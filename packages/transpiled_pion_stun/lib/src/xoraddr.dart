/// Port of `xoraddr.go` (pion/stun v3.1.1).
///
/// `isIPv4`/`isZeros`/`ErrBadIPLength` are shared with `addr.go`'s port
/// (addr.dart) rather than duplicated: both files declare byte-identical
/// helpers in Go too (`isIPv4`, `isZeros` are private to the `stun` package
/// and visible to both files simply by being in the same package; a single
/// Go package has no notion of per-file duplication the way separate Dart
/// libraries would).
library;

import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

import 'addr.dart';
import 'attributes.dart';
import 'checks.dart';
import 'errors.dart';
import 'helpers.dart';
import 'message.dart';

const int _familyIpv4 = 0x01;
const int _familyIpv6 = 0x02;

/// Port of `XORMappedAddress` (xoraddr.go:19-22): the XOR-MAPPED-ADDRESS
/// attribute (RFC 5389 Section 15.2).
final class XorMappedAddress implements Setter, Getter {
  XorMappedAddress({required this.ip, required this.port});

  Uint8List ip;
  int port;

  /// Port of `XORMappedAddress.String` (xoraddr.go:24-26).
  @override
  String toString() => '${ipToString(ip)}:$port';

  /// Port of `XORMappedAddress.AddToAs` (xoraddr.go:52-70).
  void addToAs(Message msg, AttrType attr) {
    var family = _familyIpv4;
    var effectiveIp = ip;
    if (ip.length == 16) {
      if (isIpv4(ip)) {
        effectiveIp = Uint8List.sublistView(ip, 12, 16);
      } else {
        family = _familyIpv6;
      }
    } else if (ip.length != 4) {
      throw const BadIpLengthException();
    }
    final value = Uint8List(4 + effectiveIp.length);
    final xorValue = Uint8List(16);
    xorValue.setRange(4, 16, msg.transactionId);
    ByteData.sublistView(xorValue).setUint32(0, magicCookie, Endian.big);
    final data = ByteData.sublistView(value);
    data.setUint16(0, family, Endian.big);
    data.setUint16(2, (port ^ (magicCookie >> 16)) & 0xFFFF, Endian.big);
    xorBytes(
      Uint8List.sublistView(value, 4, 4 + effectiveIp.length),
      effectiveIp,
      xorValue,
    );
    msg.add(attr, value);
  }

  /// Port of `XORMappedAddress.AddTo` (xoraddr.go:39-41). Can throw
  /// [BadIpLengthException] if `ip.length` is invalid.
  @override
  void addTo(Message m) => addToAs(m, AttrType.xorMappedAddress);

  /// Port of `XORMappedAddress.GetFromAs` (xoraddr.go:75-108).
  void getFromAs(Message msg, AttrType attr) {
    final value = msg.get(attr);
    final data = ByteData.sublistView(value);
    final family = data.getUint16(0, Endian.big);
    if (family != _familyIpv6 && family != _familyIpv4) {
      throw DecodeException.at('xor-mapped address', 'family', 'bad value $family');
    }
    final ipLen = family == _familyIpv6 ? 16 : 4;
    if (value.length <= 4) throw const UnexpectedEofException();
    checkOverflow(attr, value.length - 4, ipLen);
    port = data.getUint16(2, Endian.big) ^ (magicCookie >> 16);
    final xorValue = Uint8List(4 + transactionIdSize);
    ByteData.sublistView(xorValue).setUint32(0, magicCookie, Endian.big);
    xorValue.setRange(4, xorValue.length, msg.transactionId);
    final decoded = Uint8List(ipLen);
    xorBytes(decoded, Uint8List.sublistView(value, 4), xorValue);
    ip = decoded;
  }

  /// Port of `XORMappedAddress.GetFrom` (xoraddr.go:110-130). While
  /// decoding, [ip]'s previous value is discarded and replaced (Go reuses
  /// the backing array in place when possible; Dart always allocates the
  /// decoded result fresh, which is simpler and has no observable
  /// difference since [ip] is documented as valid only until the next
  /// mutation, same as upstream).
  @override
  void getFrom(Message m) => getFromAs(m, AttrType.xorMappedAddress);
}
