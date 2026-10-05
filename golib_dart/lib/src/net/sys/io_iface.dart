part of 'sys_io.dart';

// Interfaces: endereços e prefixos do `NetworkInterface.list` do `dart:io`;
// no linux, índice, MTU, MAC e flags de `/sys/class/net/<nome>/` (e também
// as interfaces sem endereço, que o `dart:io` omite), como o netlink do Go.
// ⚠️ Fora do linux não há MTU, MAC nem flags reais: `up`/`running` valem
// para toda interface listada (o `dart:io` só lista as que têm endereço),
// `loopback` sai dos endereços, o resto fica falso.

Future<List<SysInterface>> _interfaces() async {
  final dartList = await NetworkInterface.list(
    includeLoopback: true,
    includeLinkLocal: true,
  );
  final byName = <String, SysInterface>{};
  for (final ni in dartList) {
    byName[ni.name] = SysInterface(
      index: ni.index,
      name: ni.name,
      up: true,
      running: true,
      loopback: ni.addresses.any((a) => a.isLoopback),
      addrs: [for (final a in ni.addresses) (a.rawAddress, a.prefixLength)],
    );
  }
  if (Platform.isLinux || Platform.isAndroid) {
    final sys = linuxSysInterfaces(_readSys, _listSys);
    if (sys != null) {
      for (final i in sys) {
        i.addrs = byName[i.name]?.addrs ?? [];
      }
      return sys;
    }
  }
  return byName.values.toList()..sort((a, b) => a.index.compareTo(b.index));
}

String? _readSys(String path) {
  try {
    return File(path).readAsStringSync();
  } on FileSystemException {
    return null;
  }
}

List<String>? _listSys(String path) {
  try {
    return [
      for (final e in Directory(path).listSync())
        e.path.substring(e.path.lastIndexOf('/') + 1),
    ];
  } on FileSystemException {
    return null;
  }
}
