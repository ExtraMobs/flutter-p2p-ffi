// ignore_for_file: library_prefixes
/// Port of the TLS 1.3 record layer: the parts of Go's `crypto/tls`
/// `conn.go` (1,692 lines) and `common.go` (1,805 lines) needed to protect,
/// frame and parse individual records once a connection has (or has not
/// yet) negotiated TLS 1.3, per RFC 8446 Section 5.
///
/// ## Scope boundary
///
/// This file ports record framing and per-record AEAD protection only. It
/// does **not** port `Conn` itself: `Conn`'s exported surface (`Read`,
/// `Write`, `Handshake`, `Close`, ...) is inseparable from `net.Conn`
/// wrapping, `*Config`, x509 verification and the handshake state machine
/// (`handshake_client_tls13.go`/`handshake_server_tls13.go`), all explicitly
/// out of scope for this pass. Nor does it port the stream-reassembly loop
/// (`Conn.readRecordOrCCS`'s outer `retryReadRecord` recursion, alert-level
/// interpretation, `closeNotify`-as-`io.EOF`): that loop is connection
/// policy tied to a live `net.Conn`, not record-layer mechanics, and is left
/// to the future `Conn` integration this record layer is meant to support.
///
/// ## Go symbol -> upstream file:line -> Dart symbol
///
/// From `conn.go`:
///   - `halfConn` struct (`conn.go:169-185`) -> [HalfConn]. Unexported in
///     Go; elevated to public here for the same testability reason
///     documented in `alert.dart`'s header. Restricted to the TLS 1.3 AEAD
///     path: the `mac`/`nextCipher`/`nextMac`/`scratchBuf` fields and the
///     `cipher.Stream`/`cbcMode` branches of `encrypt`/`decrypt` exist only
///     for TLS 1.0-1.2, out of scope, and are not ported. The `level
///     QUICEncryptionLevel` field is QUIC bookkeeping (also out of scope)
///     and dropped from [HalfConn.setTrafficSecret]'s signature.
///   - `(*halfConn).incSeq` (`conn.go:240-252`) -> [HalfConn.incSeq]
///   - `(*halfConn).setTrafficSecret` (`conn.go:229-237`)
///     -> [HalfConn.setTrafficSecret]
///   - `(*halfConn).explicitNonceLen` (`conn.go:257-276`), restricted to its
///     `aead` case (`case aead: return c.explicitNonceLen()`, always 0 for
///     TLS 1.3's `xorNonceAEAD`) -> [HalfConn.explicitNonceLen]
///   - `(*halfConn).changeCipherSpec` (`conn.go:215-227`)
///     -> [HalfConn.changeCipherSpec]. Go's condition
///     `hc.nextCipher == nil || hc.version == VersionTLS13` always takes the
///     error branch in a TLS-1.3-only port (`nextCipher` is TLS 1.2
///     renegotiation prep, never populated here), so this always throws;
///     ported for RFC 8446 Appendix D.4 fidelity (a TLS 1.3 endpoint that
///     somehow reached this call is an internal error, not a no-op).
///   - `(*halfConn).decrypt` (`conn.go:340-462`), restricted to the `aead`
///     case and the `hc.version == VersionTLS13` branches (the
///     `cipher.Stream`/`cbcMode` cases and the trailing `hc.mac != nil`
///     block are TLS 1.0-1.2 only) -> [HalfConn.decrypt]
///   - `(*halfConn).encrypt` (`conn.go:480-563`), same restriction
///     -> [HalfConn.encrypt]
///   - `recordType` (`common.go:74`) and its 4 constants (`common.go:76-81`)
///     -> [recordTypeChangeCipherSpec] / [recordTypeAlert] /
///     [recordTypeHandshake] / [recordTypeApplicationData]. Also unexported
///     in Go; elevated for the same reason.
///   - `writeRecordLocked`'s fragmentation loop and header construction
///     (`conn.go:981-1050`), minus QUIC (`conn.go:982-993`) and the
///     `recordTypeChangeCipherSpec && vers != VersionTLS13` branch
///     (`conn.go:1043-1047`, unreachable for TLS 1.3) -> [writeTls13Records].
///     `maxPayloadSizeForWrite`'s dynamic record-sizing heuristic
///     (`conn.go:902-947`, `tcpMSSEstimate`/`recordSizeBoostThreshold`,
///     `common.go:872-884`) needs `*Config.DynamicRecordSizingDisabled` and
///     `Conn`'s running `bytesSent`/`packetsSent` counters, both out of
///     scope; this port always fragments at [maxPlaintext], matching Go's
///     own behavior with `DynamicRecordSizingDisabled: true`. Named gap, not
///     silently degraded.
///   - `readRecordOrCCS`'s header validation and single-record decode path
///     (`conn.go:610-698`), minus QUIC (`conn.go:622-624`), the
///     handshake-interleaving check that needs `Conn.hand` buffering state
///     (`conn.go:706-708`), and the outer type-switch's retry/alert-level/
///     `closeNotify` policy (`conn.go:710-788`, connection-loop policy, see
///     "Scope boundary" above) -> [readTls13Record]. The stream-assembly
///     helpers `readFromUntil`/`atLeastReader` (`conn.go:804-840`) are not
///     ported: this port takes one already-assembled record buffer per
///     call rather than pulling bytes off a live `net.Conn`.
///   - `RecordHeaderError` (`conn.go:566-586`) -> [RecordHeaderException].
///     The `Conn net.Conn` field is dropped (needs `net.Conn`, out of
///     scope); `newRecordHeaderError`'s `copy(err.RecordHeader[:], ...)`
///     partial-header behavior is preserved via `_headerOrPartial`.
///
/// From `common.go`, only the record-layer-referenced subset of the
/// `const` blocks at lines 32-40 and 63-81:
///   - `VersionTLS10`/`VersionTLS12`/`VersionTLS13` (`common.go:33,35-36`)
///     -> [versionTls10] / [versionTls12] / [versionTls13]. `VersionTLS11`
///     and `VersionSSL30` (`common.go:34,40`) are not referenced by the
///     ported record-layer code (only by version-negotiation logic in
///     `Config`, out of scope) and are excluded.
///   - `maxPlaintext`/`maxCiphertextTLS13`/`recordHeaderLen`
///     (`common.go:64,66-67`) -> [maxPlaintext] / [maxCiphertextTls13] /
///     [recordHeaderLen].
///   - `maxUselessRecords` (`common.go:70`) -> [maxUselessRecords]. Ported
///     as a named limit even though the retry loop that consumes it
///     (`retryReadRecord`) is out of scope, since it is a protocol-level
///     constant a future retry loop must reuse rather than reinvent.
///   - Excluded: `maxCiphertext` (`common.go:65`, TLS 1.0-1.2 record size
///     cap -- this port has no TLS 1.0-1.2 path), `maxHandshake` /
///     `maxHandshakeCertificateMsg` (`common.go:68-69`, handshake message
///     *reassembly* limits consumed by `Conn.readHandshake`, out of scope
///     with the handshake state machine).
///
/// From `alert.go`: see `alert.dart`'s own header (a separate small file,
/// ported in full since `conn.go` depends on it throughout).
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'alert.dart';
import 'cipher_suites.dart' show AeadAuthenticationException;
import 'key_schedule.dart';

/// Port of `VersionTLS10` (`common.go:33`).
const int versionTls10 = 0x0301;

/// Port of `VersionTLS12` (`common.go:35`).
const int versionTls12 = 0x0303;

/// Port of `VersionTLS13` (`common.go:36`).
const int versionTls13 = 0x0304;

/// Port of `maxPlaintext` (`common.go:64`).
const int maxPlaintext = 16384;

/// Port of `maxCiphertextTLS13` (`common.go:66`).
const int maxCiphertextTls13 = 16384 + 256;

/// Port of `recordHeaderLen` (`common.go:67`).
const int recordHeaderLen = 5;

/// Port of `maxUselessRecords` (`common.go:70`).
const int maxUselessRecords = 16;

/// Port of `recordTypeChangeCipherSpec` (`common.go:77`).
const int recordTypeChangeCipherSpec = 20;

/// Port of `recordTypeAlert` (`common.go:78`).
const int recordTypeAlert = 21;

/// Port of `recordTypeHandshake` (`common.go:79`).
const int recordTypeHandshake = 22;

/// Port of `recordTypeApplicationData` (`common.go:80`).
const int recordTypeApplicationData = 23;

/// Port of `RecordHeaderError` (`conn.go:566-579`), minus the `Conn` field
/// -- see file header.
final class RecordHeaderException implements Exception {
  /// Builds a header validation failure. [recordHeader] is padded/truncated
  /// to exactly [recordHeaderLen] bytes, mirroring `copy(err.RecordHeader[:], ...)`
  /// (`conn.go:584`) with a source shorter than the fixed `[5]byte` array.
  RecordHeaderException(this.message, Uint8List rawHeader)
    : recordHeader = _headerOrPartial(rawHeader);

  /// Port of `RecordHeaderError.Msg` (`conn.go:568`).
  final String message;

  /// Port of `RecordHeaderError.RecordHeader` (`conn.go:571`).
  final Uint8List recordHeader;

  /// Port of `(RecordHeaderError).Error` (`conn.go:579`).
  @override
  String toString() => 'tls: $message';
}

Uint8List _headerOrPartial(Uint8List record) {
  final out = Uint8List(recordHeaderLen);
  final n = record.length < recordHeaderLen ? record.length : recordHeaderLen;
  out.setRange(0, n, record);
  return out;
}

/// Big-endian byte write helpers (Rule 10: go through
/// `fixed_types.Golang.*` rather than manual masks). Reading big-endian
/// fields back out of already-bounded bytes uses plain shifts below, which
/// mirrors the existing convention in `handshake_messages.dart`'s
/// `_Reader` (parsing an already-fixed-width field does not carry the
/// truncation-on-write risk `Golang.UintN` guards against).
Uint8List _beUint8(int value) =>
    Uint8List.fromList([Golang.Uint8(value).toLittleEndianBytes()[0]]);

Uint8List _beUint16(int value) {
  final le = Golang.Uint16(value).toLittleEndianBytes();
  return Uint8List.fromList([le[1], le[0]]);
}

/// Port of `halfConn` (`conn.go:169-185`), restricted to the TLS 1.3 AEAD
/// path. See file header for the full restriction rationale.
final class HalfConn {
  /// Starts an unprotected half-connection: no cipher, sequence number
  /// zero, version unnegotiated (mirrors Go's zero-value `halfConn{}`).
  HalfConn();

  /// Port of `halfConn.version` (`conn.go:173`). `0` mirrors Go's
  /// unnegotiated zero value; set to [versionTls13] once negotiated.
  int version = 0;

  /// Port of `halfConn.cipher` (`conn.go:174`), narrowed from `any` to
  /// [CipherSuiteTls13Aead]? since the `cipher.Stream`/`cbcMode` cases are
  /// out of scope.
  CipherSuiteTls13Aead? cipher;

  /// Port of `halfConn.trafficSecret` (`conn.go:184`).
  Uint8List trafficSecret = Uint8List(0);

  final Uint8List _seq = Uint8List(8);

  /// Port of `halfConn.seq` (`conn.go:176`), exposed read-only (a defensive
  /// copy) since Go's in-package tests read `hc.seq` directly, which an
  /// external `test/atomic/` file cannot do without a public accessor.
  Uint8List get seq => Uint8List.fromList(_seq);

  /// Port of `(*halfConn).incSeq` (`conn.go:240-252`).
  void incSeq() {
    for (var i = 7; i >= 0; i--) {
      _seq[i] = (_seq[i] + 1) & 0xff;
      if (_seq[i] != 0) return;
    }
    // Port of Go's `panic("TLS: sequence number wraparound")`: not allowed
    // to let the sequence number wrap silently.
    throw StateError('TLS: sequence number wraparound');
  }

  /// Port of `(*halfConn).setTrafficSecret` (`conn.go:229-237`), minus the
  /// `level QUICEncryptionLevel` parameter (QUIC bookkeeping, out of scope
  /// -- see file header).
  void setTrafficSecret(CipherSuiteTls13 suite, Uint8List secret) {
    trafficSecret = secret;
    final keys = suite.trafficKey(secret);
    cipher = suite.aead(keys.key, keys.iv);
    _seq.fillRange(0, _seq.length, 0);
  }

  /// Port of `(*halfConn).changeCipherSpec` (`conn.go:215-227`), restricted
  /// to the TLS 1.3 branch -- see file header for why this always throws.
  void changeCipherSpec() => throw const AlertException(alertInternalError);

  /// Port of `(*halfConn).explicitNonceLen` (`conn.go:257-276`), restricted
  /// to the `nil`/`aead` cases.
  int get explicitNonceLen => cipher?.explicitNonceLen ?? 0;

  /// Port of `(*halfConn).decrypt` (`conn.go:340-462`), restricted to the
  /// `aead` case. [record] is one full wire record (header + ciphertext).
  /// Throws [AlertException] in place of Go's `(nil, 0, alert...)` returns.
  ({Uint8List plaintext, int recordType}) decrypt(Uint8List record) {
    var typ = record[0];
    var payload = Uint8List.sublistView(record, recordHeaderLen);

    // Port of conn.go:345-349 (RFC 8446 Appendix D.4): a TLS 1.3
    // change_cipher_spec is never decrypted, regardless of cipher state.
    if (version == versionTls13 && typ == recordTypeChangeCipherSpec) {
      return (plaintext: payload, recordType: typ);
    }

    final c = cipher;
    Uint8List plaintext;
    if (c != null) {
      // explicitNonceLen is always 0 for xorNonceAEAD (conn.go:361-368
      // collapses to `nonce = hc.seq[:]`; payload is unchanged).
      final nonce = Uint8List.fromList(_seq);
      final additionalData = Uint8List.sublistView(record, 0, recordHeaderLen);
      try {
        plaintext = c.open(nonce, payload, additionalData);
      } on AeadAuthenticationException {
        throw const AlertException(alertBadRecordMac);
      }

      // Port of conn.go:409-427: content-type unwrapping and padding strip
      // only apply once TLS 1.3 is negotiated (guards against a cipher set
      // without `version` -- unreachable via this port's own factories,
      // which only build TLS 1.3 AEADs, but kept explicit for structural
      // fidelity to Go's own guard).
      if (version == versionTls13) {
        if (typ != recordTypeApplicationData) {
          throw const AlertException(alertUnexpectedMessage);
        }
        if (plaintext.length > maxPlaintext + 1) {
          throw const AlertException(alertRecordOverflow);
        }
        for (var i = plaintext.length - 1; i >= 0; i--) {
          if (plaintext[i] != 0) {
            typ = plaintext[i];
            plaintext = plaintext.sublist(0, i);
            break;
          }
          if (i == 0) {
            throw const AlertException(alertUnexpectedMessage);
          }
        }
      }
    } else {
      plaintext = payload;
    }

    incSeq();
    return (plaintext: plaintext, recordType: typ);
  }

  /// Port of `(*halfConn).encrypt` (`conn.go:480-563`), restricted to the
  /// `aead`/`nil` cases. [header] must be exactly [recordHeaderLen] bytes
  /// (type, version, placeholder length); its length field is overwritten
  /// with the true protected length, matching Go's unconditional
  /// `record[3]`/`record[4]` rewrite. Returns the full wire record.
  Uint8List encrypt(Uint8List header, Uint8List payload) {
    if (header.length != recordHeaderLen) {
      throw ArgumentError(
        'tls: internal error: header must be exactly $recordHeaderLen bytes',
      );
    }
    final c = cipher;
    if (c == null) {
      return Uint8List.fromList([...header, ...payload]);
    }

    // explicitNonceLen is always 0 for xorNonceAEAD, so the nonce is always
    // the raw sequence number (conn.go:514-517).
    final nonce = Uint8List.fromList(_seq);
    final originalType = header[0];
    final innerPlaintext = Uint8List(payload.length + 1)
      ..setRange(0, payload.length, payload)
      ..[payload.length] = originalType;

    final n = payload.length + 1 + c.overhead;
    final aad = Uint8List.fromList(header);
    aad[0] = recordTypeApplicationData;
    aad.setRange(3, 5, _beUint16(n));

    final ciphertext = c.seal(nonce, innerPlaintext, aad);
    incSeq();
    return Uint8List.fromList([...aad, ...ciphertext]);
  }
}

/// Port of `writeRecordLocked`'s fragmentation loop and header construction
/// (`conn.go:981-1050`), minus QUIC and the (TLS-1.3-unreachable) legacy
/// change_cipher_spec branch -- see file header. Returns each fragment as a
/// ready-to-send wire record, in order; writing them to the transport is
/// left to the caller (no `net.Conn` in scope).
List<Uint8List> writeTls13Records(
  HalfConn out,
  int type,
  Uint8List data, {
  int version = versionTls13,
}) {
  // Port of conn.go:1016-1027's version-byte selection.
  final headerVersion = version == 0
      ? versionTls10
      : version == versionTls13
      ? versionTls12
      : version;

  final records = <Uint8List>[];
  var remaining = data;
  while (remaining.isNotEmpty) {
    final m = remaining.length > maxPlaintext ? maxPlaintext : remaining.length;
    final chunk = Uint8List.sublistView(remaining, 0, m);
    remaining = Uint8List.sublistView(remaining, m);

    final header = Uint8List(recordHeaderLen)
      ..[0] = _beUint8(type)[0]
      ..setRange(1, 3, _beUint16(headerVersion))
      ..setRange(3, 5, _beUint16(m));
    records.add(out.encrypt(header, chunk));
  }
  return records;
}

/// Port of `readRecordOrCCS`'s header validation and single-record decode
/// path (`conn.go:610-698`), minus QUIC, the handshake-interleaving check
/// and the outer type-switch's connection-loop policy -- see file header.
///
/// [record] must contain at least one full wire record starting at index 0;
/// trailing bytes beyond that one record are ignored (the caller owns
/// buffering across multiple records). Pass `expectedVersion: null` only
/// for the very first record read on a connection (mirrors Go's
/// `!c.haveVers` branch, `conn.go:664-672`, including the SSLv2 heuristic);
/// pass the negotiated version (e.g. [versionTls13]) for every record after
/// that (mirrors `conn.go:651-663`).
({int recordType, Uint8List data}) readTls13Record(
  HalfConn inHalfConn,
  Uint8List record, {
  required int? expectedVersion,
}) {
  if (record.length < recordHeaderLen) {
    throw RecordHeaderException(
      'internal error: record shorter than header',
      _headerOrPartial(record),
    );
  }
  final typ = record[0];
  final vers = (record[1] << 8) | record[2];
  final n = (record[3] << 8) | record[4];
  final headerBytes = Uint8List.sublistView(record, 0, recordHeaderLen);

  if (expectedVersion == null) {
    // Port of conn.go:642-649: an SSLv2 handshake starts with a uint16
    // length whose MSB is set (typ byte reads as 0x80).
    if (typ == 0x80) {
      throw RecordHeaderException(
        'unsupported SSLv2 handshake received',
        headerBytes,
      );
    }
    // Port of conn.go:664-672.
    if ((typ != recordTypeAlert && typ != recordTypeHandshake) ||
        vers >= 0x1000) {
      throw RecordHeaderException(
        'first record does not look like a TLS handshake',
        headerBytes,
      );
    }
  } else {
    // Port of conn.go:652-663: TLS 1.3 froze the record layer version to
    // 1.2 (RFC 8446 Section 5.1).
    final effectiveExpected = expectedVersion == versionTls13
        ? versionTls12
        : expectedVersion;
    if (vers != effectiveExpected) {
      throw RecordHeaderException(
        'received record with version ${vers.toRadixString(16)} '
        'when expecting version ${effectiveExpected.toRadixString(16)}',
        headerBytes,
      );
    }
  }

  // Port of conn.go:673-677 (restricted to the TLS 1.3 limit).
  if (n > maxCiphertextTls13) {
    throw const AlertException(alertRecordOverflow);
  }
  if (record.length < recordHeaderLen + n) {
    throw RecordHeaderException(
      'internal error: record buffer shorter than header-declared length',
      headerBytes,
    );
  }
  final frame = record.length == recordHeaderLen + n
      ? record
      : Uint8List.sublistView(record, 0, recordHeaderLen + n);

  final decrypted = inHalfConn.decrypt(frame);

  // Port of conn.go:691-693.
  if (decrypted.plaintext.length > maxPlaintext) {
    throw const AlertException(alertRecordOverflow);
  }
  // Port of conn.go:696-698: application data is always protected.
  if (inHalfConn.cipher == null &&
      decrypted.recordType == recordTypeApplicationData) {
    throw const AlertException(alertUnexpectedMessage);
  }
  // Port of conn.go:717-720's wire-shape check (semantic interpretation --
  // level, close_notify-as-EOF, retry -- is connection-loop policy, out of
  // scope; see file header).
  if (decrypted.recordType == recordTypeAlert &&
      decrypted.plaintext.length != 2) {
    throw const AlertException(alertUnexpectedMessage);
  }

  return (recordType: decrypted.recordType, data: decrypted.plaintext);
}
