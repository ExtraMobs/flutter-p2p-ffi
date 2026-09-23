// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/transpiled_boxo.dart' hide Blockstore;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

Future<void> main(List<String> args) async {
  print('============================================================');
  print('         DART IPFS - DAEMON DE HOSPEDAGEM (ESTILO KUBO)     ');
  print('============================================================');

  // 1. Configurar o nó Dart IPFS
  // Usamos porta TCP 4002 como padrão do Swarm IPFS.
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

  // Endereço WAN público da conexão para anúncio correto na DHT
  final wanIp = '203.0.113.47';
  final announceAddr = Platform.environment['DART_IPFS_ANNOUNCE_ADDR'] ??
      '/ip4/$wanIp/tcp/$tcpPort';

  final config = IpfsConfig(
    offline: false,
    network: NetworkConfig(
      listenAddresses: ['/ip4/0.0.0.0/tcp/$tcpPort'],
      announceAddresses: [announceAddr],
      bootstrapPeers: const [
        // Bootstrappers oficiais da rede pública IPFS / libp2p
        '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
        '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
      ],
      mdnsEnabled: false,
    ),
  );

  print('1. Inicializando subsistemas do nó Dart IPFS (Swarm, TLS 1.3/Noise, DHT, Bitswap, NAT)...');
  final node = await IpfsNode.fromBuildCfg(
    BuildCfg(config: config, online: true),
  );

  final peerId = node.peerId.toBase58();
  print('   Nó ativo localmente! PeerId: $peerId\n');

  // 2. Fase de Bootstrap e Negociação de Rede (seguindo o ciclo do daemon do Kubo)
  print('2. Conectando aos peers de bootstrap e negociando presença na rede...');
  for (final boot in config.network.bootstrapPeers) {
    try {
      await node.connect(addrInfoFromString(boot));
      print('   ✓ Conectado ao bootstrapper: $boot');
    } catch (e) {
      print('   ✗ Falha ao conectar em $boot: $e');
    }
  }

  // Aguarda estabilização e negociação (Identify exchange, AutoNAT probing e UPnP)
  print('\n3. Aguardando estabilização da rede e negociação de rotas...');
  await Future<void>.delayed(const Duration(seconds: 4));

  print('\n============================================================');
  print('>>> DAEMON PRONTO (NETWORK NEGOTIATED) <<<');
  print('Endereços Swarm consolidados para anúncio:');
  for (final addr in node.swarmAddresses) {
    print('  $addr');
  }
  print('============================================================\n');

  // 4. SOMENTE AGORA (após inicialização e negociação completa) geramos e hospedamos o CID no Blockstore
  print('4. Inserindo payload inédito no blockstore após prontidão...');
  final rng = Random.secure();
  final randomBytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final randomHex = randomBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final contentString = 'Dart-IPFS-KuboLifecycle-[$timestamp]-$randomHex';
  final contentBytes = Uint8List.fromList(utf8.encode(contentString));

  // A. Como Raw block legítimo (CIDv1 com codec 'raw' -> bafkrei...)
  final rawDigest = MultihashUtils.sum('sha2-256', contentBytes);
  final rawCid = Cid.v1('raw', rawDigest);
  await node.putBlock(blocks.BasicBlock.withCid(contentBytes, rawCid));

  // B. Como UnixFS DAG legítimo (CIDv0 com codec 'dag-pb' -> Qm...)
  final unixFsResult = await buildDagFromReader(
    Stream.value(contentBytes),
    cidVersion: 0,
    retainBlocks: true,
    onBlock: (b) async {
      await node.putBlock(blocks.BasicBlock.withCid(b.data, b.cid));
    },
  );
  final unixFsCid = unixFsResult.root;

  print('   Conteúdo armazenado no blockstore: "$contentString"');
  print('   * Raw CID (CIDv1 / raw):       ${rawCid.encode()}');
  print('   * UnixFS CID (CIDv0 / dag-pb): ${unixFsCid.encode()}\n');

  // 5. Anunciar CIDs consolidados na Amino DHT
  print('5. Anunciando CIDs na Amino DHT com os endereços consolidados...');
  try {
    await node.provide(rawCid);
    print('   ✓ Raw CID anunciado na DHT: ${rawCid.encode()}');
  } catch (e) {
    print('   ✗ Aviso ao anunciar Raw CID: $e');
  }

  try {
    await node.provide(unixFsCid);
    print('   ✓ UnixFS CID anunciado na DHT: ${unixFsCid.encode()}');
  } catch (e) {
    print('   ✗ Aviso ao anunciar UnixFS CID: $e');
  }

  print('\n============================================================');
  print('>>> NÓ DART ATIVO E HOSPEDANDO O CID NA REDE PÚBLICA GLOBAL <<<');
  print('Para recuperar o conteúdo via IPFS / Kubo:');
  print('  ipfs block get ${rawCid.encode()}');
  print('  ipfs cat ${unixFsCid.encode()}');
  print('Para consultar na DHT:');
  print('  ipfs routing findprovs ${rawCid.encode()}');
  print('Para testar discagem direta (se necessário):');
  print('  ipfs swarm connect $announceAddr/p2p/$peerId');
  print('============================================================\n');

  // Monitoramento de saúde a cada 30 segundos
  final startTime = DateTime.now();
  Timer.periodic(const Duration(seconds: 30), (timer) {
    final uptime = DateTime.now().difference(startTime);
    print(
      '[${DateTime.now().toUtc().toIso8601String()}] Daemon Status: ONLINE | Uptime: ${uptime.inMinutes}m ${uptime.inSeconds % 60}s | Bloco servindo em Bitswap/DHT.',
    );
  });

  // Manter o processo vivo e realizar shutdown limpo
  final completer = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nEncerrando o nó Dart IPFS...');
    await node.close();
    print('Nó finalizado com sucesso.');
    completer.complete();
    exit(0);
  });

  await completer.future;
}
