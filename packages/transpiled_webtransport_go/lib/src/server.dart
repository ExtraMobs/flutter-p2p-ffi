// Port of the server half of `github.com/quic-go/webtransport-go`'s
// `server.go` (v0.11.1, revision d03fbc34952e05e833ab2a3810ab55aeefe2bf30),
// together with the slice of `quic-go/http3`'s server that answering a
// WebTransport CONNECT request actually needs.
//
// Upstream's `Server` also owns `net.PacketConn`/`http3.Server` plumbing --
// listening for QUIC connections, routing ordinary HTTP/3 requests, origin
// checking for browser clients -- none of which this project has a use for:
// AGENTS.md puts the local HTTP surface out of scope, and libp2p hands this
// port an already-accepted [quic_go.QuicConn] instead of asking it to listen.
// What is ported is the part with no substitute: performing the server side
// of the HTTP/3 + Extended CONNECT handshake (`Server.ServeQUICConn` +
// `Server.Upgrade`, RFC 9220) and handing back the resulting [Session],
// mirroring `client.dart`'s [Dialer] so the two sides interoperate.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_qpack/transpiled_qpack.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart' as quic_go;

import 'protocol.dart';
import 'session.dart';

/// Thrown when a WebTransport session cannot be accepted.
class ServerException implements Exception {
  /// Creates a [ServerException] describing why the session was refused.
  const ServerException(this.message);

  /// A human readable description of the failure.
  final String message;

  @override
  String toString() => 'ServerException: $message';
}

/// The default `acceptPath` for [Server.accept]: every path is served.
bool _acceptAnyPath(String path) => true;

/// Accepts WebTransport sessions on an established HTTP/3 QUIC connection.
///
/// Go: `webtransport.Server`, minus the `http.Server` plumbing this project
/// has no use for (the gateway/HTTP surface is out of scope per AGENTS.md).
class Server {
  /// Creates a [Server].
  const Server({this.handshakeTimeout = const Duration(seconds: 10)});

  /// How long to wait for the client's SETTINGS, and for each request
  /// stream, before giving up on the handshake.
  final Duration handshakeTimeout;

  /// Runs the server side of the HTTP/3 + Extended CONNECT handshake on
  /// [conn] and returns the established session.
  ///
  /// [acceptPath] decides whether a request path is served; return false and
  /// the request is answered 404 and the wait resumes for the next one.
  ///
  /// Go: `Server.ServeQUICConn` + `Server.Upgrade`, collapsed into one call
  /// because this port has no `http.Server` request loop routing requests to
  /// a handler in between.
  Future<Session> accept({
    required quic_go.QuicConn conn,
    bool Function(String path) acceptPath = _acceptAnyPath,
  }) async {
    if (conn.negotiatedProtocol != null &&
        conn.negotiatedProtocol != nextProtoH3) {
      throw ServerException(
        'WebTransport needs ALPN "$nextProtoH3", got '
        '"${conn.negotiatedProtocol}"',
      );
    }

    // RFC 9114 section 6.2.1: the control stream carries its stream type and
    // then SETTINGS, before anything else this endpoint sends. Extended
    // CONNECT (RFC 9220) must be announced or the client refuses to open a
    // WebTransport session at all; the WebTransport codepoint goes in
    // `other`, as Go's `ConfigureHTTP3Server` sets it via
    // `http3.Server.AdditionalSettings`.
    conn.openUniStream().write(
      Uint8List.fromList(
        const Http3SettingsFrame(
          datagram: true,
          extendedConnect: true,
          other: {settingsWebTransportEnabled: 1},
        ).append(appendVarInt(const [], http3StreamTypeControl)),
      ),
    );

    // RFC 9204 section 4.2: both QPACK streams must exist for the lifetime
    // of the connection even when neither endpoint uses the dynamic table.
    conn.openUniStream().write(
      appendVarInt(const [], http3StreamTypeQpackEncoder),
    );
    conn.openUniStream().write(
      appendVarInt(const [], http3StreamTypeQpackDecoder),
    );

    // The client's SETTINGS are read but, like upstream's `Upgrade` (which
    // only inspects `EnableDatagrams`), not otherwise required to unlock the
    // handshake: this port does not offer datagrams on its own streams yet,
    // so there is nothing to gate on that flag today.
    await _readClientSettings(conn).timeout(handshakeTimeout);

    while (true) {
      final request = await conn.acceptStream().timeout(
        handshakeTimeout,
        onTimeout: () => throw const ServerException(
          'timed out waiting for a request stream',
        ),
      );

      final headers = await _readRequestHeaders(request).timeout(
        handshakeTimeout,
        onTimeout: () => throw const ServerException(
          'timed out waiting for the CONNECT request headers',
        ),
      );

      String header(String name) => headers
          .firstWhere(
            (field) => field.name == name,
            orElse: () => const HeaderField(name: ''),
          )
          .value;

      final method = header(':method');
      final protocol = header(':protocol');
      final path = header(':path');

      if (method != 'CONNECT' || !isWebTransportProtocol(protocol)) {
        _respond(request, status: '400');
        throw ServerException(
          'expected a WebTransport CONNECT request, got method "$method" '
          'protocol "$protocol"',
        );
      }

      if (!acceptPath(path)) {
        _respond(request, status: '404');
        continue;
      }

      final offered = header(wtAvailableProtocolsHeader);
      final selected = offered.isEmpty ? null : _firstOfferedProtocol(offered);

      _respond(
        request,
        status: '200',
        extra: selected == null
            ? const []
            : [HeaderField(name: wtProtocolHeader, value: selected)],
      );

      // RFC 9114 section 6.2.1: the control stream stays open for the whole
      // connection; closing it is a H3_CLOSED_CRITICAL_STREAM connection
      // error.
      return Session(
        conn: conn,
        sessionId: request.id,
        requestStream: request,
        applicationProtocol: selected ?? '',
      );
    }
  }

  /// Reads the peer's unidirectional streams up to and including its
  /// SETTINGS frame.
  ///
  /// The client opens its control stream and both QPACK streams in whatever
  /// order it likes, so unidirectional streams are accepted until the
  /// control stream turns up. Go: the `AcceptUniStream` loop feeding
  /// `http3Conn.HandleUnidirectionalStream` in `Server.ServeQUICConn`.
  Future<Http3SettingsFrame> _readClientSettings(quic_go.QuicConn conn) async {
    while (true) {
      final stream = await conn.acceptUniStream();
      final streamType = await _readVarInt(stream);
      if (streamType != http3StreamTypeControl) continue;

      final buffer = BytesBuilder(copy: false);
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
          throw const ServerException(
            'client closed its control stream before sending SETTINGS',
          );
        }
        buffer
          ..add(pending)
          ..add(chunk);
      }
    }
  }

  /// Reads the HEADERS frame carrying the CONNECT request.
  Future<List<HeaderField>> _readRequestHeaders(
    quic_go.QuicStream stream,
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
          throw const ServerException(
            'client opened a request stream with something other than '
            'HEADERS',
          );
        }
      } on FormatException {
        // Not enough bytes buffered yet.
      }
      final chunk = await stream.read();
      if (chunk.isEmpty) {
        throw const ServerException(
          'client closed the request stream before sending its headers',
        );
      }
      buffer
        ..add(pending)
        ..add(chunk);
    }
  }

  /// Writes a HEADERS frame answering a request with [status] and any
  /// [extra] header fields, mirroring the `w.WriteHeader` + `w.Header().Add`
  /// calls in Go's `Server.Upgrade`.
  void _respond(
    quic_go.QuicStream stream, {
    required String status,
    List<HeaderField> extra = const [],
  }) {
    final headerBlock = _encodeHeaders([
      HeaderField(name: ':status', value: status),
      ...extra,
    ]);
    stream
      ..write(
        Uint8List.fromList(
          Http3HeadersFrame(headerBlock.length).append(const []),
        ),
      )
      ..write(headerBlock);
  }
}

/// Reads exactly one QUIC varint from the head of [stream].
///
/// The first byte's two most significant bits give the encoded length, per
/// RFC 9000 section 16, so nothing that follows the varint is consumed.
Future<int> _readVarInt(quic_go.QuicStream stream) async {
  final first = await stream.readExactly(1);
  final length = 1 << (first[0] >> 6);
  if (length == 1) return first[0] & 0x3f;
  final rest = await stream.readExactly(length - 1);
  final encoded = Uint8List(length)
    ..[0] = first[0]
    ..setAll(1, rest);
  return parseVarInt(encoded).$1;
}

/// Picks the first protocol a client offered via [wtAvailableProtocolsHeader].
///
/// The value is a structured-field list (RFC 8941) of string items. A full
/// httpsfv parser (`github.com/dunglas/httpsfv`) is outside this port's
/// dependency scope, so only the shape webtransport-go itself produces -- a
/// comma-separated list of bare or double-quoted tokens -- is understood
/// here, matching Go's `Server.selectProtocol` picking the first offered
/// protocol this server also lists in `ApplicationProtocols`. This port has
/// no `ApplicationProtocols` allowlist of its own, so every offered protocol
/// is accepted and the first one wins.
String? _firstOfferedProtocol(String header) {
  for (final raw in header.split(',')) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }
  return null;
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
