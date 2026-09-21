// Port of the client half of `github.com/quic-go/webtransport-go`'s
// `client.go` (v0.11.1, revision d03fbc34952e05e833ab2a3810ab55aeefe2bf30),
// together with the slice of `quic-go/http3`'s client that establishing a
// session actually needs.
//
// Establishing a WebTransport session is an HTTP/3 Extended CONNECT
// (RFC 9220) carrying `:protocol: webtransport-h3`. Getting there means
// speaking enough HTTP/3 to be a well-formed client: the control stream must
// be the first unidirectional stream opened and must start with SETTINGS
// (RFC 9114 section 6.2.1), the QPACK encoder and decoder streams must exist
// even when the dynamic table is never used (RFC 9204 section 4.2), and the
// request's header block is QPACK, not plain text.
//
// The session ID is the QUIC stream ID of the CONNECT request itself, which
// is why every stream inside the session is prefixed with it.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_qpack/transpiled_qpack.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart' as quicgo;

import 'protocol.dart';
import 'session.dart';

/// Thrown when a WebTransport session cannot be established.
class DialException implements Exception {
  /// Creates a [DialException] describing why the session was refused.
  const DialException(this.message);

  /// A human readable description of the failure.
  final String message;

  @override
  String toString() => 'DialException: $message';
}

/// Establishes WebTransport sessions over an existing QUIC connection, per
/// Go's `webtransport.Dialer`.
///
/// Go's `Dialer.Dial` also dials the QUIC connection itself; here that is the
/// caller's job, because libp2p needs to drive the QUIC handshake with its own
/// `certhash` pinning before any HTTP/3 exists.
class Dialer {
  /// Creates a [Dialer].
  const Dialer({this.handshakeTimeout = const Duration(seconds: 15)});

  /// How long to wait for the server's SETTINGS and CONNECT response.
  final Duration handshakeTimeout;

  /// Runs the Extended CONNECT handshake on [conn] and returns the session.
  ///
  /// [authority] is the `host:port` of the peer and [path] the request path,
  /// which for libp2p is `/.well-known/libp2p-webtransport?type=noise`.
  Future<Session> dial({
    required quicgo.QuicConn conn,
    required String authority,
    required String path,
  }) async {
    if (conn.negotiatedProtocol != null &&
        conn.negotiatedProtocol != nextProtoH3) {
      throw DialException(
        'WebTransport needs ALPN "$nextProtoH3", got "${conn.negotiatedProtocol}"',
      );
    }

    // RFC 9114 section 6.2.1: the control stream carries its stream type and
    // then SETTINGS, before anything else this endpoint sends. The
    // WebTransport codepoint goes in `other`, as Go's
    // `http3.Transport.AdditionalSettings` does; `datagram` is not optional
    // here, because webtransport-go's server refuses a session whose client
    // did not enable HTTP datagrams (`server.go`, the `settings.EnableDatagrams`
    // check).
    conn.openUniStream().write(
      Uint8List.fromList(
        const Http3SettingsFrame(
          datagram: true,
          other: {settingsWebTransportEnabled: 1},
        ).append(appendVarInt(const [], http3StreamTypeControl)),
      ),
    );

    // RFC 9204 section 4.2: both QPACK streams must exist for the lifetime of
    // the connection even when neither endpoint uses the dynamic table.
    conn.openUniStream().write(
      appendVarInt(const [], http3StreamTypeQpackEncoder),
    );
    conn.openUniStream().write(
      appendVarInt(const [], http3StreamTypeQpackDecoder),
    );

    final serverSettings = await _readServerSettings(
      conn,
    ).timeout(handshakeTimeout);
    if (!serverSettings.extendedConnect) {
      throw const DialException(
        'server does not support Extended CONNECT, so it cannot serve '
        'WebTransport',
      );
    }

    final headerBlock = _encodeHeaders([
      const HeaderField(name: ':method', value: 'CONNECT'),
      const HeaderField(name: ':protocol', value: protocolHeader),
      const HeaderField(name: ':scheme', value: 'https'),
      HeaderField(name: ':authority', value: authority),
      HeaderField(name: ':path', value: path),
    ]);

    final request = conn.openStream()
      ..write(
        Uint8List.fromList(
          Http3HeadersFrame(headerBlock.length).append(const []),
        ),
      )
      ..write(headerBlock);

    final response = await _readResponseHeaders(request).timeout(
      handshakeTimeout,
      onTimeout: () => throw const DialException(
        'timed out waiting for the CONNECT response',
      ),
    );

    final status = response
        .firstWhere(
          (field) => field.name == ':status',
          orElse: () => const HeaderField(name: ':status', value: ''),
        )
        .value;
    final code = int.tryParse(status);
    if (code == null || code < 200 || code > 299) {
      request.reset();
      throw DialException('CONNECT was refused with status "$status"');
    }

    // RFC 9114 section 6.2.1: the control stream stays open for the whole
    // connection; closing it is a H3_CLOSED_CRITICAL_STREAM connection error.
    return Session(
      conn: conn,
      sessionId: request.id,
      requestStream: request,
      applicationProtocol: response
          .firstWhere(
            (field) => field.name == wtProtocolHeader,
            orElse: () => const HeaderField(name: wtProtocolHeader, value: ''),
          )
          .value,
    );
  }

  /// Reads the peer's control stream up to and including its SETTINGS frame.
  ///
  /// The server opens its control stream and both QPACK streams in whatever
  /// order it likes, so unidirectional streams are accepted until the control
  /// stream turns up.
  Future<Http3SettingsFrame> _readServerSettings(quicgo.QuicConn conn) async {
    while (true) {
      final stream = await conn.acceptUniStream();
      final buffer = BytesBuilder(copy: false);
      final streamType = await _readVarInt(stream);
      if (streamType != http3StreamTypeControl) continue;

      while (true) {
        final pending = buffer.takeBytes();
        try {
          final (frame, _) = parseHttp3Frame(pending);
          if (frame is Http3SettingsFrame) return frame;
        } on FormatException {
          // The frame is not fully buffered yet; read more and retry.
        }
        final chunk = await stream.read();
        if (chunk.isEmpty) {
          throw const DialException(
            'server closed its control stream before sending SETTINGS',
          );
        }
        buffer
          ..add(pending)
          ..add(chunk);
      }
    }
  }

  /// Reads the HEADERS frame answering the CONNECT request.
  Future<List<HeaderField>> _readResponseHeaders(
    quicgo.QuicStream stream,
  ) async {
    final buffer = BytesBuilder(copy: false);
    while (true) {
      final pending = buffer.takeBytes();
      try {
        final (frame, consumed) = parseHttp3Frame(pending);
        if (frame is Http3HeadersFrame) {
          final available = pending.length - consumed;
          if (available >= frame.length) {
            return _decodeHeaders(
              Uint8List.sublistView(pending, consumed, consumed + frame.length),
            );
          }
        } else {
          throw const DialException(
            'server answered CONNECT with something other than HEADERS',
          );
        }
      } on FormatException {
        // Not enough bytes buffered yet.
      }
      final chunk = await stream.read();
      if (chunk.isEmpty) {
        throw const DialException(
          'server closed the request stream before answering CONNECT',
        );
      }
      buffer
        ..add(pending)
        ..add(chunk);
    }
  }
}

/// Reads exactly one QUIC varint from the head of [stream].
///
/// The first byte's two most significant bits give the encoded length, per
/// RFC 9000 section 16, so nothing that follows the varint is consumed.
Future<int> _readVarInt(quicgo.QuicStream stream) async {
  final first = await stream.readExactly(1);
  final length = 1 << (first[0] >> 6);
  if (length == 1) return first[0] & 0x3f;
  final rest = await stream.readExactly(length - 1);
  final encoded = Uint8List(length)
    ..[0] = first[0]
    ..setAll(1, rest);
  return parseVarInt(encoded).$1;
}

/// QPACK-encodes a whole header block, prefix included.
Uint8List _encodeHeaders(List<HeaderField> fields) {
  final encoder = Encoder();
  final block = BytesBuilder(copy: false);
  for (final field in fields) {
    block.add(encoder.writeField(field));
  }
  encoder.close();
  return block.takeBytes();
}

List<HeaderField> _decodeHeaders(Uint8List block) =>
    const Decoder().decode(block).toList();
