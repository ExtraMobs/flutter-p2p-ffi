/// Port of `addr.go` (pion/stun v3.1.1).
///
/// Go's `net.IP` (a variable-length `[]byte`, 4 or 16 bytes, that
/// `MappedAddress.AddToAs`/`GetFromAs` inspect by exact byte length to pick
/// the wire `family` -- `net.IPv4len`/`net.IPv6len`) is ported as a plain
/// [Uint8List] rather than `dart:io`'s `InternetAddress`: `InternetAddress`
/// normalizes to one canonical byte length per its `type` and cannot hold
/// the 4-byte-vs-16-byte distinction this codec's wire format depends on.
/// [MappedAddress.ip]'s string form still reuses
/// `InternetAddress.fromRawAddress(...).address` (stdlib) for formatting.
///
/// Go declares `AlternateServer`, `OtherAddress` and `ResponseOrigin` as
/// `type X MappedAddress` -- distinct named types with the identical
/// underlying struct, whose methods are implemented by pointer-casting a
/// `*X` to `*MappedAddress` (e.g. `a := (*MappedAddress)(s)`) and calling
/// straight through. This is exactly the "type alias declared in the
/// upstream Go repository" carve-out AGENTS.md's typedef ban excepts, so it
/// is ported the equivalent Dart way: each type `extends MappedAddress`,
/// inheriting its fields and `addToAs`/`getFromAs`, and overrides only
/// `addTo`/`getFrom` to target its own [AttrType].
library;

import 'dart:io';
import 'dart:typed_data';

import 'attributes.dart';
import 'errors.dart';
import 'helpers.dart';
import 'message.dart';

String ipToString(Uint8List ip) {
  final type = ip.length == 4
      ? InternetAddressType.IPv4
      : InternetAddressType.IPv6;
  return InternetAddress.fromRawAddress(ip, type: type).address;
}

const int _familyIpv4 = 0x01;
const int _familyIpv6 = 0x02;

/// Port of `ErrBadIPLength` (xoraddr.go:31): `len(IP)` is neither
/// `net.IPv6len` nor `net.IPv4len`.
final class BadIpLengthException implements Exception {
  const BadIpLengthException();

  @override
  String toString() => 'invalid length of IP value';
}

bool isIpv4(Uint8List ip) =>
    isZeros(Uint8List.sublistView(ip, 0, 10)) &&
    ip[10] == 0xff &&
    ip[11] == 0xff;

bool isZeros(Uint8List p) {
  for (final b in p) {
    if (b != 0) return false;
  }
  return true;
}

/// Port of `MappedAddress` (addr.go:19-22): the MAPPED-ADDRESS attribute
/// (RFC 5389 Section 15.1). Used only by servers for backward compatibility
/// with RFC 3489 clients.
class MappedAddress implements Setter, Getter {
  MappedAddress({required this.ip, required this.port});

  Uint8List ip;
  int port;

  /// Port of `MappedAddress.String` (addr.go:63-65).
  @override
  String toString() => '${ipToString(ip)}:$port';

  /// Port of `MappedAddress.GetFromAs` (addr.go:68-95).
  void getFromAs(Message m, AttrType t) {
    final value = m.get(t);
    if (value.length <= 4) throw const UnexpectedEofException();
    final data = ByteData.sublistView(value);
    final family = data.getUint16(0, Endian.big);
    if (family != _familyIpv6 && family != _familyIpv4) {
      throw DecodeException.at(
        'xor-mapped address',
        'family',
        'bad value $family',
      );
    }
    final ipLen = family == _familyIpv6 ? 16 : 4;
    port = data.getUint16(2, Endian.big);
    ip = Uint8List.sublistView(value, 4, 4 + ipLen);
  }

  /// Port of `MappedAddress.AddToAs` (addr.go:98-119).
  void addToAs(Message msg, AttrType attrType) {
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
    final data = ByteData.sublistView(value);
    data.setUint16(0, family, Endian.big);
    // Go writes `uint16(a.Port)`, an implicit truncating conversion; masking
    // here reproduces that instead of letting ByteData.setUint16 throw on
    // an out-of-[0,65535] port.
    data.setUint16(2, port & 0xFFFF, Endian.big);
    value.setRange(4, value.length, effectiveIp);
    msg.add(attrType, value);
  }

  /// Port of `MappedAddress.AddTo` (addr.go:122-124).
  @override
  void addTo(Message m) => addToAs(m, AttrType.mappedAddress);

  /// Port of `MappedAddress.GetFrom` (addr.go:127-129).
  @override
  void getFrom(Message m) => getFromAs(m, AttrType.mappedAddress);
}

/// Port of `AlternateServer` (addr.go:26-29): the ALTERNATE-SERVER
/// attribute (RFC 5389 Section 15.11). See file-level doc comment for why
/// this `extends` [MappedAddress].
final class AlternateServer extends MappedAddress {
  AlternateServer({required super.ip, required super.port});

  /// Port of `AlternateServer.AddTo` (addr.go:47-51).
  @override
  void addTo(Message m) => addToAs(m, AttrType.alternateServer);

  /// Port of `AlternateServer.GetFrom` (addr.go:54-58).
  @override
  void getFrom(Message m) => getFromAs(m, AttrType.alternateServer);
}

/// Port of `OtherAddress` (addr.go:40-43): the OTHER-ADDRESS attribute
/// (RFC 5780 Section 7.4). See file-level doc comment for why this
/// `extends` [MappedAddress].
final class OtherAddress extends MappedAddress {
  OtherAddress({required super.ip, required super.port});

  /// Port of `OtherAddress.AddTo` (addr.go:130-134).
  @override
  void addTo(Message m) => addToAs(m, AttrType.otherAddress);

  /// Port of `OtherAddress.GetFrom` (addr.go:137-141).
  @override
  void getFrom(Message m) => getFromAs(m, AttrType.otherAddress);

  /// Port of `OtherAddress.String` (addr.go:143-145).
  @override
  String toString() => '${ipToString(ip)}:$port';
}

/// Port of `ResponseOrigin` (addr.go:33-36): the RESPONSE-ORIGIN attribute
/// (RFC 5780 Section 7.3). See file-level doc comment for why this
/// `extends` [MappedAddress].
final class ResponseOrigin extends MappedAddress {
  ResponseOrigin({required super.ip, required super.port});

  /// Port of `ResponseOrigin.AddTo` (addr.go:148-152).
  @override
  void addTo(Message m) => addToAs(m, AttrType.responseOrigin);

  /// Port of `ResponseOrigin.GetFrom` (addr.go:155-159).
  @override
  void getFrom(Message m) => getFromAs(m, AttrType.responseOrigin);

  /// Port of `ResponseOrigin.String` (addr.go:161-163).
  @override
  String toString() => '${ipToString(ip)}:$port';
}
