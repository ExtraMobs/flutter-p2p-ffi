// Port of github.com/pion/dtls/v3 pkg/crypto/ciphersuite/*.go
//
// Provides the crypto operations needed for a DTLS CipherSuite. The Go
// package spreads these across ciphersuite.go (this file), gcm.go, cbc.go
// and ccm.go, sharing several unexported symbols (the `aead` struct,
// `examinePadding`, `seqNumPlaceholder`, `generateAEADAdditionalData(CID)`,
// `errFailedToCast`) across all four files. Dart's per-file privacy is
// reconciled with that the same way `packages/transpiled_pion_sdp` does:
// one library declared here, with the sibling files pulled in as `part`s so
// they keep sharing this file's private namespace.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:pointycastle/export.dart' as pc;

import '../../../protocol/protocol.dart';
import '../../../protocol/recordlayer/record_layer.dart';
import '../ccm/ccm.dart' as ccm;
import '../prf/prf.dart';

part 'gcm.dart';
part 'cbc.dart';
part 'ccm.dart';

/// 8 bytes of 0xff.
/// https://datatracker.ietf.org/doc/html/rfc9146#name-record-payload-protection
final Uint8List _seqNumPlaceholderBytes = Uint8List.fromList(
  List<int>.filled(8, 0xff),
);

/// errNotEnoughRoomForNonce -> &protocol.InternalError{...}.
class NotEnoughRoomForNonceException implements Exception {
  const NotEnoughRoomForNonceException();

  @override
  String toString() => 'buffer not long enough to contain nonce';
}

/// errDecryptPacket -> &protocol.TemporaryError{...}.
class DecryptPacketException implements Exception {
  const DecryptPacketException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to decrypt packet: $cause';
}

/// errInvalidMAC -> &protocol.TemporaryError{...}.
class InvalidMacException implements Exception {
  const InvalidMacException();

  @override
  String toString() => 'invalid mac';
}

/// errFailedToCast -> &protocol.FatalError{...}.
class FailedToCastException implements Exception {
  const FailedToCastException();

  @override
  String toString() => 'failed to cast';
}

/// A DTLS-record AEAD cipher: the shape shared by the pkg/crypto/ccm.Ccm
/// port and the AES-GCM adapter used by gcm.dart, mirroring Go's
/// `cipher.AEAD` (crypto/cipher, stdlib) as consumed by the unexported
/// `aead` struct below.
abstract class GoAeadCipher {
  Uint8List seal(
    Uint8List dst,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List additionalData,
  );

  Uint8List open(
    Uint8List dst,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List additionalData,
  );
}

/// aead provides a generic API to Encrypt/Decrypt DTLS 1.2 Packets.
///
/// Port of the unexported Go type `aead`. Go pools fixed-size nonce buffers
/// with a `sync.Pool`; that is a pure allocation-reuse optimization with no
/// observable effect, so the Dart port allocates a fresh buffer per call and
/// lets the GC reclaim it.
class Aead {
  Aead(
    this.localAead,
    this.localWriteIv,
    this.remoteAead,
    this.remoteWriteIv,
    this.nonceLength,
    this.tagLength,
  );

  final GoAeadCipher localAead;
  final GoAeadCipher remoteAead;
  final Uint8List localWriteIv;
  final Uint8List remoteWriteIv;
  final int nonceLength;
  final int tagLength;

  /// encrypt encrypts a DTLS RecordLayer message.
  Uint8List encrypt(RecordLayer pkt, Uint8List raw) {
    final headerSize = pkt.header.size();
    final payload = raw.sublist(headerSize);
    raw = raw.sublist(0, headerSize);

    final nonce = Uint8List(nonceLength);
    nonce.setRange(0, 4, localWriteIv.sublist(0, 4));

    // https://www.rfc-editor.org/rfc/rfc9325#name-nonce-reuse-in-tls-12
    final seq64 =
        (pkt.header.epoch << 48) |
        (pkt.header.sequenceNumber & 0x0000ffffffffffff);
    ByteData.sublistView(nonce).setUint64(4, seq64);

    final Uint8List additionalData;
    if (pkt.header.contentType == ContentType.connectionId) {
      additionalData = _generateAeadAdditionalDataCid(
        pkt.header,
        payload.length,
      );
    } else {
      additionalData = _generateAeadAdditionalData(pkt.header, payload.length);
    }

    final sealed = localAead.seal(Uint8List(0), nonce, payload, additionalData);

    final finalSize = raw.length + 8 + sealed.length;
    final r = Uint8List(finalSize);
    r.setRange(0, raw.length, raw);
    r.setRange(raw.length, raw.length + 8, nonce.sublist(4));
    r.setRange(raw.length + 8, finalSize, sealed);

    // Update recordLayer size to include explicit nonce.
    final contentLen = r.length - headerSize;
    r[headerSize - 2] = (contentLen >> 8) & 0xFF;
    r[headerSize - 1] = contentLen & 0xFF;

    return r;
  }

  /// decrypt decrypts a DTLS RecordLayer message.
  Uint8List decrypt(Header header, Uint8List inBytes) {
    header.unmarshal(inBytes);
    if (header.contentType == ContentType.changeCipherSpec) {
      // Nothing to encrypt with ChangeCipherSpec.
      return inBytes;
    }
    if (inBytes.length <= (8 + header.size())) {
      throw const NotEnoughRoomForNonceException();
    }

    final nonce = Uint8List(nonceLength);
    nonce.setRange(0, 4, remoteWriteIv.sublist(0, 4));
    nonce.setRange(
      4,
      nonceLength,
      inBytes.sublist(header.size(), header.size() + 8),
    );
    final out = inBytes.sublist(header.size() + 8);

    final Uint8List additionalData;
    if (header.contentType == ContentType.connectionId) {
      additionalData = _generateAeadAdditionalDataCid(
        header,
        out.length - tagLength,
      );
    } else {
      additionalData = _generateAeadAdditionalData(
        header,
        out.length - tagLength,
      );
    }

    final Uint8List opened;
    try {
      opened = remoteAead.open(Uint8List(0), nonce, out, additionalData);
    } catch (e) {
      throw DecryptPacketException(e);
    }

    final result = Uint8List(header.size() + opened.length);
    result.setRange(0, header.size(), inBytes.sublist(0, header.size()));
    result.setRange(header.size(), result.length, opened);
    return result;
  }
}

Uint8List _generateAeadAdditionalData(Header h, int payloadLen) {
  final additionalData = Uint8List(13);
  final view = ByteData.sublistView(additionalData);
  // SequenceNumber MUST be set first: Go writes the uint64 sequence number
  // over the whole 13-byte buffer, then overwrites the first two bytes with
  // Epoch -- net effect: bytes[0:2]=Epoch, bytes[2:8]=low 6 bytes of
  // SequenceNumber (uint48).
  view.setUint64(0, h.sequenceNumber);
  view.setUint16(0, h.epoch);
  additionalData[8] = h.contentType.value;
  additionalData[9] = h.version.major;
  additionalData[10] = h.version.minor;
  view.setUint16(additionalData.length - 2, payloadLen);
  return additionalData;
}

/// generateAEADAdditionalDataCID generates additional data for AEAD ciphers
/// according to https://datatracker.ietf.org/doc/html/rfc9146#name-aead-ciphers
Uint8List _generateAeadAdditionalDataCid(Header h, int payloadLen) {
  final cid = h.connectionId ?? Uint8List(0);
  final builder = BytesBuilder()
    ..add(_seqNumPlaceholderBytes)
    ..addByte(ContentType.connectionId.value)
    ..addByte(cid.length & 0xFF)
    ..addByte(ContentType.connectionId.value)
    ..addByte(h.version.major)
    ..addByte(h.version.minor);
  final epochBytes = ByteData(2)..setUint16(0, h.epoch);
  builder.add(epochBytes.buffer.asUint8List());
  builder.add(_uint48Be(h.sequenceNumber));
  builder.add(cid);
  final payloadLenBytes = ByteData(2)..setUint16(0, payloadLen);
  builder.add(payloadLenBytes.buffer.asUint8List());
  return builder.toBytes();
}

Uint8List _uint48Be(int v) {
  final out = Uint8List(6);
  var value = v;
  for (var i = 5; i >= 0; i--) {
    out[i] = value & 0xFF;
    value >>= 8;
  }
  return out;
}

/// examinePadding returns, in constant time, the length of the padding to
/// remove from the end of payload. It also returns a byte which is equal to
/// 255 if the padding was valid and 0 otherwise. See RFC 2246, Section
/// 6.2.3.2.
///
/// https://github.com/golang/go/blob/039c2081d1178f90a8fa2f4e6958693129f8de33/src/crypto/tls/conn.go#L245
///
/// Go computes the sign checks below via wrapping `uint` subtraction plus a
/// 32-bit sign-extend trick (`byte(int32(^t) >> 31)`), which is how Go keeps
/// this branch-free without a native boolean-to-mask cast. Every operand
/// here is a single byte (`paddingLen`, loop index `i`) or a DTLS record
/// payload length -- never within light-years of 2^31 -- so a plain signed
/// comparison always agrees with the wraparound trick's result; this keeps
/// the port branch-light without emulating 32-bit wraparound that these
/// operand ranges can never actually trigger.
(int toRemove, int good) examinePadding(Uint8List payload) {
  if (payload.isEmpty) {
    return (0, 0);
  }

  final paddingLen = payload[payload.length - 1];
  var good = (payload.length - 1 - paddingLen) >= 0 ? 0xFF : 0x00;

  final toCheck = payload.length < 256 ? payload.length : 256;

  for (var i = 0; i < toCheck; i++) {
    final mask = (paddingLen - i) >= 0 ? 0xFF : 0x00;
    final b = payload[payload.length - 1 - i];
    good &= ~(mask & paddingLen ^ mask & b) & 0xFF;
  }

  good &= (good << 4) & 0xFF;
  good &= (good << 2) & 0xFF;
  good &= (good << 1) & 0xFF;
  good = (good & 0x80) != 0 ? 0xFF : 0x00;

  final toRemove = paddingLen + 1;

  return (toRemove, good);
}
