part of '../../../net/netip.dart';

const _prefixValueMethods = [
  'Addr', 'AppendBinary', 'AppendText', 'AppendTo', 'Bits', 'Compare', //
  'Contains', 'IsSingleIP', 'IsValid', 'MarshalBinary', 'MarshalText',
  'Masked', 'Overlaps', 'String',
];

const _prefixPtrMethods = [
  'Addr', 'AppendBinary', 'AppendText', 'AppendTo', 'Bits', 'Compare', //
  'Contains', 'IsSingleIP', 'IsValid', 'MarshalBinary', 'MarshalText',
  'Masked', 'Overlaps', 'String', 'UnmarshalBinary', 'UnmarshalText',
];

/// `netip.Prefix`: endereço e tamanho de prefixo (CIDR), por valor.
final class Prefix extends GoStruct<Prefix>
    implements
        Stringer,
        encoding.TextMarshaler,
        encoding.TextUnmarshaler,
        encoding.BinaryMarshaler,
        encoding.BinaryUnmarshaler {
  /// `netip.Prefix{}`.
  Prefix() : _ip = Addr(), _bitsPlusOne = 0;

  Prefix._(this._ip, this._bitsPlusOne);

  /// `(*Prefix)(nil)` dentro de uma interface.
  static final Prefix $nil = Prefix()..$nilPtr = true;

  Addr _ip;

  /// `bitsPlusOne` (uint8): 0 é prefixo inválido.
  int _bitsPlusOne;

  @override
  String get $goType => 'netip.Prefix';
  @override
  List<String> get $valueMethods => _prefixValueMethods;
  @override
  List<String> get $ptrMethods => _prefixPtrMethods;
  @override
  Prefix $copy() => Prefix._(_ip.$copy(), _bitsPlusOne);
  @override
  void $set(Prefix o) {
    _ip.$set(o._ip);
    _bitsPlusOne = o._bitsPlusOne;
  }

  @override
  List<Object?> get $fields => [_ip, _bitsPlusOne];
  @override
  List<String> get $fieldNames => const ['ip', 'bitsPlusOne'];
  @override
  List<String> get $fieldTypes => const ['netip.Addr', 'uint8'];

  /// `Addr()`.
  Addr addr$() => _ip.$copy();

  int get _bits => _bitsPlusOne - 1;

  /// `Bits()`: -1 se inválido.
  Golang.Int bits() => Golang.Int(_bits);

  /// `IsValid()`.
  bool isValid() => _bitsPlusOne > 0;

  bool get _isZero => this == Prefix();

  /// `IsSingleIP()`.
  bool isSingleIP() => isValid() && _bits == _ip._bitLen;

  /// `Compare(p2)`: endereço mascarado, bits, endereço.
  Golang.Int compare(Prefix p2) {
    final c = _masked()._ip._compare(p2._masked()._ip);
    if (c != 0) return Golang.Int(c);
    final d = _bits.compareTo(p2._bits);
    if (d != 0) return Golang.Int(d.sign);
    return Golang.Int(_ip._compare(p2._ip));
  }

  Prefix _masked() => _ip.prefix(Golang.Int(_bits)).$1;

  /// `Masked()`: o prefixo com os bits de host zerados.
  Prefix masked() => _masked();

  /// `Contains(ip)`.
  bool contains(Addr ip) {
    if (!isValid() || ip._hasZone) return false;
    final f1 = _ip._bitLen, f2 = ip._bitLen;
    if (f1 == 0 || f2 == 0 || f1 != f2) return false;
    if (ip.is4()) {
      return ((ip._addr.lo ^ _ip._addr.lo) >> ((32 - _bits) & 63)).$lo == 0;
    }
    return ip._addr.xor(_ip._addr).and(_mask6(_bits)).isZero;
  }

  /// `Overlaps(o)`.
  bool overlaps(Prefix o) {
    if (!isValid() || !o.isValid()) return false;
    if (this == o) return true;
    if (_ip.is4() != o._ip.is4()) return false;
    final pb = _bits, ob = o._bits;
    final minBits = pb < ob ? pb : ob;
    if (minBits == 0) return true;
    final (p2, err) = _ip.prefix(Golang.Int(minBits));
    if (err != null) return false;
    final (o2, err2) = o._ip.prefix(Golang.Int(minBits));
    if (err2 != null) return false;
    return p2._ip == o2._ip;
  }

  /// `AppendTo(b)`.
  _Bytes appendTo(_Bytes b) {
    if (_isZero) return b;
    if (!isValid()) return _app(b, 'invalid Prefix'.codeUnits);
    if (_ip._z == _z4) {
      b = _appendTo4(_ip, b);
    } else if (_ip.is4In6()) {
      b = _app(b, '::ffff:'.codeUnits);
      b = _appendTo4(_ip.unmap(), b);
    } else {
      b = _appendTo6(_ip, b);
    }
    b = _app(b, const [0x2f]);
    return _appendDecimal(b, _bits & 0xff);
  }

  /// `AppendText(b)`.
  (_Bytes, GoError?) appendText(_Bytes b) => (appendTo(b), null);

  /// `MarshalText()`.
  @override
  (_Bytes, GoError?) marshalText() {
    var buf = Slice.of(<Golang.Uint8>[], _byteElem);
    if (_ip._z == _z4) {
      buf = _make0(18);
    } else if (_ip._z != null) {
      buf = _make0(50);
    }
    return appendText(buf);
  }

  /// `(*Prefix).UnmarshalText(text)`.
  @override
  GoError? unmarshalText(_Bytes text) {
    if (text.length == 0) {
      $set(Prefix());
      return null;
    }
    final (p, err) = parsePrefix(_str(_bytesOf(text)));
    $set(p);
    return err;
  }

  /// `AppendBinary(b)`: o endereço sem zona e um byte de bits.
  (_Bytes, GoError?) appendBinary(_Bytes b) {
    final (b2, err) = _ip._withoutZone().appendBinary(b);
    if (err != null) return (Slice.nil(_byteElem), err);
    return (_app(b2, [_bits & 0xff]), null);
  }

  /// `MarshalBinary()`.
  @override
  (_Bytes, GoError?) marshalBinary() =>
      appendBinary(_make0(_ip._withoutZone()._marshalBinarySize + 1));

  /// `(*Prefix).UnmarshalBinary(b)`.
  @override
  GoError? unmarshalBinary(_Bytes b) {
    if (b.length < 1) return _errNew('unexpected slice size');
    final addr = Addr();
    final err = addr.unmarshalBinary(b.slice(0, b.length - 1));
    if (err != null) return err;
    $set(_prefixFrom(addr, b[b.length - 1].toInt()));
    return null;
  }

  /// `String()`: `a/n`, ou `invalid Prefix`.
  @override
  Golang.String string() {
    if (!isValid()) return _gs('invalid Prefix');
    return _ip.string() + _gs('/') + strconv.itoa(Golang.Int(_bits));
  }
}

Prefix _prefixFrom(Addr ip, int bits) {
  var bitsPlusOne = 0;
  if (!ip._isZero && bits >= 0 && bits <= ip._bitLen) bitsPlusOne = bits + 1;
  return Prefix._(ip._withoutZone(), bitsPlusOne);
}

/// `PrefixFrom(ip, bits)`: sem mascarar; bits fora do intervalo dão um
/// Prefix inválido.
Prefix prefixFrom(Addr ip, Golang.Int bits) {
  if (bits < Golang.Int(0) || bits > Golang.Int(128)) {
    return _prefixFrom(ip, -1);
  }
  return _prefixFrom(ip, bits.toInt());
}

/// `parsePrefixError` (não exportado).
final class _ParsePrefixError extends GoStruct<_ParsePrefixError>
    implements GoError {
  _ParsePrefixError(this.in$, this.msg) {
    $isValue = true;
  }

  Golang.String in$;
  Golang.String msg;

  @override
  String get $goType => 'netip.parsePrefixError';
  @override
  List<String> get $valueMethods => const ['Error'];
  @override
  List<String> get $ptrMethods => const ['Error'];
  @override
  _ParsePrefixError $copy() => _ParsePrefixError(in$, msg);
  @override
  void $set(_ParsePrefixError o) {
    in$ = o.in$;
    msg = o.msg;
  }

  @override
  List<Object?> get $fields => [in$, msg];
  @override
  List<String> get $fieldNames => const ['in', 'msg'];
  @override
  List<String> get $fieldTypes => const ['string', 'string'];

  @override
  Golang.String error() =>
      _gs('netip.ParsePrefix(') + strconv.quote(in$) + _gs('): ') + msg;
}

/// `ParsePrefix(s)`: `a/n` (sem mascarar; zona IPv6 é erro).
(Prefix, GoError?) parsePrefix(Golang.String s) {
  final i = _lastIndexByte(s, 0x2f);
  if (i < 0) return (Prefix(), _ParsePrefixError(s, _gs("no '/'")));
  final (ip, err) = parseAddr(s.slice(0, i));
  if (err != null) return (Prefix(), _ParsePrefixError(s, err.error()));
  if (ip.is6() && ip._z != _z6noz) {
    return (
      Prefix(),
      _ParsePrefixError(s, _gs('IPv6 zones cannot be present in a prefix')),
    );
  }
  final bitsStr = s.slice(i + 1);
  final bad = _ParsePrefixError(
    s,
    _gs('bad bits after slash: ') + strconv.quote(bitsStr),
  );
  if (bitsStr.length > 1 && (bitsStr[0] < 0x31 || bitsStr[0] > 0x39)) {
    return (Prefix(), bad);
  }
  final (bits, err2) = strconv.atoi(bitsStr);
  if (err2 != null) return (Prefix(), bad);
  final maxBits = ip.is6() ? 128 : 32;
  if (bits < Golang.Int(0) || bits > Golang.Int(maxBits)) {
    return (Prefix(), _ParsePrefixError(s, _gs('prefix length out of range')));
  }
  return (_prefixFrom(ip, bits.toInt()), null);
}

/// `MustParsePrefix(s)`.
Prefix mustParsePrefix(Golang.String s) {
  final (p, err) = parsePrefix(s);
  if (err != null) throw Panic(err);
  return p;
}
