part of '../../net.dart';

// Interfaces de rede (D4, porta de `interface.go`) sobre `sys.sysInterfaces`.
// No Dart a lista vem por `Future`, então `Interfaces`, `InterfaceAddrs`,
// `InterfaceByIndex`/`ByName` e `(*Interface).Addrs` suspendem.
// ⚠️ O que cada plataforma não informa (prefixo, MAC, flags no `dart:io`)
// está documentado em `src/net/sys/`.

/// `net.Flags`.
final class Flags extends Golang.Uint64Base<Flags> implements fmt.Stringer {
  Flags([int v = 0]) : super(v);
  Flags.from(Golang.IntBase v) : super.from(v);
  Flags.fromBigInt(BigInt v) : super.fromBigInt(v);
  Flags._(super.$hi, super.$lo) : super.raw();

  @override
  Flags $make(int hi, int lo) => Flags._(hi, lo);

  @override
  String get $goType => 'net.Flags';

  @override
  List<String> get $methods => const ['String'];

  static const _names = [
    'up',
    'broadcast',
    'loopback',
    'pointtopoint',
    'multicast',
    'running',
  ];

  /// `String()`: `up|broadcast|...`, ou `0`.
  @override
  Golang.String string() {
    final v = toInt();
    final parts = [
      for (var i = 0; i < _names.length; i++)
        if (v & (1 << i) != 0) _names[i],
    ];
    return _s(parts.isEmpty ? '0' : parts.join('|'));
  }
}

/// `net.Interface`.
final class Interface extends GoStruct<Interface> {
  Interface({
    Golang.Int? index,
    Golang.Int? mtu,
    Golang.String? name,
    HardwareAddr? hardwareAddr,
    Flags? flags,
  }) : index = index ?? Golang.Int(),
       mtu = mtu ?? Golang.Int(),
       name = name ?? Golang.String(),
       hardwareAddr = hardwareAddr ?? HardwareAddr(Slice.nil(_byteElem)),
       flags = flags ?? Flags();

  /// `(*Interface)(nil)` dentro de uma interface.
  static final Interface $nil = Interface()..$nilPtr = true;

  Golang.Int index;
  Golang.Int mtu;
  Golang.String name;
  HardwareAddr hardwareAddr;
  Flags flags;

  /// Os endereços que o `sys` deu (o Go os pede ao kernel de novo).
  List<(Uint8List, int)> _addrs = const [];

  @override
  String get $goType => 'net.Interface';
  @override
  List<String> get $ptrMethods => const ['Addrs'];
  @override
  Interface $copy() => Interface(
    index: index,
    mtu: mtu,
    name: name,
    hardwareAddr: hardwareAddr,
    flags: flags,
  ).._addrs = _addrs;
  @override
  void $set(Interface o) {
    index = o.index;
    mtu = o.mtu;
    name = o.name;
    hardwareAddr = o.hardwareAddr;
    flags = o.flags;
    _addrs = o._addrs;
  }

  @override
  List<Object?> get $fields => [index, mtu, name, hardwareAddr, flags];
  @override
  List<String> get $fieldNames => const [
    'Index',
    'MTU',
    'Name',
    'HardwareAddr',
    'Flags',
  ];

  /// `(*Interface).Addrs()`: os endereços como `*IPNet`.
  Future<(Slice<Addr?>, GoError?)> addrs() async {
    final fresh = await _byIndex(index.toInt());
    final list = fresh?._addrs ?? _addrs;
    return (_ipNets(list), null);
  }
}

Slice<Addr?> _ipNets(List<(Uint8List, int)> list) => Slice.of([
  for (final (ip, bits) in list)
    IPNet(
      ip: _ipOf(ip),
      mask: cidrMask(Golang.Int(bits), Golang.Int(ip.length * 8)),
    ) as Addr?,
], _addrElem);

const _addrElem = Elem<Addr?>(16, zeroNull, pointers: true);
final _ifaceElem = Elem<Interface>(
  80,
  Interface.new,
  pointers: true,
  value: true,
);

Interface _interfaceOf(sys.SysInterface i) {
  var f = 0;
  if (i.up) f |= 1;
  if (i.broadcast) f |= 2;
  if (i.loopback) f |= 4;
  if (i.pointToPoint) f |= 8;
  if (i.multicast) f |= 16;
  if (i.running) f |= 32;
  return Interface(
    index: Golang.Int(i.index),
    mtu: Golang.Int(i.mtu),
    name: _s(i.name),
    hardwareAddr: HardwareAddr(
      i.hardwareAddr.isEmpty
          ? Slice.nil(_byteElem)
          : Slice.of([
              for (final b in i.hardwareAddr) Golang.Uint8(b),
            ], _byteElem),
    ),
    flags: Flags(f),
  ).._addrs = i.addrs;
}

Future<Interface?> _byIndex(int index) async {
  for (final i in await sys.sysInterfaces()) {
    if (i.index == index) return _interfaceOf(i);
  }
  return null;
}

GoError _ifaceOp(GoError err) => _opError('route', 'ip+net', null, null, err);

/// `net.Interfaces()`.
Future<(Slice<Interface>, GoError?)> interfaces() async {
  try {
    final list = await sys.sysInterfaces();
    return (
      Slice.of([for (final i in list) _interfaceOf(i)], _ifaceElem),
      null,
    );
  } on Object catch (e) {
    return (Slice<Interface>.nil(_ifaceElem), _ifaceOp(_sysError(e)));
  }
}

/// `net.InterfaceAddrs()`.
Future<(Slice<Addr?>, GoError?)> interfaceAddrs() async {
  try {
    final list = await sys.sysInterfaces();
    return (_ipNets([for (final i in list) ...i.addrs]), null);
  } on Object catch (e) {
    return (Slice<Addr?>.nil(_addrElem), _ifaceOp(_sysError(e)));
  }
}

/// `errNoSuchInterface` do Go.
final GoError _errNoSuchInterface = ErrorString(
  _s('no such network interface'),
);

/// `net.InterfaceByIndex(index)`.
Future<(Interface?, GoError?)> interfaceByIndex(Golang.Int index) async {
  if (index.toInt() <= 0) return (null, _ifaceOp(_errInvalidInterfaceIndex));
  try {
    final i = await _byIndex(index.toInt());
    return i == null ? (null, _ifaceOp(_errNoSuchInterface)) : (i, null);
  } on Object catch (e) {
    return (null, _ifaceOp(_sysError(e)));
  }
}

final GoError _errInvalidInterfaceIndex = ErrorString(
  _s('invalid network interface index'),
);
final GoError _errInvalidInterfaceName = ErrorString(
  _s('invalid network interface name'),
);

/// `net.InterfaceByName(name)`.
Future<(Interface?, GoError?)> interfaceByName(Golang.String name) async {
  if (name.toString().isEmpty)
    return (null, _ifaceOp(_errInvalidInterfaceName));
  try {
    for (final i in await sys.sysInterfaces()) {
      if (i.name == name.toString()) return (_interfaceOf(i), null);
    }
    return (null, _ifaceOp(_errNoSuchInterface));
  } on Object catch (e) {
    return (null, _ifaceOp(_sysError(e)));
  }
}
