// Port of github.com/pion/dtls/v3 pkg/crypto/ciphersuite/cbc.go
part of 'ciphersuite.dart';

const int _cbcBlockSize = 16;

/// errBufferTooSmall analog for the pending
/// `pkg/protocol/recordlayer.InnerPlaintext.Unmarshal` port (see
/// `_unmarshalInnerPlaintext` below).
class BufferTooSmallException implements Exception {
  const BufferTooSmallException();

  @override
  String toString() => 'buffer is too small';
}

Uint8List _concatBytes(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

bool _hmacEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var v = 0;
  for (var i = 0; i < a.length; i++) {
    v |= a[i] ^ b[i];
  }
  return v == 0;
}

Uint8List _cbcCryptBlocks(
  bool forEncryption,
  Uint8List key,
  Uint8List iv,
  Uint8List data,
) {
  final cipher = pc.CBCBlockCipher(pc.AESEngine())
    ..init(forEncryption, pc.ParametersWithIV(pc.KeyParameter(key), iv));
  final out = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    cipher.processBlock(data, offset, out, offset);
    offset += _cbcBlockSize;
  }
  return out;
}

/// Temporary local mirror of the pending
/// `pkg/protocol/recordlayer.InnerPlaintext.Unmarshal`
/// (https://datatracker.ietf.org/doc/html/rfc9146#name-record-layer-extensions),
/// needed by [_hmacCid] below. That type has not landed yet in this module
/// (ported concurrently, in `pkg/protocol/recordlayer`, by another agent
/// working on this same package this session) -- replace this with the
/// canonical import once available; see PROGRESS.md.
({Uint8List content, int realType, int zeros}) _unmarshalInnerPlaintext(
  Uint8List data,
) {
  var i = data.length - 1;
  var zeros = 0;
  while (i >= 0) {
    if (data[i] != 0) {
      zeros = data.length - 1 - i;
      break;
    }
    i--;
  }
  if (i == 0) {
    throw const BufferTooSmallException();
  }
  final realType = data[i];
  final content = Uint8List.fromList(data.sublist(0, i));
  return (content: content, realType: realType, zeros: zeros);
}

Uint8List _cbcHmac(
  int epoch,
  int sequenceNumber,
  ContentType contentType,
  Version protocolVersion,
  Uint8List payload,
  Uint8List key,
  HashFunc hf,
) {
  final msg = Uint8List(13);
  final view = ByteData.sublistView(msg);
  view.setUint16(0, epoch);
  msg.setRange(2, 8, _uint48Be(sequenceNumber));
  msg[8] = contentType.value;
  msg[9] = protocolVersion.major;
  msg[10] = protocolVersion.minor;
  view.setUint16(11, payload.length);

  final mac = pkg_crypto.Hmac(hf(), key);
  final digest = mac.convert(_concatBytes([msg, payload]));
  return Uint8List.fromList(digest.bytes);
}

/// hmacCID calculates a MAC according to
/// https://datatracker.ietf.org/doc/html/rfc9146#section-5.1
Uint8List _cbcHmacCid(
  int epoch,
  int sequenceNumber,
  Version protocolVersion,
  Uint8List payload,
  Uint8List key,
  HashFunc hf,
  Uint8List cid,
) {
  final inner = _unmarshalInnerPlaintext(payload);

  final builder = BytesBuilder()
    ..add(_seqNumPlaceholderBytes)
    ..addByte(ContentType.connectionId.value)
    ..addByte(cid.length & 0xFF)
    ..addByte(ContentType.connectionId.value)
    ..addByte(protocolVersion.major)
    ..addByte(protocolVersion.minor);
  final epochBytes = ByteData(2)..setUint16(0, epoch);
  builder.add(epochBytes.buffer.asUint8List());
  builder.add(_uint48Be(sequenceNumber));
  builder.add(cid);
  final payloadLenBytes = ByteData(2)..setUint16(0, payload.length);
  builder.add(payloadLenBytes.buffer.asUint8List());
  builder.add(inner.content);
  builder.addByte(inner.realType);
  builder.add(Uint8List(inner.zeros));

  final mac = pkg_crypto.Hmac(hf(), key);
  final digest = mac.convert(_concatBytes([builder.toBytes(), payload]));
  return Uint8List.fromList(digest.bytes);
}

/// CBC provides an API to Encrypt/Decrypt DTLS 1.2 Packets.
class Cbc {
  Cbc._(
    this._writeKey,
    this._writeMac,
    this._readKey,
    this._readMac,
    this._hashFunc,
  );

  final Uint8List _writeKey;
  final Uint8List _writeMac;
  final Uint8List _readKey;
  final Uint8List _readMac;
  final HashFunc _hashFunc;

  /// NewCBC creates a DTLS CBC Cipher.
  ///
  /// `localWriteIv`/`remoteWriteIv` mirror Go's constructor signature
  /// (needed there to build the initial `cipher.BlockMode` value), but both
  /// Go and this port call `SetIV`/derive a fresh IV before every real use
  /// (a random IV on encrypt, the wire IV on decrypt) -- so neither
  /// constructor IV ever reaches production output in either language.
  factory Cbc(
    Uint8List localKey,
    Uint8List localWriteIv,
    Uint8List localMac,
    Uint8List remoteKey,
    Uint8List remoteWriteIv,
    Uint8List remoteMac,
    HashFunc hashFunc,
  ) {
    return Cbc._(localKey, localMac, remoteKey, remoteMac, hashFunc);
  }

  /// Encrypt encrypts a DTLS RecordLayer message.
  Uint8List encrypt(RecordLayer pkt, Uint8List raw) {
    final headerSize = pkt.header.size();
    var payload = raw.sublist(headerSize);
    final rawHeader = raw.sublist(0, headerSize);

    final h = pkt.header;
    final Uint8List mac;
    if (h.contentType == ContentType.connectionId) {
      mac = _cbcHmacCid(
        h.epoch,
        h.sequenceNumber,
        h.version,
        payload,
        _writeMac,
        _hashFunc,
        h.connectionId ?? Uint8List(0),
      );
    } else {
      mac = _cbcHmac(
        h.epoch,
        h.sequenceNumber,
        h.contentType,
        h.version,
        payload,
        _writeMac,
        _hashFunc,
      );
    }
    payload = _concatBytes([payload, mac]);

    final paddingLen = _cbcBlockSize - (payload.length % _cbcBlockSize);
    final padding = Uint8List(paddingLen)
      ..fillRange(0, paddingLen, paddingLen - 1);
    payload = _concatBytes([payload, padding]);

    final iv = Uint8List(_cbcBlockSize);
    final rnd = Random.secure();
    for (var i = 0; i < iv.length; i++) {
      iv[i] = rnd.nextInt(256);
    }

    final encrypted = _cbcCryptBlocks(true, _writeKey, iv, payload);
    payload = _concatBytes([iv, encrypted]);

    final result = _concatBytes([rawHeader, payload]);
    final contentLen = result.length - headerSize;
    result[headerSize - 2] = (contentLen >> 8) & 0xFF;
    result[headerSize - 1] = contentLen & 0xFF;
    return result;
  }

  /// Decrypt decrypts a DTLS RecordLayer message.
  Uint8List decrypt(Header header, Uint8List inBytes) {
    header.unmarshal(inBytes);
    if (header.contentType == ContentType.changeCipherSpec) {
      // Nothing to encrypt with ChangeCipherSpec.
      return inBytes;
    }

    var body = inBytes.sublist(header.size());
    final macSize = _hashFunc().convert(const []).bytes.length;
    if (body.length % _cbcBlockSize != 0 ||
        body.length <
            _cbcBlockSize +
                (macSize + 1 > _cbcBlockSize ? macSize + 1 : _cbcBlockSize)) {
      throw const NotEnoughRoomForNonceException();
    }

    final iv = body.sublist(0, _cbcBlockSize);
    body = _cbcCryptBlocks(false, _readKey, iv, body.sublist(_cbcBlockSize));

    final (paddingLen, paddingGood) = examinePadding(body);
    if (paddingGood != 255) {
      throw const InvalidMacException();
    }

    if (body.length < macSize) {
      throw const InvalidMacException();
    }

    final dataEnd = body.length - macSize - paddingLen;
    if (dataEnd < 0) {
      throw const InvalidMacException();
    }

    final expectedMac = body.sublist(dataEnd, dataEnd + macSize);
    Uint8List actualMac;
    try {
      if (header.contentType == ContentType.connectionId) {
        actualMac = _cbcHmacCid(
          header.epoch,
          header.sequenceNumber,
          header.version,
          body.sublist(0, dataEnd),
          _readMac,
          _hashFunc,
          header.connectionId ?? Uint8List(0),
        );
      } else {
        actualMac = _cbcHmac(
          header.epoch,
          header.sequenceNumber,
          header.contentType,
          header.version,
          body.sublist(0, dataEnd),
          _readMac,
          _hashFunc,
        );
      }
    } catch (_) {
      throw const InvalidMacException();
    }

    if (!_hmacEqual(actualMac, expectedMac)) {
      throw const InvalidMacException();
    }

    final result = Uint8List(header.size() + dataEnd);
    result.setRange(0, header.size(), inBytes.sublist(0, header.size()));
    result.setRange(header.size(), result.length, body.sublist(0, dataEnd));
    return result;
  }
}
