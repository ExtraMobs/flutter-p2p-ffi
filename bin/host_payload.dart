// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/transpiled_boxo.dart' hide Blockstore;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

Future<void> setupUpnpPortMapping(int port) async {
  print('Configurando mapeamento de porta UPnP no gateway da rede...');
  try {
    final soapAddMapping = '<?xml version="1.0"?>\r\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n'
        '<s:Body>\r\n'
        '<u:AddPortMapping xmlns:u="urn:schemas-upnp-org:service:WANIPConnection:1">\r\n'
        '<NewRemoteHost></NewRemoteHost>\r\n'
        '<NewExternalPort>$port</NewExternalPort>\r\n'
        '<NewProtocol>TCP</NewProtocol>\r\n'
        '<NewInternalPort>$port</NewInternalPort>\r\n'
        '<NewInternalClient>192.168.1.4</NewInternalClient>\r\n'
        '<NewEnabled>1</NewEnabled>\r\n'
        '<NewPortMappingDescription>Dart-IPFS-Host</NewPortMappingDescription>\r\n'
        '<NewLeaseDuration>0</NewLeaseDuration>\r\n'
        '</u:AddPortMapping>\r\n'
        '</s:Body>\r\n'
        '</s:Envelope>';

    final bytes = utf8.encode(soapAddMapping);
    final client = HttpClient();
    final req = await client
        .postUrl(Uri.parse('http://192.168.1.1:52869/upnp/control/WANIPConn1'))
        .timeout(const Duration(seconds: 3));
    req.headers.set(
      'SOAPAction',
      '"urn:schemas-upnp-org:service:WANIPConnection:1#AddPortMapping"',
    );
    req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
    req.headers.set('Connection', 'Close');
    req.contentLength = bytes.length;
    req.add(bytes);
    final resp = await req.close();
    print('  UPnP Port Mapping status: ${resp.statusCode} ${resp.reasonPhrase}');
  } catch (e) {
    print('  Aviso ao configurar UPnP: $e');
  }
}

Future<void> main(List<String> args) async {
  print('============================================================');
  print('          DART IPFS - P2P SERVING NODE DAEMON              ');
  print('============================================================');

  // 1. UPnP Port Forwarding
  await setupUpnpPortMapping(4002);

  // 2. Payload: texto passado por argumento, ou uma sequencia aleatoria seguramente
  // unica quando nenhum argumento e fornecido.
  final String secretSequence;
  if (args.isNotEmpty) {
    secretSequence = args.join(' ');
  } else {
    final rng = Random.secure();
    final randomBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final randomHex =
        randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    secretSequence = 'Dart-IPFS-Proof-[$timestamp]-$randomHex';
  }

  print('\n>>> PAYLOAD HOSPEDADO:');
  print(secretSequence);
  print('------------------------------------------------------------');

  final textBytes = utf8.encode(secretSequence);

  // 3. Configure IPFS node on port 4002
  const config = IpfsConfig(
    offline: false,
    network: NetworkConfig(
      listenAddresses: ['/ip4/0.0.0.0/tcp/4002'],
      announceAddresses: ['/ip4/203.0.113.47/tcp/4002'],
      bootstrapPeers: [
        // Public IPFS bootstrapper (mars.i.ipfs.io)
        '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
        // Local Kubo node
        '/ip4/127.0.0.1/tcp/4001/p2p/12D3KooWBvCyh8Vezjcwjhe2etkvjxw7g8hx9SW4jP5c94yXkyX1',
      ],
    ),
  );

  print('\nIniciando nó Dart IPFS...');
  final node = await IpfsNode.fromBuildCfg(
    BuildCfg(config: config, online: true),
  );

  final peerId = node.peerId.toBase58();
  print('Nó Dart IPFS online!');
  print('PeerId: $peerId');

  // Multiaddresses
  final directWanAddr = '/ip4/203.0.113.47/tcp/4002/p2p/$peerId';
  final directLanAddr = '/ip4/192.168.1.4/tcp/4002/p2p/$peerId';
  final relayKuboAddr1 =
      '/ip4/203.0.113.47/tcp/10754/p2p/12D3KooWBvCyh8Vezjcwjhe2etkvjxw7g8hx9SW4jP5c94yXkyX1/p2p-circuit/p2p/$peerId';
  final relayKuboAddr2 =
      '/ip4/203.0.113.47/tcp/63525/p2p/12D3KooWBvCyh8Vezjcwjhe2etkvjxw7g8hx9SW4jP5c94yXkyX1/p2p-circuit/p2p/$peerId';
  final relayMarsAddr =
      '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ/p2p-circuit/p2p/$peerId';

  print('\nMultiaddresses disponíveis para acesso:');
  print('  [WAN Direto via UPnP]: $directWanAddr');
  print('  [LAN Direto]:          $directLanAddr');
  print('  [Circuit Relay v2 #1]: $relayKuboAddr1');
  print('  [Circuit Relay v2 #2]: $relayKuboAddr2');
  print('  [Circuit Relay Mars]:  $relayMarsAddr');

  // 4. Store as UnixFS DAG (CIDv0 - Qm...)
  final importResult = await buildDagFromReader(
    Stream.value(textBytes),
    cidVersion: 0,
    retainBlocks: true,
    onBlock: (block) async {
      await node.putBlock(blocks.BasicBlock.withCid(block.data, block.cid));
    },
  );
  final unixFsCid = importResult.root;

  // 5. Also store as Raw block (CIDv1 - bafk...)
  final rawCid = await node.putRawBlock(Uint8List.fromList(textBytes));

  print('\n------------------------------------------------------------');
  print('>>> IDENTIFICADORES DE CONTEUDO (CIDs):');
  print('  * UnixFS CID (Arquivo de texto para `ipfs cat`):');
  print('    ${unixFsCid.encode()}');
  print('  * Raw Block CID (Bloco puro para `ipfs block get`):');
  print('    ${rawCid.encode()}');
  print('------------------------------------------------------------');

  // 6. Connect to peers & establish bidirectional mesh
  print('\nConectando aos pares de rede e bootstrap...');
  for (final boot in config.network.bootstrapPeers) {
    try {
      await node.connect(addrInfoFromString(boot));
      print('  Conectado: $boot');
    } catch (e) {
      print('  Aviso ao conectar em $boot: $e');
    }
  }

  // Connect Kubo back to Dart node on loopback
  try {
    final res = await Process.run(
      'ipfs',
      ['swarm', 'connect', '/ip4/127.0.0.1/tcp/4002/p2p/$peerId'],
      environment: {'IPFS_PATH': r'B:\IPFS\.ipfs'},
    );
    print('  Kubo local conectado ao nó Dart: ${res.stdout.toString().trim()}');
  } catch (e) {
    print('  Aviso ao conectar Kubo no Dart: $e');
  }

  // 7. Announce CIDs to DHT
  Future<void> announceAll() async {
    print('\n[${DateTime.now().toUtc()}] Anunciando CIDs na DHT e Swarm...');
    try {
      await node.provide(unixFsCid);
      print('  UnixFS CID anunciado com sucesso: ${unixFsCid.encode()}');
    } catch (e) {
      print('  Falha ao anunciar UnixFS CID: $e');
    }

    try {
      await node.provide(rawCid);
      print('  Raw CID anunciado com sucesso: ${rawCid.encode()}');
    } catch (e) {
      print('  Falha ao anunciar Raw CID: $e');
    }

  }

  await announceAll();

  // Periodic republishing every 5 minutes
  final timer = Timer.periodic(
    const Duration(minutes: 5),
    (_) => announceAll(),
  );

  print('\n============================================================');
  print('>>> NÓ DART ATIVO E HOSPEDANDO O ARQUIVO EM TEMPO REAL <<<');
  print('============================================================');
  print('\nComandos para a máquina externa:');
  print('\n--- Opcao A: Conexao Direta WAN (via porta UPnP 4002) ---');
  print('ipfs swarm connect $directWanAddr');
  print('ipfs cat ${unixFsCid.encode()}');
  print('ipfs block get ${rawCid.encode()}');
  print('\n--- Opcao B: Conexao via Circuit Relay v2 (Garantido através do Kubo) ---');
  print('ipfs swarm connect $relayKuboAddr1');
  print('ipfs cat ${unixFsCid.encode()}');
  print('ipfs block get ${rawCid.encode()}');
  print('\n--- Opcao C: Conexao via Circuit Relay Mars (IPFS Public Relay) ---');
  print('ipfs swarm connect $relayMarsAddr');
  print('ipfs cat ${unixFsCid.encode()}');
  print('ipfs block get ${rawCid.encode()}');
  print('\n(Aguardando conexoes e requisicoes de blocos Bitswap...)');

  // Keep daemon alive indefinitely
  final completer = Completer<void>();
  try {
    ProcessSignal.sigint.watch().listen((_) async {
      print('\nEncerrando daemon...');
      timer.cancel();
      await node.close();
      print('Nó Dart IPFS finalizado.');
      completer.complete();
      exit(0);
    });
  } catch (_) {}

  await completer.future;
}
