// "Navegador": `net_sys_test.dart` roda isto compilado (JS e Wasm) no Node
// com `globalThis.process` escondido — o que `sys_js.dart` vê num
// navegador — e exige `operation not supported` em toda operação.
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/sys.dart';

import 'scenarios.dart' show describe;

Future<void> main() async {
  final lo = SysAddr(Uint8List.fromList([127, 0, 0, 1]), 80);
  print('suportado $sysNetSupported');
  final ops = <String, Future<Object?> Function()>{
    'dial': () => sysDialTcp(lo),
    'listen': () => sysListenTcp(lo),
    'udp': () => sysListenUdp(lo),
    'lookupIp': () => sysLookupIp('localhost'),
    'lookupTxt': () => sysLookupTxt('example.com'),
    'interfaces': sysInterfaces,
  };
  for (final MapEntry(:key, :value) in ops.entries) {
    try {
      await value();
      print('$key: ok?!');
    } catch (e) {
      print('$key: ${describe(e)}');
    }
  }
}
