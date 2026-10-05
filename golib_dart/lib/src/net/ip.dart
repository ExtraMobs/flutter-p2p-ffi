part of '../../net.dart';

const _ipValueMethods = [
  'AppendText', 'DefaultMask', 'Equal', 'IsGlobalUnicast', //
  'IsInterfaceLocalMulticast', 'IsLinkLocalMulticast', 'IsLinkLocalUnicast',
  'IsLoopback', 'IsMulticast', 'IsPrivate', 'IsUnspecified', 'MarshalText',
  'Mask', 'String', 'To16', 'To4',
];

const _ipPtrMethods = [..._ipValueMethods, 'UnmarshalText'];

/// `IPv4len`, `IPv6len` (o g2d dobra as constantes; o shim as usa).
const _iPv4len = 4, _iPv6len = 16;

/// `net.IP` (`type IP []byte`): endereço IPv4 (4 ou 16 bytes) ou IPv6.
final class IP extends Slice<Golang.Uint8>
    implements Stringer, encoding.TextMarshaler, Golang.GoTyped {
  IP(Slice<Golang.Uint8> v) : super.alias(v);

  @override
  String get $goType => 'net.IP';
  @override
  List<String> get $methods => _ipValueMethods;

  int _b(int i) => this[i].toInt();

  /// `IsUnspecified()`: 0.0.0.0 ou ::.
  bool isUnspecified() => equal(iPv4zero) || equal(iPv6unspecified);

  /// `IsLoopback()`.
  bool isLoopback() {
    final ip4 = to4();
    if (!ip4.isNil) return ip4._b(0) == 127;
    return equal(iPv6loopback);
  }

  /// `IsPrivate()` (RFC 1918 / RFC 4193).
  bool isPrivate() {
    final ip4 = to4();
    if (!ip4.isNil) {
      return ip4._b(0) == 10 ||
          (ip4._b(0) == 172 && ip4._b(1) & 0xf0 == 16) ||
          (ip4._b(0) == 192 && ip4._b(1) == 168);
    }
    return length == _iPv6len && _b(0) & 0xfe == 0xfc;
  }

  /// `IsMulticast()`.
  bool isMulticast() {
    final ip4 = to4();
    if (!ip4.isNil) return ip4._b(0) & 0xf0 == 0xe0;
    return length == _iPv6len && _b(0) == 0xff;
  }

  /// `IsInterfaceLocalMulticast()`.
  bool isInterfaceLocalMulticast() =>
      length == _iPv6len && _b(0) == 0xff && _b(1) & 0x0f == 0x01;

  /// `IsLinkLocalMulticast()`.
  bool isLinkLocalMulticast() {
    final ip4 = to4();
    if (!ip4.isNil) {
      return ip4._b(0) == 224 && ip4._b(1) == 0 && ip4._b(2) == 0;
    }
    return length == _iPv6len && _b(0) == 0xff && _b(1) & 0x0f == 0x02;
  }

  /// `IsLinkLocalUnicast()`.
  bool isLinkLocalUnicast() {
    final ip4 = to4();
    if (!ip4.isNil) return ip4._b(0) == 169 && ip4._b(1) == 254;
    return length == _iPv6len && _b(0) == 0xfe && _b(1) & 0xc0 == 0x80;
  }

  /// `IsGlobalUnicast()`.
  bool isGlobalUnicast() =>
      (length == _iPv4len || length == _iPv6len) &&
      !equal(iPv4bcast) &&
      !isUnspecified() &&
      !isLoopback() &&
      !isMulticast() &&
      !isLinkLocalUnicast();

  /// `To4()`: os 4 bytes do IPv4 (também do IPv4 mapeado), ou nil.
  IP to4() {
    if (length == _iPv4len) return this;
    if (length == _iPv6len &&
        _isZeros(this, 0, 10) &&
        _b(10) == 0xff &&
        _b(11) == 0xff) {
      return IP(slice(12, 16));
    }
    return IP(Slice.nil(_byteElem));
  }

  /// `To16()`: os 16 bytes, ou nil.
  IP to16() {
    if (length == _iPv4len) return iPv4(this[0], this[1], this[2], this[3]);
    if (length == _iPv6len) return this;
    return IP(Slice.nil(_byteElem));
  }

  /// `DefaultMask()`: a máscara de classe do IPv4, ou nil.
  IPMask defaultMask() {
    final ip = to4();
    if (ip.isNil) return IPMask(Slice.nil(_byteElem));
    if (ip._b(0) < 0x80) return _classAMask;
    if (ip._b(0) < 0xC0) return _classBMask;
    return _classCMask;
  }

  /// `Mask(mask)`: ip & mask, ou nil se os tamanhos não casam.
  IP mask(IPMask mask) {
    _Bytes m = mask;
    _Bytes ip = this;
    if (m.length == _iPv6len && ip.length == _iPv4len && _allFF(m, 0, 12)) {
      m = m.slice(12);
    }
    if (m.length == _iPv4len &&
        ip.length == _iPv6len &&
        _equalAt(ip, 0, _v4InV6Prefix)) {
      ip = ip.slice(12);
    }
    final n = ip.length;
    if (n != m.length) return IP(Slice.nil(_byteElem));
    return IP(
      _bytes([for (var i = 0; i < n; i++) ip[i].toInt() & m[i].toInt()]),
    );
  }

  /// `String()`: `<nil>`, `?hex`, decimal com pontos ou IPv6 (RFC 5952).
  @override
  Golang.String string() {
    if (length == 0) return _gs('<nil>');
    if (length != _iPv4len && length != _iPv6len) {
      return _gs('?') + _hexString(this);
    }
    final buf = _make0(length == _iPv4len ? 15 : 39);
    return _str(_bytesOf(_appendTo(buf)));
  }

  /// `appendTo(b)`: pela formatação do `netip.Addr`.
  _Bytes _appendTo(_Bytes b) {
    _Bytes ip = this;
    final p4 = to4();
    if (p4.length == _iPv4len) ip = p4;
    final (addr, _) = netip.addrFromSlice(ip);
    return addr.appendTo(b);
  }

  /// `AppendText(b)`.
  (_Bytes, GoError?) appendText(_Bytes b) {
    if (length == 0) return (b, null);
    if (length != _iPv4len && length != _iPv6len) {
      return (
        b,
        AddrError(err: _gs('invalid IP address'), addr: _hexString(this)),
      );
    }
    return (_appendTo(b), null);
  }

  /// `MarshalText()`.
  @override
  (_Bytes, GoError?) marshalText() {
    final (b, err) = appendText(_make0(24));
    if (err != null) return (Slice.nil(_byteElem), err);
    return (b, null);
  }

  /// `Equal(x)`: o IPv4 e o mesmo IPv4 em 16 bytes são iguais.
  bool equal(IP x) {
    if (length == x.length) return _equalAt(this, 0, _bytesOf(x));
    if (length == _iPv4len && x.length == _iPv6len) {
      return _equalAt(x, 0, _v4InV6Prefix) && _equalAt(x, 12, _bytesOf(this));
    }
    if (length == _iPv6len && x.length == _iPv4len) {
      return _equalAt(this, 0, _v4InV6Prefix) &&
          _equalAt(this, 12, _bytesOf(x));
    }
    return false;
  }
}

/// `*net.IP`: vista sobre qualquer ponteiro para o valor.
final class IP$Ptr extends PtrView<IP>
    implements Stringer, encoding.TextMarshaler, encoding.TextUnmarshaler {
  IP$Ptr(super.$p);

  /// `(*IP)(nil)` dentro de uma interface.
  static final IP$Ptr $nil = IP$Ptr(const NilPtr<IP>());

  @override
  String get $goType => '*net.IP';
  @override
  List<String> get $methods => _ipPtrMethods;

  (_Bytes, GoError?) appendText(_Bytes p0) => $p.value.appendText(p0);
  IPMask defaultMask() => $p.value.defaultMask();
  bool equal(IP p0) => $p.value.equal(p0);
  bool isGlobalUnicast() => $p.value.isGlobalUnicast();
  bool isInterfaceLocalMulticast() => $p.value.isInterfaceLocalMulticast();
  bool isLinkLocalMulticast() => $p.value.isLinkLocalMulticast();
  bool isLinkLocalUnicast() => $p.value.isLinkLocalUnicast();
  bool isLoopback() => $p.value.isLoopback();
  bool isMulticast() => $p.value.isMulticast();
  bool isPrivate() => $p.value.isPrivate();
  bool isUnspecified() => $p.value.isUnspecified();
  @override
  (_Bytes, GoError?) marshalText() => $p.value.marshalText();
  IP mask(IPMask p0) => $p.value.mask(p0);
  @override
  Golang.String string() => $p.value.string();
  IP to16() => $p.value.to16();
  IP to4() => $p.value.to4();

  /// `(*IP).UnmarshalText(text)`: vazio dá nil.
  @override
  GoError? unmarshalText(_Bytes text) {
    if (text.length == 0) {
      value = IP(Slice.nil(_byteElem));
      return null;
    }
    final s = _str(_bytesOf(text));
    final x = parseIP(s);
    if (x.isNil) return ParseError(type: _gs('IP address'), text: s);
    value = x;
    return null;
  }
}
