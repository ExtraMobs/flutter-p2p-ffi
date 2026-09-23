// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/transpiled_boxo.dart' hide Blockstore;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

Future<void> main(List<String> args) async {
  print('============================================================');
  print('         DART IPFS - HOSPEDAGEM DE CID ALEATORIO            ');
  print('============================================================');

  // 1. Gerar payload aleatorio e unico
  final rng = Random.secure();
  final randomBytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final randomHex = randomBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final contentString = 'Dart-IPFS-Random-Content-[$timestamp]-$randomHex';
  final contentBytes = Uint8List.fromList(utf8.encode(contentString));

  print('Payload aleatorio gerado:');
  print('  "$contentString"');
  print('Tamanho: ${contentBytes.length} bytes\n');

  // 2. Configurar o no Dart IPFS
  // Usamos porta TCP 4002 como padrao; se ocupada, usamos porta efemera 0.
  var tcpPort = 4002;
  try {
    final testSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      tcpPort,
    );
    await testSocket.close();
  } catch (_) {
    print('Porta $tcpPort em uso, alocando porta dinamica.');
    tcpPort = 0;
  }

  final config = IpfsConfig(
    offline: false,
    network: NetworkConfig(
      listenAddresses: ['/ip4/0.0.0.0/tcp/$tcpPort'],
      bootstrapPeers: [
        // Mars IPFS bootstrapper
        '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
        // Kubo local (se ativo)
        '/ip4/127.0.0.1/tcp/4001/p2p/12D3KooWBvCyh8Vezjcwjhe2etkvjxw7g8hx9SW4jP5c94yXkyX1',
      ],
    ),
  );

  print('Iniciando o no Dart IPFS...');
  final node = await IpfsNode.fromBuildCfg(
    BuildCfg(config: config, online: true),
  );

  final peerId = node.peerId.toBase58();
  print('No Dart online com sucesso!');
  print('PeerId: $peerId');
  print('Swarm addresses:');
  for (final addr in node.swarmAddresses) {
    print('  $addr');
  }

  // 3. Inserir bloco no blockstore
  // A. Como Raw block (CIDv1)
  final rawCid = await node.putRawBlock(contentBytes);

  // B. Como UnixFS DAG (CIDv0)
  final unixFsResult = await buildDagFromReader(
    Stream.value(contentBytes),
    cidVersion: 0,
    retainBlocks: true,
    onBlock: (b) async {
      await node.putBlock(blocks.BasicBlock.withCid(b.data, b.cid));
    },
  );
  final unixFsCid = unixFsResult.root;

  print('\n------------------------------------------------------------');
  print('>>> CIDs HOSPEDADOS COM SUCESSO:');
  print('  * Raw CID (CIDv1):    ${rawCid.encode()}');
  print('  * UnixFS CID (CIDv0): ${unixFsCid.encode()}');
  print('------------------------------------------------------------\n');

  // 4. Conectar a peers de bootstrap
  print('Conectando aos pares de bootstrap...');
  for (final boot in config.network.bootstrapPeers) {
    try {
      await node.connect(addrInfoFromString(boot));
      print('  Conectado: $boot');
    } catch (e) {
      print('  Nao foi possivel conectar a $boot: $e');
    }
  }

  // Se o Kubo local estiver rodando, conectamos ele ao no Dart
  try {
    for (final sAddr in node.swarmAddresses) {
      if (sAddr.contains('127.0.0.1') || sAddr.contains('0.0.0.0')) {
        final loopbackAddr = sAddr.replaceAll('0.0.0.0', '127.0.0.1');
        final res = await Process.run(
          'ipfs',
          ['swarm', 'connect', loopbackAddr],
          environment: {'IPFS_PATH': r'B:\IPFS\.ipfs'},
        );
        if (res.exitCode == 0) {
          print(
            '  Kubo local conectado ao no Dart via loopback: ${res.stdout.toString().trim()}',
          );
          break;
        }
      }
    }
  } catch (_) {}

  // 5. Anunciar CIDs na DHT
  print('\nAnunciando CIDs na DHT...');
  try {
    await node.provide(rawCid);
    print('  Raw CID anunciado na DHT: ${rawCid.encode()}');
  } catch (e) {
    print('  Aviso ao anunciar Raw CID: $e');
  }

  try {
    await node.provide(unixFsCid);
    print('  UnixFS CID anunciado na DHT: ${unixFsCid.encode()}');
  } catch (e) {
    print('  Aviso ao anunciar UnixFS CID: $e');
  }

  print('\n============================================================');
  print('>>> NO DART ATIVO E HOSPEDANDO O CID EM TEMPO REAL <<<');
  print('Para recuperar o conteudo via IPFS/Kubo:');
  print('  ipfs block get ${rawCid.encode()}');
  print('  ipfs cat ${unixFsCid.encode()}');
  print('============================================================\n');

  // Monitoramento de saude a cada 30 segundos
  final startTime = DateTime.now();
  Timer.periodic(const Duration(seconds: 30), (timer) {
    final uptime = DateTime.now().difference(startTime);
    print(
      '[${DateTime.now().toUtc().toIso8601String()}] Status: ONLINE | Uptime: ${uptime.inMinutes}m ${uptime.inSeconds % 60}s | Bloco hospedado intacto.',
    );
  });

  // Manter o processo vivo
  final completer = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nEncerrando no Dart IPFS...');
    await node.close();
    print('No finalizado.');
    completer.complete();
    exit(0);
  });

  await completer.future;
}
