part of '../../net.dart';

/// `net.HardwareAddr` (`type HardwareAddr []byte`): endereço físico (MAC).
final class HardwareAddr extends Slice<Golang.Uint8>
    implements Stringer, Golang.GoTyped {
  HardwareAddr(Slice<Golang.Uint8> v) : super.alias(v);

  @override
  String get $goType => 'net.HardwareAddr';
  @override
  List<String> get $methods => const ['String'];

  /// `String()`: `aa:bb:cc:...` (vazio sem bytes).
  @override
  Golang.String string() {
    if (length == 0) return Golang.String();
    final buf = <int>[];
    for (var i = 0; i < length; i++) {
      final b = this[i].toInt();
      if (i > 0) buf.add(0x3a);
      buf
        ..add(_hexDigit.codeUnitAt(b >> 4))
        ..add(_hexDigit.codeUnitAt(b & 0xf));
    }
    return _str(buf);
  }
}

/// `*net.HardwareAddr`: vista sobre qualquer ponteiro para o valor.
final class HardwareAddr$Ptr extends PtrView<HardwareAddr> implements Stringer {
  HardwareAddr$Ptr(super.$p);

  /// `(*HardwareAddr)(nil)` dentro de uma interface.
  static final HardwareAddr$Ptr $nil = HardwareAddr$Ptr(
    const NilPtr<HardwareAddr>(),
  );

  @override
  String get $goType => '*net.HardwareAddr';
  @override
  List<String> get $methods => const ['String'];

  @override
  Golang.String string() => $p.value.string();
}

/// `ParseMAC(s)`: EUI-48, EUI-64 ou IPoIB (20 bytes), com `:`, `-` ou `.`.
(HardwareAddr, GoError?) parseMAC(Golang.String s) {
  final hw = _parseMAC(s);
  if (hw == null) {
    return (
      HardwareAddr(Slice.nil(_byteElem)),
      AddrError(err: _gs('invalid MAC address'), addr: s),
    );
  }
  return (HardwareAddr(_bytes(hw)), null);
}

/// O corpo de `ParseMAC` (null no `goto error`).
List<int>? _parseMAC(Golang.String s) {
  if (s.length < 12) return null;
  if (s[2] == 0x3a || s[2] == 0x2d) {
    if ((s.length + 1) % 3 != 0) return null;
    final n = (s.length + 1) ~/ 3;
    if (n != 6 && n != 8 && n != 20) return null;
    final hw = List<int>.filled(n, 0);
    for (var x = 0, i = 0; i < n; i++) {
      final (b, ok) = _xtoi2(s.slice(x), s[2]);
      if (!ok) return null;
      hw[i] = b;
      x += 3;
    }
    return hw;
  }
  if (s[4] == 0x2e) {
    if ((s.length + 1) % 5 != 0) return null;
    final n = 2 * (s.length + 1) ~/ 5;
    if (n != 6 && n != 8 && n != 20) return null;
    final hw = List<int>.filled(n, 0);
    for (var x = 0, i = 0; i < n; i += 2) {
      final (b0, ok0) = _xtoi2(s.slice(x, x + 2), 0);
      if (!ok0) return null;
      hw[i] = b0;
      final (b1, ok1) = _xtoi2(s.slice(x + 2), s[4]);
      if (!ok1) return null;
      hw[i + 1] = b1;
      x += 5;
    }
    return hw;
  }
  if (s.length % 2 != 0) return null;
  final n = s.length ~/ 2;
  if (n != 6 && n != 8 && n != 20) return null;
  final hw = List<int>.filled(n, 0);
  for (var x = 0, i = 0; i < n; i++) {
    final (b, ok) = _xtoi2(s.slice(x, x + 2), 0);
    if (!ok) return null;
    hw[i] = b;
    x += 2;
  }
  return hw;
}
