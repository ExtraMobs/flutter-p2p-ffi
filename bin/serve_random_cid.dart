// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/transpiled_boxo.dart' hide Blockstore;
import 'package:transpiled_go_codec_dagpb/transpiled_go_codec_dagpb.dart'
    hide decode, encode;
import 'package:transpiled_go_dag_jose/transpiled_go_dag_jose.dart'
    as go_dag_jose;
import 'package:transpiled_go_ipld_git/transpiled_go_ipld_git.dart'
    as go_ipld_git;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

Future<void> main(List<String> args) async {
  print('============================================================');
  print('   DART IPFS - DAEMON DE HOSPEDAGEM MULTICODEC (ESTILO KUBO)');
  print('============================================================');

  // Registrar todos os codecs IPLD no defaultRegistry
  registerDagPbCodec();
  go_ipld_git.registerGitCodec();
  go_dag_jose.registerDagJoseCodec();

  // 1. Configurar o nó Dart IPFS
  var tcpPort = 4002;
  try {
    final testSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      tcpPort,
    );
    await testSocket.close();
  } catch (_) {
    try {
      tcpPort = 4003;
      final testSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        tcpPort,
      );
      await testSocket.close();
      print('Porta 4002 em TimeWait, usando porta 4003.');
    } catch (_) {
      print('Porta 4003 em uso, alocando porta dinamica.');
      tcpPort = 0;
    }
  }

  final announceAddr = Platform.environment['DART_IPFS_ANNOUNCE_ADDR'];

  final config = IpfsConfig(
    offline: false,
    network: NetworkConfig(
      listenAddresses: ['/ip4/0.0.0.0/tcp/$tcpPort'],
      announceAddresses: announceAddr != null ? [announceAddr] : const [],
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

  print('1. Inicializando subsistemas do nó Dart IPFS (Swarm, TLS/Noise, DHT, Bitswap)...');
  final node = await IpfsNode.fromBuildCfg(
    BuildCfg(config: config, online: true),
  );

  final peerId = node.peerId.toBase58();
  print('   Nó ativo localmente! PeerId: $peerId\n');

  // 2. Conectar aos bootstrappers para estabilizar presença na DHT
  print('2. Conectando aos peers de bootstrap e negociando presença na rede...');
  for (final boot in config.network.bootstrapPeers) {
    try {
      await node.connect(addrInfoFromString(boot));
      print('   ✓ Conectado ao bootstrapper: $boot');
    } catch (e) {
      print('   ✗ Falha ao conectar em $boot: $e');
    }
  }

  print('\n3. Aguardando estabilização da rede e negociação de rotas...');
  await Future<void>.delayed(const Duration(seconds: 4));

  print('\n============================================================');
  print('>>> DAEMON PRONTO (NETWORK NEGOTIATED) <<<');
  print('Endereços Swarm consolidados para anúncio:');
  for (final addr in node.swarmAddresses) {
    print('  $addr');
  }
  print('============================================================\n');

  // 4. Gerar e armazenar blocos para todos os 8 formatos no blockstore
  print('4. Gerando e armazenando blocos em todos os 8 formatos IPLD...');
  final rng = Random.secure();
  final randomBytes = List<int>.generate(16, (_) => rng.nextInt(256));
  final randomHex = randomBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final sampleText = 'Dart IPFS Multicodec Suite [$timestamp] #$randomHex';

  final hostedCids = <String, (Cid, String)>{};

  // 1. Raw (0x55)
  final rawPayload = Uint8List.fromList(utf8.encode('$sampleText - raw data payload'));
  final rawCid = Cid.computeForDataSync(rawPayload, codec: 'raw');
  await node.putBlock(blocks.BasicBlock.withCid(rawPayload, rawCid));
  hostedCids['raw (0x55)'] = (rawCid, 'Payload bruto em bytes');

  // 2. DAG-PB (0x70) - UnixFS legítimo
  final unixFsResult = await buildDagFromReader(
    Stream.value(rawPayload),
    cidVersion: 1,
    retainBlocks: true,
    onBlock: (b) async {
      await node.putBlock(blocks.BasicBlock.withCid(b.data, b.cid));
    },
  );
  final pbCid = unixFsResult.root;
  hostedCids['dag-pb (0x70)'] = (pbCid, 'Arquivo UnixFS com links Merkle DAG');

  // Nó com links IPLD (para dag-cbor e dag-json)
  final linkMapBuilder = prototype.map.newBuilder();
  final linkMa = linkMapBuilder.beginMap(4);
  linkMa.assembleKey().assignString('service');
  linkMa.assembleValue().assignString('dart_ipfs');
  linkMa.assembleKey().assignString('message');
  linkMa.assembleValue().assignString(sampleText);
  linkMa.assembleKey().assignString('timestamp');
  linkMa.assembleValue().assignString(timestamp);
  linkMa.assembleKey().assignString('rawLink');
  linkMa.assembleValue().assignLink(CidLink(rawCid));
  linkMa.finish();
  final linkMapNode = linkMapBuilder.build();

  // Nó puro sem links (para cbor e json)
  final plainMapBuilder = prototype.map.newBuilder();
  final plainMa = plainMapBuilder.beginMap(3);
  plainMa.assembleKey().assignString('service');
  plainMa.assembleValue().assignString('dart_ipfs');
  plainMa.assembleKey().assignString('message');
  plainMa.assembleValue().assignString(sampleText);
  plainMa.assembleKey().assignString('timestamp');
  plainMa.assembleValue().assignString(timestamp);
  plainMa.finish();
  final plainMapNode = plainMapBuilder.build();

  // 3. DAG-CBOR (0x71)
  final dagCborBytes = _encodeWithRegistry(0x71, linkMapNode);
  final dagCborCid = Cid.computeForDataSync(dagCborBytes, codec: 'dag-cbor');
  await node.putBlock(blocks.BasicBlock.withCid(dagCborBytes, dagCborCid));
  hostedCids['dag-cbor (0x71)'] = (dagCborCid, 'CBOR canônico com IPLD Links');

  // 4. CBOR (0x51)
  final cborBytes = _encodeWithRegistry(0x51, plainMapNode);
  final cborCid = Cid.computeForDataSync(cborBytes, codec: 'cbor');
  await node.putBlock(blocks.BasicBlock.withCid(cborBytes, cborCid));
  hostedCids['cbor (0x51)'] = (cborCid, 'CBOR estrito sem Tag 42');

  // 5. DAG-JSON (0x0129)
  final dagJsonBytes = _encodeWithRegistry(0x0129, linkMapNode);
  final dagJsonCid = Cid.computeForDataSync(dagJsonBytes, codec: 'dag-json');
  await node.putBlock(blocks.BasicBlock.withCid(dagJsonBytes, dagJsonCid));
  hostedCids['dag-json (0x0129)'] = (dagJsonCid, 'JSON com suporte a IPLD Links');

  // 6. JSON (0x0200)
  final jsonBytes = _encodeWithRegistry(0x0200, plainMapNode);
  final jsonCid = Cid.computeForDataSync(jsonBytes, codec: 'json');
  await node.putBlock(blocks.BasicBlock.withCid(jsonBytes, jsonCid));
  hostedCids['json (0x0200)'] = (jsonCid, 'JSON canônico puro');

  // 7. Git-Raw (0x78)
  final gitContent = utf8.encode('blob git test payload for Dart IPFS at $timestamp');
  final gitBlob = Uint8List.fromList([
    ...utf8.encode('blob ${gitContent.length}\x00'),
    ...gitContent,
  ]);
  final gitSha = Uint8List.fromList(crypto.sha1.convert(gitBlob).bytes);
  final gitCid = go_ipld_git.shaToCid(gitSha);
  await node.putBlock(blocks.BasicBlock.withCid(gitBlob, gitCid));
  hostedCids['git-raw (0x78)'] = (gitCid, 'Git Blob com hash SHA-1 de 20 bytes');

  // 8. DAG-JOSE (0x85)
  final josePayload = rawCid.bytes();
  final jwsMap = prototype.map.newBuilder();
  final jwsMa = jwsMap.beginMap(2);
  jwsMa.assembleKey().assignString('payload');
  jwsMa.assembleValue().assignBytes(josePayload);
  jwsMa.assembleKey().assignString('signatures');
  final la = jwsMa.assembleValue().beginList(1);
  final sigMa = la.assembleValue().beginMap(1);
  sigMa.assembleKey().assignString('signature');
  sigMa.assembleValue().assignBytes(Uint8List.fromList([42, 42, 42, 42]));
  sigMa.finish();
  la.finish();
  jwsMa.finish();
  final jwsNode = jwsMap.build();

  final joseBytes = _encodeWithRegistry(0x85, jwsNode);
  final joseCid = Cid.computeForDataSync(joseBytes, codec: 'dag-jose');
  await node.putBlock(blocks.BasicBlock.withCid(joseBytes, joseCid));
  hostedCids['dag-jose (0x85)'] = (joseCid, 'Envelope criptográfico JWS com link assinado');

  print('   ✓ Todos os 8 blocos foram gerados e armazenados com sucesso no blockstore!\n');

  print('============================================================');
  print('>>> NÓ DART ATIVO E HOSPEDANDO TODOS OS 8 CIDs NO SWARM <<<');
  print('Endereços do nó Dart para swarm connect:');
  for (final addr in node.swarmAddresses) {
    print('  ipfs swarm connect $addr');
  }
  print('');
  print('COMANDOS KUBO PARA TESTAR CADA FORMATO:');
  for (final entry in hostedCids.entries) {
    final formatName = entry.key;
    final cid = entry.value.$1;
    final desc = entry.value.$2;
    print('\n* [$formatName] - $desc:');
    print('  CID: ${cid.encode()}');
    print('  ipfs block get ${cid.encode()}');
    if (formatName.startsWith('dag-')) {
      print('  ipfs dag get ${cid.encode()}');
    }
    if (formatName.startsWith('dag-pb')) {
      print('  ipfs cat ${cid.encode()}');
    }
    print('  ipfs routing findprovs ${cid.encode()}');
  }
  print('============================================================\n');

  // 5. Anunciar cada CID na Amino DHT pública em background
  print('5. Anunciando CIDs na Amino DHT em background...');
  unawaited(() async {
    for (final entry in hostedCids.entries) {
      final formatName = entry.key;
      final cid = entry.value.$1;
      try {
        await node.provide(cid);
        print('   ✓ $formatName anunciado na DHT: ${cid.encode()}');
      } catch (e) {
        print('   ✗ Aviso ao anunciar $formatName: $e');
      }
    }
    print('\n[DHT] Todos os 8 CIDs foram anunciados na rede DHT pública!');
  }());

  // Monitoramento periódico
  final startTime = DateTime.now();
  Timer.periodic(const Duration(seconds: 30), (timer) {
    final uptime = DateTime.now().difference(startTime);
    print(
      '[${DateTime.now().toUtc().toIso8601String()}] Daemon Status: ONLINE | Uptime: ${uptime.inMinutes}m ${uptime.inSeconds % 60}s | 8 formatos IPLD ativos no Bitswap/DHT.',
    );
  });

  // Manter o processo ativo e realizar encerramento limpo
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

Uint8List _encodeWithRegistry(int codecIndicator, Node node) {
  final encoder = defaultRegistry.lookupEncoder(codecIndicator);
  final sink = <List<int>>[];
  encoder(node, _StreamControllerSink(sink.add));
  return Uint8List.fromList(sink.expand((e) => e).toList());
}

class _StreamControllerSink<T> implements Sink<T> {
  _StreamControllerSink(this._onAdd);
  final void Function(T) _onAdd;
  @override
  void add(T data) => _onAdd(data);
  @override
  void close() {}
}
