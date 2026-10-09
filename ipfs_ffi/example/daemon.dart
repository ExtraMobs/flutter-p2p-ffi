// Daemon IPFS completo (kubo via FFI): repo em disco, rede libp2p, API RPC e
// gateway HTTP, tudo dentro deste processo Dart.
//
//   dart run example/daemon.dart [repo]   (padrão: ./.ipfs-example)
//
// Na primeira vez faz `ipfs init`. Ctrl-C para.
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/ipfs_ffi.dart';

Future<void> main(List<String> args) async {
  final repo = args.isNotEmpty ? args.first : '.ipfs-example';
  final daemon = await IpfsDaemon.start(repo);
  final id = await daemon.rpc('id') as Map;
  print('daemon no ar: peer ${id['ID']}');
  print('API RPC: ${daemon.api}');
  for (final a in id['Addresses'] as List? ?? const []) {
    print('  ouvindo $a');
  }

  final added = await daemon.rpc(
    'add',
    file: utf8.encode('olá do Dart via FFI\n'),
  ) as Map;
  final cid = added['Hash'];
  print('add: $cid');
  final client = HttpClient();
  final res =
      await (await client.postUrl(daemon.api.resolve('cat?arg=$cid'))).close();
  print('cat: ${await res.transform(utf8.decoder).join()}'.trim());
  client.close();

  print('rodando; Ctrl-C para parar');
  // O kubo também trata o SIGINT; quem receber primeiro derruba o daemon.
  final sigint = ProcessSignal.sigint.watch().first.then((_) => daemon.stop());
  print('daemon saiu com ${await Future.any([daemon.done, sigint])}');
  exit(0);
}
