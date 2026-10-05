/// Interfaces de rede do linux por `/sys/class/net/<nome>/{ifindex,mtu,
/// address,flags}` — o que o Go lê por netlink —, sem os endereços (cada
/// motor junta os seus). Puro Dart: quem chama dá a leitura de arquivo
/// (`dart:io` na VM, `node:fs` no Node).
library;

import 'dart:typed_data';

import 'common.dart';

const _iffUp = 0x1;
const _iffBroadcast = 0x2;
const _iffLoopback = 0x8;
const _iffPointToPoint = 0x10;
const _iffRunning = 0x40;
const _iffMulticast = 0x1000;

/// Interfaces em ordem de índice; `null` se `/sys/class/net` não existe.
List<SysInterface>? linuxSysInterfaces(
  String? Function(String path) readFile,
  List<String>? Function(String dir) listDir,
) {
  const base = '/sys/class/net';
  final names = listDir(base);
  if (names == null || names.isEmpty) return null;
  final out = <SysInterface>[];
  for (final name in names) {
    int? num(String f, {int radix = 10}) {
      final t = readFile('$base/$name/$f')?.trim();
      if (t == null) return null;
      return int.tryParse(
        t.startsWith('0x') ? t.substring(2) : t,
        radix: radix,
      );
    }

    final index = num('ifindex');
    if (index == null) continue;
    final flags = num('flags', radix: 16) ?? 0;
    out.add(
      SysInterface(
        index: index,
        name: name,
        mtu: num('mtu') ?? 0,
        hardwareAddr: _mac(readFile('$base/$name/address')),
        up: flags & _iffUp != 0,
        broadcast: flags & _iffBroadcast != 0,
        loopback: flags & _iffLoopback != 0,
        pointToPoint: flags & _iffPointToPoint != 0,
        running: flags & _iffRunning != 0,
        multicast: flags & _iffMulticast != 0,
      ),
    );
  }
  out.sort((a, b) => a.index.compareTo(b.index));
  return out;
}

/// `aa:bb:...`; todo zero vira vazio, como no Go (`IFLA_ADDRESS` nulo).
Uint8List _mac(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return Uint8List(0);
  final parts = t.split(':');
  final out = Uint8List(parts.length);
  for (var i = 0; i < parts.length; i++) {
    final v = int.tryParse(parts[i], radix: 16);
    if (v == null) return Uint8List(0);
    out[i] = v;
  }
  return out.every((b) => b == 0) ? Uint8List(0) : out;
}
