part of '../../../net/netip.dart';

const _addrPortValueMethods = [
  'Addr', 'AppendBinary', 'AppendText', 'AppendTo', 'Compare', 'IsValid', //
  'MarshalBinary', 'MarshalText', 'Port', 'String',
];

const _addrPortPtrMethods = [
  'Addr', 'AppendBinary', 'AppendText', 'AppendTo', 'Compare', 'IsValid', //
  'MarshalBinary', 'MarshalText', 'Port', 'String', 'UnmarshalBinary',
  'UnmarshalText',
];

/// `netip.AddrPort`: endereço IP e porta, por valor.
final class AddrPort extends GoStruct<AddrPort>
    implements
        Stringer,
        encoding.TextMarshaler,
        encoding.TextUnmarshaler,
        encoding.BinaryMarshaler,
        encoding.BinaryUnmarshaler {
  /// `netip.AddrPort{}`.
  AddrPort() : _ip = Addr(), _port = Golang.Uint16();

  AddrPort._(this._ip, this._port);

  /// `(*AddrPort)(nil)` dentro de uma interface.
  static final AddrPort $nil = AddrPort()..$nilPtr = true;

  Addr _ip;
  Golang.Uint16 _port;

  @override
  String get $goType => 'netip.AddrPort';
  @override
  List<String> get $valueMethods => _addrPortValueMethods;
  @override
  List<String> get $ptrMethods => _addrPortPtrMethods;
  @override
  AddrPort $copy() => AddrPort._(_ip.$copy(), _port);
  @override
  void $set(AddrPort o) {
    _ip.$set(o._ip);
    _port = o._port;
  }

  @override
  List<Object?> get $fields => [_ip, _port];
  @override
  List<String> get $fieldNames => const ['ip', 'port'];
  @override
  List<String> get $fieldTypes => const ['netip.Addr', 'uint16'];

  /// `Addr()`.
  Addr addr$() => _ip.$copy();

  /// `Port()`.
  Golang.Uint16 port() => _port;

  /// `IsValid()`.
  bool isValid() => _ip.isValid();

  /// `Compare(p2)`: endereço, depois porta.
  Golang.Int compare(AddrPort p2) {
    final c = _ip._compare(p2._ip);
    if (c != 0) return Golang.Int(c);
    return Golang.Int(_port.compareTo(p2._port).sign);
  }

  _Bytes _appendPort(_Bytes b) {
    b = _app(b, const [0x3a]);
    return strconv.appendUint(b, Golang.Uint64.from(_port), Golang.Int(10));
  }

  /// `String()`.
  @override
  Golang.String string() {
    _Bytes b;
    final ip = _ip;
    if (ip._z == null) return _gs('invalid AddrPort');
    if (ip._z == _z4) {
      b = _appendTo4(ip, _make0(21));
    } else {
      if (ip.is4In6()) {
        b = _app(_make0(37), const [0x5b]);
        b = _appendTo4In6(ip, b);
      } else {
        b = _app(_make0(54), const [0x5b]);
        b = _appendTo6(ip, b);
      }
      b = _app(b, const [0x5d]);
    }
    return _str(_bytesOf(_appendPort(b)));
  }

  /// `AppendTo(b)`.
  _Bytes appendTo(_Bytes b) {
    final ip = _ip;
    if (ip._z == null) return b;
    if (ip._z == _z4) {
      b = _appendTo4(ip, b);
    } else {
      b = _app(b, const [0x5b]);
      b = ip.is4In6() ? _appendTo4In6(ip, b) : _appendTo6(ip, b);
      b = _app(b, const [0x5d]);
    }
    return _appendPort(b);
  }

  /// `AppendText(b)`.
  (_Bytes, GoError?) appendText(_Bytes b) => (appendTo(b), null);

  /// `MarshalText()`.
  @override
  (_Bytes, GoError?) marshalText() {
    var buf = Slice.of(<Golang.Uint8>[], _byteElem);
    if (_ip._z == _z4) {
      buf = _make0(21);
    } else if (_ip._z != null) {
      buf = _make0(54);
    }
    return appendText(buf);
  }

  /// `(*AddrPort).UnmarshalText(text)`.
  @override
  GoError? unmarshalText(_Bytes text) {
    if (text.length == 0) {
      $set(AddrPort());
      return null;
    }
    final (p, err) = parseAddrPort(_str(_bytesOf(text)));
    $set(p);
    return err;
  }

  /// `AppendBinary(b)`: o endereço e a porta little-endian.
  (_Bytes, GoError?) appendBinary(_Bytes b) {
    final (b2, err) = _ip.appendBinary(b);
    if (err != null) return (Slice.nil(_byteElem), err);
    final p = _port.toInt();
    return (_app(b2, [p & 0xff, p >> 8]), null);
  }

  /// `MarshalBinary()`.
  @override
  (_Bytes, GoError?) marshalBinary() =>
      appendBinary(_make0(_ip._marshalBinarySize + 2));

  /// `(*AddrPort).UnmarshalBinary(b)`.
  @override
  GoError? unmarshalBinary(_Bytes b) {
    if (b.length < 2) return _errNew('unexpected slice size');
    final addr = Addr();
    final err = addr.unmarshalBinary(b.slice(0, b.length - 2));
    if (err != null) return err;
    final lo = b[b.length - 2].toInt(), hi = b[b.length - 1].toInt();
    $set(addrPortFrom(addr, Golang.Uint16(lo | hi << 8)));
    return null;
  }
}

/// `AddrPortFrom(ip, port)`.
AddrPort addrPortFrom(Addr ip, Golang.Uint16 port) =>
    AddrPort._(ip.$copy(), port);

/// `splitAddrPort`: (ip, porta, v6, erro).
(Golang.String, Golang.String, bool, GoError?) _splitAddrPort(Golang.String s) {
  final empty = Golang.String();
  final i = _lastIndexByte(s, 0x3a);
  if (i == -1) return (empty, empty, false, _errNew('not an ip:port'));
  var ip = s.slice(0, i);
  final port = s.slice(i + 1);
  if (ip.length == 0) return (empty, empty, false, _errNew('no IP'));
  if (port.length == 0) return (empty, empty, false, _errNew('no port'));
  var v6 = false;
  if (ip[0] == 0x5b) {
    if (ip.length < 2 || ip[ip.length - 1] != 0x5d) {
      return (empty, empty, false, _errNew('missing ]'));
    }
    ip = ip.slice(1, ip.length - 1);
    v6 = true;
  }
  return (ip, port, v6, null);
}

/// `ParseAddrPort(s)`: `ip:porta`, IPv6 entre colchetes.
(AddrPort, GoError?) parseAddrPort(Golang.String s) {
  final ipp = AddrPort();
  final (ip, port, v6, err) = _splitAddrPort(s);
  if (err != null) return (ipp, err);
  final (port16, err2) = strconv.parseUint(
    port,
    Golang.Int(10),
    Golang.Int(16),
  );
  if (err2 != null) {
    return (
      ipp,
      ErrorString(
        _gs('invalid port ') +
            strconv.quote(port) +
            _gs(' parsing ') +
            strconv.quote(s),
      ),
    );
  }
  ipp._port = Golang.Uint16.from(port16);
  final (a, err3) = parseAddr(ip);
  ipp._ip = a;
  if (err3 != null) return (AddrPort(), err3);
  if (v6 && a.is4()) {
    return (
      AddrPort(),
      ErrorString(
        _gs('invalid ip:port ') +
            strconv.quote(s) +
            _gs(', square brackets can only be used with IPv6 addresses'),
      ),
    );
  } else if (!v6 && a.is6()) {
    return (
      AddrPort(),
      ErrorString(
        _gs('invalid ip:port ') +
            strconv.quote(s) +
            _gs(', IPv6 addresses must be surrounded by square brackets'),
      ),
    );
  }
  return (ipp, null);
}

/// `MustParseAddrPort(s)`.
AddrPort mustParseAddrPort(Golang.String s) {
  final (ip, err) = parseAddrPort(s);
  if (err != null) throw Panic(err);
  return ip;
}
