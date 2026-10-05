part of '../../../net/netip.dart';

/// `addrDetail` canonicalizado (`unique.Handle[addrDetail]`): família e
/// zona IPv6, comparado por valor. O `z0` (Addr zero) é `null`.
final class _Z {
  const _Z(this.isV6, this.zoneV6);

  final bool isV6;
  final Golang.String zoneV6;

  @override
  bool operator ==(Object other) =>
      other is _Z && other.isV6 == isV6 && other.zoneV6 == zoneV6;

  @override
  int get hashCode => Object.hash(isV6, zoneV6);
}

/// `z4`.
final _z4 = _Z(false, Golang.String());

/// `z6noz`.
final _z6noz = _Z(true, Golang.String());

const _addrValueMethods = [
  'AppendBinary', 'AppendText', 'AppendTo', 'As16', 'As4', 'AsSlice', //
  'BitLen', 'Compare', 'Is4', 'Is4In6', 'Is6', 'IsGlobalUnicast',
  'IsInterfaceLocalMulticast', 'IsLinkLocalMulticast', 'IsLinkLocalUnicast',
  'IsLoopback', 'IsMulticast', 'IsPrivate', 'IsUnspecified', 'IsValid',
  'Less', 'MarshalBinary', 'MarshalText', 'Next', 'Prefix', 'Prev',
  'String', 'StringExpanded', 'Unmap', 'WithZone', 'Zone',
];

const _addrPtrMethods = [
  'AppendBinary', 'AppendText', 'AppendTo', 'As16', 'As4', 'AsSlice', //
  'BitLen', 'Compare', 'Is4', 'Is4In6', 'Is6', 'IsGlobalUnicast',
  'IsInterfaceLocalMulticast', 'IsLinkLocalMulticast', 'IsLinkLocalUnicast',
  'IsLoopback', 'IsMulticast', 'IsPrivate', 'IsUnspecified', 'IsValid',
  'Less', 'MarshalBinary', 'MarshalText', 'Next', 'Prefix', 'Prev',
  'String', 'StringExpanded', 'Unmap', 'UnmarshalBinary', 'UnmarshalText',
  'WithZone', 'Zone',
];

/// `netip.Addr`: endereço IPv4 ou IPv6 (com zona opcional), por valor.
/// O zero value (`Addr{}`) não é endereço válido.
final class Addr extends GoStruct<Addr>
    implements
        Stringer,
        encoding.TextMarshaler,
        encoding.TextUnmarshaler,
        encoding.BinaryMarshaler,
        encoding.BinaryUnmarshaler {
  /// `netip.Addr{}`.
  Addr() : _addr = _U128.zero, _z = null;

  Addr._(this._addr, this._z);

  /// `(*Addr)(nil)` dentro de uma interface.
  static final Addr $nil = Addr()..$nilPtr = true;

  /// `addr`: o IPv6 (ou o IPv4 mapeado em IPv6) como inteiro big-endian.
  _U128 _addr;

  /// `z`: família e zona.
  _Z? _z;

  @override
  String get $goType => 'netip.Addr';
  @override
  List<String> get $valueMethods => _addrValueMethods;
  @override
  List<String> get $ptrMethods => _addrPtrMethods;
  @override
  Addr $copy() => Addr._(_addr, _z);
  @override
  void $set(Addr o) {
    _addr = o._addr;
    _z = o._z;
  }

  @override
  List<Object?> get $fields => [_addr, _z];
  @override
  List<String> get $fieldNames => const ['addr', 'z'];
  @override
  List<String> get $fieldTypes => const [
    'netip.uint128',
    'unique.Handle[net/netip.addrDetail]',
  ];

  /// Cópia com outro `addr`/`z` (o Go altera a cópia do receptor).
  Addr _with({_U128? addr, _Z? z, bool z0 = false}) =>
      Addr._(addr ?? _addr, z0 ? null : (z ?? _z));

  /// `v4(i)`: o i-ésimo byte do IPv4.
  int _v4(int i) => (_addr.lo >> ((3 - i) * 8)).$lo & 0xff;

  /// `v6(i)`: o i-ésimo byte do IPv6.
  int _v6(int i) {
    final h = (i ~/ 8) % 2 == 0 ? _addr.hi : _addr.lo;
    return (h >> ((7 - i % 8) * 8)).$lo & 0xff;
  }

  /// `v6u16(i)`: a i-ésima palavra de 16 bits do IPv6.
  int _v6u16(int i) {
    final h = (i ~/ 4) % 2 == 0 ? _addr.hi : _addr.lo;
    return (h >> ((3 - i % 4) * 16)).$lo & 0xffff;
  }

  bool get _isZero => _z == null;

  /// `IsValid()`.
  bool isValid() => _z != null;

  int get _bitLen {
    if (_z == null) return 0;
    if (_z == _z4) return 32;
    return 128;
  }

  /// `BitLen()`: 128 (IPv6), 32 (IPv4) ou 0 (zero).
  Golang.Int bitLen() => Golang.Int(_bitLen);

  /// `Zone()`.
  Golang.String zone() => _z == null ? Golang.String() : _z!.zoneV6;

  int _compare(Addr ip2) {
    final f1 = _bitLen, f2 = ip2._bitLen;
    if (f1 < f2) return -1;
    if (f1 > f2) return 1;
    final c = _addr.hi.compareTo(ip2._addr.hi);
    if (c != 0) return c < 0 ? -1 : 1;
    final d = _addr.lo.compareTo(ip2._addr.lo);
    if (d != 0) return d < 0 ? -1 : 1;
    if (is6()) {
      final za = zone(), zb = ip2.zone();
      if (za < zb) return -1;
      if (za > zb) return 1;
    }
    return 0;
  }

  /// `Compare(ip2)`: família, depois endereço, depois zona.
  Golang.Int compare(Addr ip2) => Golang.Int(_compare(ip2));

  /// `Less(ip2)`.
  bool less(Addr ip2) => _compare(ip2) == -1;

  /// `Is4()`.
  bool is4() => _z == _z4;

  /// `Is4In6()`: IPv6 mapeado de IPv4 (`::ffff:a.b.c.d`).
  bool is4In6() =>
      is6() && _addr.hi == _zero64 && _addr.lo >> 32 == Golang.Uint64(0xffff);

  /// `Is6()`.
  bool is6() => _z != null && _z != _z4;

  /// `Unmap()`.
  Addr unmap() => is4In6() ? _with(z: _z4) : $copy();

  /// `WithZone(zone)`.
  Addr withZone(Golang.String zone) {
    if (!is6()) return $copy();
    if (zone.length == 0) return _with(z: _z6noz);
    return _with(z: _Z(true, zone));
  }

  Addr _withoutZone() => is6() ? _with(z: _z6noz) : $copy();

  bool get _hasZone => _z != null && _z != _z4 && _z != _z6noz;

  /// `IsLinkLocalUnicast()`.
  bool isLinkLocalUnicast() {
    final ip = is4In6() ? unmap() : this;
    if (ip.is4()) return ip._v4(0) == 169 && ip._v4(1) == 254;
    if (ip.is6()) return ip._v6u16(0) & 0xffc0 == 0xfe80;
    return false;
  }

  /// `IsLoopback()`.
  bool isLoopback() {
    final ip = is4In6() ? unmap() : this;
    if (ip.is4()) return ip._v4(0) == 127;
    if (ip.is6()) return ip._addr.hi == _zero64 && ip._addr.lo == _one64;
    return false;
  }

  /// `IsMulticast()`.
  bool isMulticast() {
    final ip = is4In6() ? unmap() : this;
    if (ip.is4()) return ip._v4(0) & 0xf0 == 0xe0;
    if (ip.is6()) return ip._addr.hi >> (64 - 8) == Golang.Uint64(0xff);
    return false;
  }

  /// `IsInterfaceLocalMulticast()`.
  bool isInterfaceLocalMulticast() {
    if (is6() && !is4In6()) return _v6u16(0) & 0xff0f == 0xff01;
    return false;
  }

  /// `IsLinkLocalMulticast()`.
  bool isLinkLocalMulticast() {
    final ip = is4In6() ? unmap() : this;
    if (ip.is4()) return ip._v4(0) == 224 && ip._v4(1) == 0 && ip._v4(2) == 0;
    if (ip.is6()) return ip._v6u16(0) & 0xff0f == 0xff02;
    return false;
  }

  /// `IsGlobalUnicast()`.
  bool isGlobalUnicast() {
    if (_z == null) return false;
    final ip = is4In6() ? unmap() : this;
    if (ip.is4() &&
        (ip == iPv4Unspecified() ||
            ip == addrFrom4(_array([255, 255, 255, 255])))) {
      return false;
    }
    return ip != iPv6Unspecified() &&
        !ip.isLoopback() &&
        !ip.isMulticast() &&
        !ip.isLinkLocalUnicast();
  }

  /// `IsPrivate()` (RFC 1918 / RFC 4193).
  bool isPrivate() {
    final ip = is4In6() ? unmap() : this;
    if (ip.is4()) {
      return ip._v4(0) == 10 ||
          (ip._v4(0) == 172 && ip._v4(1) & 0xf0 == 16) ||
          (ip._v4(0) == 192 && ip._v4(1) == 168);
    }
    if (ip.is6()) return ip._v6(0) & 0xfe == 0xfc;
    return false;
  }

  /// `IsUnspecified()`.
  bool isUnspecified() =>
      this == iPv4Unspecified() || this == iPv6Unspecified();

  /// `Prefix(b)`: o prefixo de b bits (endereço mascarado).
  (Prefix, GoError?) prefix(Golang.Int b) {
    if (b < Golang.Int(0)) return (Prefix(), _errNew('negative Prefix bits'));
    if (_z == null) return (Prefix(), null);
    final max = _z == _z4 ? 32 : 128;
    if (b > Golang.Int(max)) {
      return (
        Prefix(),
        ErrorString(
          _gs('prefix length ') +
              strconv.itoa(b) +
              _gs(' too large for IPv${max == 32 ? 4 : 6}'),
        ),
      );
    }
    final effectiveBits = b.toInt() + (max == 32 ? 96 : 0);
    final ip = _with(addr: _addr.and(_mask6(effectiveBits)));
    return (_prefixFrom(ip, b.toInt()), null);
  }

  List<int> get _as16 => [..._beBytes64(_addr.hi), ..._beBytes64(_addr.lo)];

  /// `As16()`.
  GoArray<Golang.Uint8> as16() => _array(_as16);

  /// `As4()`: pânico no zero e em IPv6 não mapeado.
  GoArray<Golang.Uint8> as4() {
    if (_z == _z4 || is4In6()) return _array(_beBytes32(_addr.lo));
    if (_z == null) throw Panic(_gs('As4 called on IP zero value'));
    throw Panic(_gs('As4 called on IPv6 address'));
  }

  /// `AsSlice()`: 4 ou 16 bytes; nil no zero.
  _Bytes asSlice() {
    if (_z == null) return Slice.nil(_byteElem);
    if (_z == _z4) return _array(_beBytes32(_addr.lo)).slice(0);
    return _array(_as16).slice(0);
  }

  /// `Next()`: o endereço seguinte; zero ao estourar.
  Addr next() {
    final ip = _with(addr: _addr.addOne());
    if (ip.is4()) {
      if (ip._addr.lo.$lo == 0) return Addr();
    } else if (ip._addr.isZero) {
      return Addr();
    }
    return ip;
  }

  /// `Prev()`: o endereço anterior; zero ao estourar.
  Addr prev() {
    if (is4()) {
      if (_addr.lo.$lo == 0) return Addr();
    } else if (_addr.isZero) {
      return Addr();
    }
    return _with(addr: _addr.subOne());
  }

  /// `String()`.
  @override
  Golang.String string() {
    if (_z == null) return _gs('invalid IP');
    if (_z == _z4) return _str(_bytesOf(_appendTo4(this, _make0(15))));
    if (is4In6()) return _str(_bytesOf(_appendTo4In6(this, _make0(29))));
    return _str(_bytesOf(_appendTo6(this, _make0(46))));
  }

  /// `AppendTo(b)`.
  _Bytes appendTo(_Bytes b) {
    if (_z == null) return b;
    if (_z == _z4) return _appendTo4(this, b);
    if (is4In6()) return _appendTo4In6(this, b);
    return _appendTo6(this, b);
  }

  /// `StringExpanded()`: IPv6 sem `::` e com 4 dígitos por grupo.
  Golang.String stringExpanded() {
    if (_z == null || _z == _z4) return string();
    var ret = _make0(39);
    for (var i = 0; i < 8; i++) {
      if (i > 0) ret = _app(ret, const [0x3a]);
      ret = _appendHexPad(ret, _v6u16(i));
    }
    if (_z != _z6noz) {
      ret = _app(ret, const [0x25]);
      ret = _app(ret, zone().toBytes());
    }
    return _str(_bytesOf(ret));
  }

  /// `AppendText(b)`.
  (_Bytes, GoError?) appendText(_Bytes b) => (appendTo(b), null);

  /// `MarshalText()`.
  @override
  (_Bytes, GoError?) marshalText() {
    var buf = Slice.of(<Golang.Uint8>[], _byteElem);
    if (_z == _z4) {
      buf = _make0(15);
    } else if (_z != null) {
      buf = _make0(is4In6() ? 29 : 46);
    }
    return appendText(buf);
  }

  /// `(*Addr).UnmarshalText(text)`: vazio dá o zero.
  @override
  GoError? unmarshalText(_Bytes text) {
    if (text.length == 0) {
      $set(Addr());
      return null;
    }
    final (ip, err) = parseAddr(_str(_bytesOf(text)));
    $set(ip);
    return err;
  }

  /// `AppendBinary(b)`.
  (_Bytes, GoError?) appendBinary(_Bytes b) {
    if (_z == _z4) {
      b = _app(b, _beBytes32(_addr.lo));
    } else if (_z != null) {
      b = _app(b, _beBytes64(_addr.hi));
      b = _app(b, _beBytes64(_addr.lo));
      b = _app(b, zone().toBytes());
    }
    return (b, null);
  }

  int get _marshalBinarySize {
    if (_z == null) return 0;
    if (_z == _z4) return 4;
    return 16 + zone().length;
  }

  /// `MarshalBinary()`.
  @override
  (_Bytes, GoError?) marshalBinary() =>
      appendBinary(_make0(_marshalBinarySize));

  /// `(*Addr).UnmarshalBinary(b)`.
  @override
  GoError? unmarshalBinary(_Bytes b) {
    final n = b.length;
    final bs = _bytesOf(b);
    if (n == 0) {
      $set(Addr());
      return null;
    }
    if (n == 4) {
      $set(addrFrom4(_array(bs)));
      return null;
    }
    if (n == 16) {
      $set(addrFrom16(_array(bs)));
      return null;
    }
    if (n > 16) {
      $set(
        addrFrom16(_array(bs.sublist(0, 16))).withZone(_str(bs.sublist(16))),
      );
      return null;
    }
    return _errNew('unexpected slice size');
  }
}
