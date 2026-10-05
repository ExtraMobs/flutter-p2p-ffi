part of '../../net.dart';

/// `net.IPMask` (`type IPMask []byte`): máscara de rede.
final class IPMask extends Slice<Golang.Uint8>
    implements Stringer, Golang.GoTyped {
  IPMask(Slice<Golang.Uint8> v) : super.alias(v);

  @override
  String get $goType => 'net.IPMask';
  @override
  List<String> get $methods => const ['Size', 'String'];

  /// `Size()`: (bits ligados, total); (0, 0) se não canônica.
  (Golang.Int, Golang.Int) size() {
    final ones = _simpleMaskLength(this);
    if (ones == -1) return (Golang.Int(0), Golang.Int(0));
    return (Golang.Int(ones), Golang.Int(length * 8));
  }

  /// `String()`: hexadecimal sem pontuação, ou `<nil>`.
  @override
  Golang.String string() {
    if (length == 0) return _gs('<nil>');
    return _hexString(this);
  }
}

/// `*net.IPMask`: vista sobre qualquer ponteiro para o valor.
final class IPMask$Ptr extends PtrView<IPMask> implements Stringer {
  IPMask$Ptr(super.$p);

  /// `(*IPMask)(nil)` dentro de uma interface.
  static final IPMask$Ptr $nil = IPMask$Ptr(const NilPtr<IPMask>());

  @override
  String get $goType => '*net.IPMask';
  @override
  List<String> get $methods => const ['Size', 'String'];

  (Golang.Int, Golang.Int) size() => $p.value.size();
  @override
  Golang.String string() => $p.value.string();
}

/// `IPv4Mask(a, b, c, d)`: a máscara de 4 bytes.
IPMask iPv4Mask(
  Golang.Uint8 a,
  Golang.Uint8 b,
  Golang.Uint8 c,
  Golang.Uint8 d,
) => IPMask(_bytes([a.toInt(), b.toInt(), c.toInt(), d.toInt()]));

final IPMask _classAMask = IPMask(_bytes([0xff, 0, 0, 0]));
final IPMask _classBMask = IPMask(_bytes([0xff, 0xff, 0, 0]));
final IPMask _classCMask = IPMask(_bytes([0xff, 0xff, 0xff, 0]));

/// `CIDRMask(ones, bits)`: nil se bits não é 32/128 ou ones fora de 0..bits.
IPMask cidrMask(Golang.Int ones, Golang.Int bits) {
  if (bits != Golang.Int(32) && bits != Golang.Int(128)) {
    return IPMask(Slice.nil(_byteElem));
  }
  if (ones < Golang.Int(0) || ones > bits) return IPMask(Slice.nil(_byteElem));
  return _cidrMask(ones.toInt(), bits.toInt());
}

IPMask _cidrMask(int ones, int bits) {
  if (bits != 32 && bits != 128 || ones < 0 || ones > bits) {
    return IPMask(Slice.nil(_byteElem));
  }
  final l = bits ~/ 8;
  final m = List<int>.filled(l, 0);
  var n = ones;
  for (var i = 0; i < l; i++) {
    if (n >= 8) {
      m[i] = 0xff;
      n -= 8;
      continue;
    }
    m[i] = ~(0xff >> n) & 0xff;
    n = 0;
  }
  return IPMask(_bytes(m));
}

/// `simpleMaskLength`: bits ligados de uma máscara canônica; -1 se não for.
int _simpleMaskLength(_Bytes mask) {
  var n = 0;
  for (var i = 0; i < mask.length; i++) {
    var v = mask[i].toInt();
    if (v == 0xff) {
      n += 8;
      continue;
    }
    while (v & 0x80 != 0) {
      n++;
      v = (v << 1) & 0xff;
    }
    if (v != 0) return -1;
    for (i++; i < mask.length; i++) {
      if (mask[i].toInt() != 0) return -1;
    }
    break;
  }
  return n;
}

/// `net.IPNet`: rede IP (número de rede e máscara).
final class IPNet extends GoStruct<IPNet> implements Addr {
  IPNet({IP? ip, IPMask? mask})
    : ip = ip ?? IP(Slice.nil(_byteElem)),
      mask = mask ?? IPMask(Slice.nil(_byteElem));

  /// `(*IPNet)(nil)` dentro de uma interface.
  static final IPNet $nil = IPNet()..$nilPtr = true;

  /// `IP`: número da rede.
  IP ip;

  /// `Mask`.
  IPMask mask;

  @override
  String get $goType => 'net.IPNet';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Contains', 'Network', 'String'];
  @override
  IPNet $copy() => IPNet(ip: ip, mask: mask);
  @override
  void $set(IPNet o) {
    ip = o.ip;
    mask = o.mask;
  }

  @override
  List<Object?> get $fields => [ip, mask];
  @override
  List<String> get $fieldNames => const ['IP', 'Mask'];
  @override
  List<String> get $fieldTypes => const ['net.IP', 'net.IPMask'];

  /// `networkNumberAndMask(n)`: (nil, nil) se inconsistente.
  (IP?, _Bytes?) _networkNumberAndMask() {
    var ip = this.ip.to4();
    if (ip.isNil) {
      ip = this.ip;
      if (ip.length != _iPv6len) return (null, null);
    }
    _Bytes m = mask;
    switch (m.length) {
      case _iPv4len:
        if (ip.length != _iPv4len) return (null, null);
      case _iPv6len:
        if (ip.length == _iPv4len) m = m.slice(12);
      default:
        return (null, null);
    }
    return (ip, m);
  }

  /// `Contains(ip)`.
  bool contains(IP ip) {
    final IPNet? n = $nilPtr ? null : this;
    final (nn, m) = n!._networkNumberAndMask();
    _Bytes x = ip.to4();
    if (x.isNil) x = ip;
    final l = x.length;
    if (l != (nn?.length ?? 0)) return false;
    for (var i = 0; i < l; i++) {
      if (nn![i].toInt() & m![i].toInt() != x[i].toInt() & m[i].toInt()) {
        return false;
      }
    }
    return true;
  }

  /// `Network()`: `ip+net`.
  @override
  Golang.String network() => _gs('ip+net');

  /// `String()`: `a/n` (máscara canônica) ou `a/hexmask`.
  @override
  Golang.String string() {
    if ($nilPtr) return _gs('<nil>');
    final (nn, m) = _networkNumberAndMask();
    if (nn == null || m == null) return _gs('<nil>');
    final l = _simpleMaskLength(m);
    if (l == -1) return nn.string() + _gs('/') + IPMask(m).string();
    return nn.string() + _gs('/') + strconv.itoa(Golang.Int(l));
  }
}
