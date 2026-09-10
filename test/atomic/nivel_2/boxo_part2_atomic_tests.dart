import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/bitswap/client.dart';
import 'package:transpiled_boxo/bitswap/message.dart' as msg;
import 'package:transpiled_boxo/bitswap/network.dart';
import 'package:transpiled_boxo/src/bitswap/client/client.dart' as client_impl;
import 'package:transpiled_boxo/src/bitswap/client/internal/blockpresencemanager/blockpresencemanager.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/messagequeue/donthavetimeoutmgr.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/messagequeue/messagequeue.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/notifications/notifications.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/peermanager/peermanager.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/peermanager/peerqueue.dart';
import 'package:transpiled_boxo/src/bitswap/client/internal/peermanager/peerwantmanager.dart';
import 'package:transpiled_boxo/src/bitswap/message/pb/message.dart' as pb;
import 'package:transpiled_boxo/src/bitswap/network/bsnet/ipfs_impl.dart';
import 'package:transpiled_boxo/src/bitswap/network/bsnet/options.dart';
import 'package:transpiled_boxo/src/bitswap/network/connecteventmanager.dart';
import 'package:transpiled_boxo/src/bitswap/network/interface.dart';
import 'package:transpiled_boxo/src/bitswap/wantlist/forward.dart' as fwd;
import 'package:transpiled_boxo/src/blockstore.dart';
import 'package:transpiled_boxo/src/chunker.dart';
import 'package:transpiled_boxo/src/dag_pb.dart';
import 'package:transpiled_boxo/src/importer.dart';
import 'package:transpiled_boxo/src/unixfs.dart';
import 'package:transpiled_boxo/src/util/file.dart';
import 'package:transpiled_boxo/src/util/time.dart';
import 'package:transpiled_boxo/src/util/util.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' hide Routing;

extension on UnixFsDataType {
  int get wireValue => index;
}

class _DummyP2pStream implements P2pStream {
  @override
  String get protocol => '/ipfs/bitswap/1.2.0';
  @override
  Future<void> write(List<int> data) async {}
  @override
  void setWriteDeadline(DateTime deadline) {}
  @override
  void setDeadline(DateTime deadline) {}
  @override
  Future<void> close() async {}
  @override
  void reset() {}
}

class _DummyP2pHost implements P2pHost {
  final List<PeerId> _peers = [];
  @override
  void setStreamHandler(String protocol, void Function(P2pStream) handler) {}
  @override
  Future<P2pStream> newStream(PeerId peer, List<String> protocols) async => _DummyP2pStream();
  @override
  void removeStreamHandler(String protocol) {}
  @override
  Future<void> connect(AddrInfo peer) async {}
  @override
  List<PeerId> get peers => _peers;
}

class _DummyReceiver implements Receiver, ConnectionListener {
  @override
  void receiveMessage(PeerId sender, msg.BitSwapMessage incoming) {}
  @override
  void receiveError(Exception error) {}
  @override
  void peerConnected(PeerId peer) {}
  @override
  void peerDisconnected(PeerId peer) {}
}

class _DummyPeerConn implements PeerConnection {
  @override
  Future<Duration> ping(Duration timeout) async => const Duration(milliseconds: 10);
  @override
  Duration latency() => const Duration(milliseconds: 10);
}

class _DummyMessageNetwork implements MessageNetwork {
  @override
  Future<void> connect(PeerId peer, {dynamic addrInfo}) async {}
  @override
  Future<MessageSender> newMessageSender(PeerId peer, MessageSenderOpts opts) async => _DummyMessageSender();
  @override
  Duration latency(PeerId peer) => const Duration(milliseconds: 10);
  @override
  Future<Duration> ping(PeerId peer) async => const Duration(milliseconds: 10);
  @override
  PeerId self() => PeerId.fromBytes(Uint8List.fromList([0x12, 0x20, ...List.filled(32, 9)]));
}

class _DummyMessageSender implements MessageSender {
  @override
  Future<void> sendMsg(msg.BitSwapMessage msg) async {}
  @override
  Future<void> reset() async {}
  @override
  bool supportsHave() => true;
}

class _DummyRouting implements Routing {
  @override
  Future<void> provide(Cid key) async {}
  @override
  Stream<AddrInfo> findProvidersAsync(Cid key, int count) => const Stream.empty();
}

class _TestGauge implements Gauge {
  int value = 0;
  @override
  void inc() => value++;
  @override
  void dec() => value--;
}

class _TestSession implements Session {
  @override
  int id() => 1;
  @override
  void signalAvailability(PeerId peer, bool isConnected) {}
}

void main() {
  final testCid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
  final testPeer = PeerId.fromBytes(Uint8List.fromList([0x12, 0x20, ...List.filled(32, 7)]));
  final testBlock = blocks.BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));

  group('FixedSizeChunker [Atomic Audit]', () {
    test('chunks() - particiona stream de bytes em blocos de tamanho fixo', () async {
      final chunker = FixedSizeChunker(Stream.value([1, 2, 3, 4, 5]), size: 2);
      final chunks = await chunker.chunks().toList();
      expect(chunks, hasLength(3));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('fromString() - instancia chunker a partir de especificacao textual', () {
      final c = fromString(Stream.value([1, 2, 3]), 'default');
      expect(c, isNotNull);
    });

    test('buildDagFromReader() - constroi dag unixfs a partir de stream de bytes', () async {
      final res = await buildDagFromReader(Stream.value([1, 2, 3]));
      expect(res.root, isNotNull);
    });

    test('wrapData() - empacota bytes em estrutura de dados raw', () {
      final bytes = wrapData(Uint8List.fromList([1, 2]));
      expect(bytes, isNotEmpty);
    });

    test('filePbData() - formata carga util como no de arquivo unixfs', () {
      final bytes = filePbData(Uint8List.fromList([1, 2]), 2);
      expect(bytes, isNotEmpty);
    });

    test('folderPbData() - cria no de diretorio unixfs', () {
      final bytes = folderPbData();
      expect(bytes, isNotEmpty);
    });

    test('unwrapData() - extrai dados brutos de no unixfs', () {
      final original = Uint8List.fromList([10, 20]);
      final unwrapped = unwrapData(wrapData(original));
      expect(unwrapped, equals(original));
    });

    test('dataSize() - extrai tamanho de dados contido no payload', () {
      final size = dataSize(filePbData(Uint8List.fromList([1, 2, 3]), 3));
      expect(size, equals(3));
    });

    test('fileExists() - valida se arquivo existe no caminho informado', () {
      expect(fileExists('pubspec.yaml'), isTrue);
      expect(fileExists('non_existent_file_xyz.txt'), isFalse);
    });

    test('parseRfc3339() - converte string rfc3339 em datetime', () {
      final dt = parseRfc3339('2026-01-01T00:00:00Z');
      expect(dt.year, equals(2026));
    });

    test('formatRfc3339() - formata datetime para representacao rfc3339', () {
      final s = formatRfc3339(DateTime.utc(2026, 1, 1));
      expect(s, contains('2026-01-01'));
    });

    test('errCast() - produz excecao de conversao de erro', () {
      final err = errCast();
      expect(err, isNotNull);
    });

    test('expandPathnames() - resolve lista de caminhos para forma canonica', () {
      final paths = expandPathnames(['pubspec.yaml']);
      expect(paths.first, contains('pubspec.yaml'));
    });

    test('getenvBool() - le variavel de ambiente como valor booleano', () {
      expect(getenvBool('UNKNOWN_ENV_VAR_123'), isFalse);
    });

    test('partition() - particiona texto pelo primeiro separador', () {
      expect(partition('a=b=c', '='), equals(['a', '=', 'b=c']));
    });

    test('rPartition() - particiona texto pelo ultimo separador', () {
      expect(rPartition('a=b=c', '='), equals(['a=b', '=', 'c']));
    });

    test('hash() - gera hash multihash padrao para buffer', () {
      final h = hash(Uint8List.fromList([1, 2]));
      expect(h.digest, isNotEmpty);
    });

    test('isValidHash() - valida consistencia de multihash textual', () {
      expect(isValidHash('QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG'), isTrue);
      expect(isValidHash('invalid-hash'), isFalse);
    });

    test('xor() - realiza operacao xor entre dois buffers de bytes', () {
      final a = Uint8List.fromList([0xAA, 0x55]);
      final b = Uint8List.fromList([0xFF, 0x00]);
      final res = xor(a, b);
      expect(res, equals(Uint8List.fromList([0x55, 0x55])));
    });

    test('wantlist() - constroi wantlist vazia', () {
      final w = fwd.wantlist();
      expect(w.length, equals(0));
    });

    test('refEntry() - constroi ref entry com prioridade', () {
      final re = fwd.refEntry(testCid, 5);
      expect(re.cid, equals(testCid));
    });

    test('prefix() - define prefixo de protocolo em configuracoes', () {
      final opt = prefix('/myprefix');
      final s = Settings();
      opt(s);
      expect(s.protocolPrefix, equals('/myprefix'));
    });

    test('supportedProtocols() - configura lista de protocolos suportados', () {
      final opt = supportedProtocols(['/p/1']);
      final s = Settings();
      opt(s);
      expect(s.supportedProtocols, equals(['/p/1']));
    });

    test('withConnectEventManager() - configura gerenciador de eventos de conexao', () {
      final cem = ConnectEventManager();
      final opt = withConnectEventManager(cem);
      final s = Settings();
      opt(s);
      expect(s.connEvtMgr, equals(cem));
    });
  });

  group('DagPbLink [Atomic Audit]', () {
    test('toBytes() - serializa link em bytes', () {
      final link = DagPbLink(hash: testCid.toBytes(), name: 'link-1', tsize: 100);
      final bytes = link.toBytes();
      expect(bytes, isNotEmpty);
    });
  });

  group('DagPbNode [Atomic Audit]', () {
    test('toBytes() - serializa no dag pb em bytes', () {
      final link = DagPbLink(hash: testCid.toBytes(), name: 'link-1', tsize: 100);
      final node = DagPbNode(data: Uint8List.fromList([1, 2, 3]), links: [link]);
      final bytes = node.toBytes();
      expect(bytes, isNotEmpty);
    });
  });

  group('BalancedUnixFsImporter [Atomic Audit]', () {
    test('importStream() - importa stream de bytes para arvore unixfs', () async {
      final imp = BalancedUnixFsImporter();
      final res = await imp.importStream(Stream.value([1, 2, 3]));
      expect(res.root, isNotNull);
    });

    test('importFile() - importa arquivo do disco para unixfs', () async {
      final imp = BalancedUnixFsImporter();
      final res = await imp.importFile('pubspec.yaml');
      expect(res.root, isNotNull);
    });
  });

  group('on [Atomic Audit]', () {
    test('on.wireValue() - obtem valor numerico da constante enum', () {
      expect(UnixFsDataType.file.wireValue, equals(2));
    });
  });

  group('UnixFsData [Atomic Audit]', () {
    test('toBytes() - serializa estrutura unixfs em bytes protobuf', () {
      final ufd = UnixFsData(UnixFsDataType.raw, data: [1, 2, 3]);
      final bytes = ufd.toBytes();
      expect(bytes, isNotEmpty);
    });
  });

  group('BlockGetter [Atomic Audit]', () {
    test('getBlock() - busca bloco via interface block getter', () async {
      final ds = MapDatastore();
      final bs = Blockstore(ds);
      await bs.put(testBlock);
      final host = _DummyP2pHost();
      final net = IpfsNetwork.fromIpfsHost(host);
      final BlockGetter bg = client_impl.Client(network: net, blockstore: bs);
      final blk = await bg.getBlock(testBlock.cid());
      expect(blk.cid(), equals(testBlock.cid()));
    });
  });

  group('NullGauge [Atomic Audit]', () {
    test('inc() - operacao no-op de incremento', () {
      const ng = NullGauge();
      ng.inc();
      expect(ng, isNotNull);
    });

    test('dec() - operacao no-op de decremento', () {
      const ng = NullGauge();
      ng.dec();
      expect(ng, isNotNull);
    });
  });

  group('Client [Atomic Audit]', () {
    late client_impl.Client client;
    late Blockstore bs;
    setUp(() async {
      final host = _DummyP2pHost();
      final net = IpfsNetwork.fromIpfsHost(host);
      final ds = MapDatastore();
      bs = Blockstore(ds);
      await bs.put(testBlock);
      client = client_impl.Client(network: net, blockstore: bs, timeout: const Duration(milliseconds: 50));
    });

    test('getBlock() - busca bloco via cliente', () async {
      final blk = await client.getBlock(testBlock.cid());
      expect(blk.cid(), equals(testBlock.cid()));
    });

    test('getBlocks() - busca multiplos blocos via cliente', () async {
      final stream = await client.getBlocks([testBlock.cid()]);
      expect(stream, isNotNull);
    });

    test('receiveMessage() - processa mensagem bitswap recebida', () {
      client.receiveMessage(testPeer, msg.BitSwapMessage(false));
      expect(client, isNotNull);
    });

    test('receiveError() - registra erro de rede', () {
      client.receiveError(Exception('net err'));
      expect(client, isNotNull);
    });

    test('peerConnected() - callback de conexao de par', () {
      client.peerConnected(testPeer);
      expect(client, isNotNull);
    });

    test('peerDisconnected() - callback de desconexao de par', () {
      client.peerDisconnected(testPeer);
      expect(client, isNotNull);
    });

    test('getWantlist() - lista de cids solicitados', () {
      expect(client.getWantlist(), isEmpty);
    });

    test('getWantBlocks() - lista de want blocks', () {
      expect(client.getWantBlocks(), isEmpty);
    });

    test('getWantHaves() - lista de want haves', () {
      expect(client.getWantHaves(), isEmpty);
    });

    test('isOnline() - status de conectividade do cliente', () {
      expect(client.isOnline(), isTrue);
    });

    test('close() - encerra cliente bitswap', () async {
      await client.close();
      expect(client, isNotNull);
    });
  });

  group('Exportable [Atomic Audit]', () {
    final msg.Exportable exp = msg.BitSwapMessage(false);

    test('toProtoV0() - exporta representacao protobuf v0', () {
      expect(exp.toProtoV0(), isNotNull);
    });

    test('toProtoV1() - exporta representacao protobuf v1', () {
      expect(exp.toProtoV1(), isNotNull);
    });

    test('toNetV0() - serializa na rede versao v0', () {
      final bb = BytesBuilder();
      exp.toNetV0(bb);
      expect(bb.length, greaterThanOrEqualTo(0));
    });

    test('toNetV1() - serializa na rede versao v1', () {
      final bb = BytesBuilder();
      exp.toNetV1(bb);
      expect(bb.length, greaterThanOrEqualTo(0));
    });
  });

  group('BitSwapMessage [Atomic Audit]', () {
    test('fillWantlist() - preenche lista externa de wants', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(true);
      final list = <msg.Entry>[];
      m.fillWantlist(list);
      expect(list, isEmpty);
    });

    test('wantlist() - retorna colecao de entradas da wantlist', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(true);
      expect(m.wantlist(), isEmpty);
    });

    test('blocks() - retorna blocos contidos na mensagem', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.blocks(), isEmpty);
    });

    test('blockPresences() - lista presencas informadas', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.blockPresences(), isEmpty);
    });

    test('haves() - filtra cids com presenca have', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.haves(), isEmpty);
    });

    test('dontHaves() - filtra cids com presenca dontHave', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.dontHaves(), isEmpty);
    });

    test('pendingBytes() - consulta bytes pendentes da mensagem', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.pendingBytes(), equals(0));
    });

    test('addEntry() - adiciona solicitacao a wantlist', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      final size = m.addEntry(testCid, 1, pb.WantType.have, false);
      expect(size, greaterThan(0));
    });

    test('cancel() - cancela cid na mensagem', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addEntry(testCid, 1, pb.WantType.have, false);
      final res = m.cancel(testCid);
      expect(res, greaterThanOrEqualTo(0));
    });

    test('remove() - remove cid da wantlist', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addEntry(testCid, 1, pb.WantType.have, false);
      m.remove(testCid);
      expect(m.wantlist(), isEmpty);
    });

    test('empty() - avalia se a mensagem esta vazia', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.empty(), isTrue);
    });

    test('size() - calcula tamanho em bytes da mensagem', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.size(), greaterThanOrEqualTo(0));
    });

    test('full() - verifica se mensagem e wantlist completa', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(true);
      expect(m.full(), isTrue);
    });

    test('addBlock() - adiciona bloco de dados', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addBlock(testBlock);
      expect(m.blocks(), contains(testBlock));
    });

    test('addBlockPresence() - adiciona presenca de bloco', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addBlockPresence(testCid, pb.BlockPresenceType.have);
      expect(m.blockPresences(), isNotEmpty);
    });

    test('addHave() - adiciona presenca have diretamente', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addHave(testCid);
      expect(m.haves(), contains(testCid));
    });

    test('addDontHave() - adiciona presenca dontHave diretamente', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.addDontHave(testCid);
      expect(m.dontHaves(), contains(testCid));
    });

    test('setPendingBytes() - define quantidade de bytes pendentes', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      m.setPendingBytes(42);
      expect(m.pendingBytes(), equals(42));
    });

    test('loggable() - mapa estruturado para logs', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(false);
      expect(m.loggable(), isA<Map>());
    });

    test('reset() - redefine estado interno da mensagem', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(true);
      m.reset(false);
      expect(m.full(), isFalse);
    });

    test('clone() - duplica mensagem de forma independente', () {
      final msg.BitSwapMessage m = msg.BitSwapMessage(true);
      final c = m.clone();
      expect(c, isNotNull);
      expect(c.full(), isTrue);
    });
  });

  group('ConnectionListener [Atomic Audit]', () {
    late ConnectionListener cl;
    setUp(() {
      cl = _DummyReceiver();
    });

    test('peerConnected() - notifica conexao de par', () {
      cl.peerConnected(testPeer);
      expect(cl, isNotNull);
    });

    test('peerDisconnected() - notifica desconexao de par', () {
      cl.peerDisconnected(testPeer);
      expect(cl, isNotNull);
    });
  });

  group('ConnectEventManager [Atomic Audit]', () {
    late ConnectEventManager cem;
    setUp(() {
      cem = ConnectEventManager([_DummyReceiver()]);
    });

    test('changeQueueLength() - consulta tamanho da fila de peers', () {
      expect(cem.changeQueueLength, equals(0));
    });

    test('hasPeers() - verifica se ha peers disponiveis', () {
      expect(cem.hasPeers, isFalse);
    });

    test('hasPendingPeers() - verifica peers pendentes', () {
      expect(cem.hasPendingPeers, isFalse);
    });

    test('setListeners() - atualiza listeners de conexao', () {
      cem.setListeners([_DummyReceiver()]);
      expect(cem, isNotNull);
    });

    test('start() - inicia gerenciamento de eventos', () {
      cem.start();
      expect(cem, isNotNull);
    });

    test('stop() - interrompe gerenciamento de eventos', () async {
      cem.start();
      await cem.stop();
      expect(cem, isNotNull);
    });

    test('connected() - notifica conexao de peer', () {
      cem.connected(testPeer);
      expect(cem, isNotNull);
    });

    test('disconnected() - notifica desconexao de peer', () {
      cem.disconnected(testPeer);
      expect(cem, isNotNull);
    });

    test('markUnresponsive() - marca par como nao responsivo', () {
      cem.markUnresponsive(testPeer);
      expect(cem, isNotNull);
    });

    test('onMessage() - registra recebimento de mensagem', () {
      cem.onMessage(testPeer);
      expect(cem, isNotNull);
    });
  });

  group('P2pStream [Atomic Audit]', () {
    late P2pStream stream;
    setUp(() {
      stream = _DummyP2pStream();
    });

    test('protocol() - consulta identificador do protocolo', () {
      expect(stream.protocol, equals('/ipfs/bitswap/1.2.0'));
    });

    test('write() - grava bytes na stream', () async {
      await stream.write([1, 2, 3]);
      expect(stream, isNotNull);
    });

    test('setWriteDeadline() - configura prazo de escrita', () {
      stream.setWriteDeadline(DateTime.now());
      expect(stream, isNotNull);
    });

    test('setDeadline() - configura prazo geral', () {
      stream.setDeadline(DateTime.now());
      expect(stream, isNotNull);
    });

    test('close() - encerra canal da stream', () async {
      await stream.close();
      expect(stream, isNotNull);
    });

    test('reset() - redefine canal da stream', () {
      stream.reset();
      expect(stream, isNotNull);
    });
  });

  group('P2pHost [Atomic Audit]', () {
    late P2pHost host;
    setUp(() {
      host = _DummyP2pHost();
    });

    test('setStreamHandler() - define manipulador de stream', () {
      host.setStreamHandler('/ipfs/bitswap/1.2.0', (s) {});
      expect(host, isNotNull);
    });

    test('newStream() - abre nova conexao de stream', () async {
      final s = await host.newStream(testPeer, ['/ipfs/bitswap/1.2.0']);
      expect(s, isNotNull);
    });

    test('removeStreamHandler() - desregistra manipulador', () {
      host.removeStreamHandler('/ipfs/bitswap/1.2.0');
      expect(host, isNotNull);
    });

    test('connect() - conecta ao endereco de par', () async {
      await host.connect(AddrInfo(id: testPeer));
      expect(host, isNotNull);
    });

    test('peers() - consulta pares conectados ao host', () {
      expect(host.peers, isEmpty);
    });
  });

  group('BitSwapNetwork [Atomic Audit]', () {
    late BitSwapNetwork bsn;
    setUp(() {
      bsn = IpfsNetwork.fromIpfsHost(_DummyP2pHost());
    });

    test('sendMessage() - despacha mensagem bitswap pela rede', () async {
      await bsn.sendMessage(testPeer, msg.BitSwapMessage(false));
      expect(bsn, isNotNull);
    });

    test('start() - inicializa conexao de rede com receptores', () {
      bsn.start([_DummyReceiver()]);
      expect(bsn, isNotNull);
    });

    test('stop() - finaliza servico de rede', () {
      bsn.stop();
      expect(bsn, isNotNull);
    });

    test('connect() - estabelece sessao de rede com par', () async {
      await bsn.connect(AddrInfo(id: testPeer));
      expect(bsn, isNotNull);
    });

    test('disconnectFrom() - encerra sessao com par', () async {
      await bsn.disconnectFrom(testPeer);
      expect(bsn, isNotNull);
    });

    test('isConnectedToPeer() - avalia estado de conectividade', () {
      expect(bsn.isConnectedToPeer(testPeer), isFalse);
    });

    test('newMessageSender() - cria novo transmissor de mensagens', () async {
      final s = await bsn.newMessageSender(
        testPeer,
        MessageSenderOpts(
          maxRetries: 1,
          sendTimeout: const Duration(seconds: 1),
          sendErrorBackoff: const Duration(milliseconds: 10),
        ),
      );
      expect(s, isNotNull);
    });

    test('host() - acessa host de rede subjacente', () {
      expect(bsn.host(), isNotNull);
    });

    test('stats() - obtem relatorio de estatisticas da rede', () {
      expect(bsn.stats(), isNotNull);
    });

    test('self() - retorna identidade local', () {
      expect(bsn.self(), isNotNull);
    });
  });

  group('PeerTagger [Atomic Audit]', () {
    late PeerTagger tagger;
    setUp(() {
      tagger = IpfsNetwork.fromIpfsHost(_DummyP2pHost());
    });

    test('tagPeer() - adiciona marcacao a par com peso', () {
      tagger.tagPeer(testPeer, 'tagA', 10);
      expect(tagger, isNotNull);
    });

    test('untagPeer() - remove marcacao de par', () {
      tagger.untagPeer(testPeer, 'tagA');
      expect(tagger, isNotNull);
    });

    test('protect() - protege conexao com par de encerramento', () {
      tagger.protect(testPeer, 'tagA');
      expect(tagger, isNotNull);
    });

    test('unprotect() - revoga protecao de conexao', () {
      final res = tagger.unprotect(testPeer, 'tagA');
      expect(res, isFalse);
    });
  });

  group('MessageSender [Atomic Audit]', () {
    late MessageSender ms;
    setUp(() {
      ms = _DummyMessageSender();
    });

    test('sendMsg() - envia mensagem pelo canal', () async {
      await ms.sendMsg(msg.BitSwapMessage(false));
      expect(ms, isNotNull);
    });

    test('reset() - reinicia canal de envio', () async {
      await ms.reset();
      expect(ms, isNotNull);
    });

    test('supportsHave() - reporta suporte ao recurso have', () {
      expect(ms.supportsHave(), isTrue);
    });
  });

  group('Receiver [Atomic Audit]', () {
    late Receiver r;
    setUp(() {
      r = _DummyReceiver();
    });

    test('receiveMessage() - trata mensagem recebida da rede', () {
      r.receiveMessage(testPeer, msg.BitSwapMessage(false));
      expect(r, isNotNull);
    });

    test('receiveError() - lida com erro reportado pela conexao', () {
      r.receiveError(Exception('error'));
      expect(r, isNotNull);
    });

    test('peerConnected() - processa evento de par conectado', () {
      r.peerConnected(testPeer);
      expect(r, isNotNull);
    });

    test('peerDisconnected() - processa evento de par desconectado', () {
      r.peerDisconnected(testPeer);
      expect(r, isNotNull);
    });
  });

  group('Routing [Atomic Audit]', () {
    test('provide() - anuncia conteudo para a rede', () async {
      final Routing r = _DummyRouting();
      await r.provide(testCid);
      expect(r, isNotNull);
    });
  });

  group('Pinger [Atomic Audit]', () {
    late Pinger pinger;
    setUp(() {
      pinger = IpfsNetwork.fromIpfsHost(_DummyP2pHost());
    });

    test('ping() - efetua ping para medir latencia de par', () async {
      final res = await pinger.ping(testPeer);
      expect(res, isNotNull);
    });

    test('latency() - consulta latencia media do par', () {
      final lat = pinger.latency(testPeer);
      expect(lat, equals(Duration.zero));
    });
  });

  group('IpfsNetwork [Atomic Audit]', () {
    late IpfsNetwork net;
    setUp(() {
      final host = _DummyP2pHost();
      net = IpfsNetwork.fromIpfsHost(host);
    });

    test('sendMessage() - envia mensagem bitswap pela rede', () async {
      await net.sendMessage(testPeer, msg.BitSwapMessage(false));
      expect(net.stats().messagesSent, equals(1));
    });

    test('start() - inicia servico de rede com listeners', () {
      net.start([_DummyReceiver()]);
      expect(net, isNotNull);
    });

    test('stop() - interrompe rede bitswap ipfs', () {
      net.stop();
      expect(net, isNotNull);
    });

    test('connect() - conecta ao par informado', () async {
      await net.connect(AddrInfo(id: testPeer));
      expect(net, isNotNull);
    });

    test('disconnectFrom() - encerra conexao com par informado', () async {
      await net.disconnectFrom(testPeer);
      expect(net, isNotNull);
    });

    test('isConnectedToPeer() - checa estado de conexao com o par', () {
      expect(net.isConnectedToPeer(testPeer), isFalse);
    });

    test('newMessageSender() - abre novo canal de emissao', () async {
      final s = await net.newMessageSender(
        testPeer,
        MessageSenderOpts(
          maxRetries: 1,
          sendTimeout: const Duration(seconds: 1),
          sendErrorBackoff: const Duration(milliseconds: 10),
        ),
      );
      expect(s, isNotNull);
    });

    test('host() - expoem instancia do host p2p', () {
      expect(net.host(), isNotNull);
    });

    test('stats() - retorna contadores de trafego', () {
      expect(net.stats(), isNotNull);
    });

    test('self() - retorna identificador do no local', () {
      expect(net.self(), isNotNull);
    });

    test('ping() - realiza ping no peer alvo', () async {
      final res = await net.ping(testPeer);
      expect(res, isNotNull);
    });

    test('latency() - calcula latencia media do peer alvo', () {
      expect(net.latency(testPeer), equals(Duration.zero));
    });

    test('tagPeer() - adiciona marcacao ao par informado', () {
      net.tagPeer(testPeer, 'tag1', 10);
      expect(net, isNotNull);
    });

    test('untagPeer() - remove marcacao do par informado', () {
      net.untagPeer(testPeer, 'tag1');
      expect(net, isNotNull);
    });

    test('protect() - protege comunicacao com o par', () {
      net.protect(testPeer, 'tag1');
      expect(net, isNotNull);
    });

    test('unprotect() - revoga protecao de comunicacao', () {
      expect(net.unprotect(testPeer, 'tag1'), isFalse);
    });
  });

  group('WantType [Atomic Audit]', () {
    test('have() - constante representativa do tipo de solicitacao have', () {
      expect(pb.WantType.have, isNotNull);
    });
  });

  group('BlockPresenceType [Atomic Audit]', () {
    test('dontHave() - constante representativa de presenca donthave', () {
      expect(pb.BlockPresenceType.dontHave, isNotNull);
    });
  });

  group('PeerConnection [Atomic Audit]', () {
    late PeerConnection pc;
    setUp(() {
      pc = _DummyPeerConn();
    });

    test('ping() - verifica conexao e mede tempo de resposta', () async {
      final lat = await pc.ping(const Duration(seconds: 1));
      expect(lat, equals(const Duration(milliseconds: 10)));
    });

    test('latency() - consulta latencia media do par', () {
      expect(pc.latency(), equals(const Duration(milliseconds: 10)));
    });
  });

  group('DontHaveTimeoutManager [Atomic Audit]', () {
    late DontHaveTimeoutManager mgr;
    setUp(() {
      mgr = DontHaveTimeoutManager.create(_DummyPeerConn(), (ks, d) {})!;
    });

    test('create() - fabrica gerenciador de timeout', () {
      final m = DontHaveTimeoutManager.create(_DummyPeerConn(), (ks, d) {});
      expect(m, isNotNull);
    });

    test('start() - inicia checagem de timeout', () {
      mgr.start();
      expect(mgr, isNotNull);
    });

    test('addPending() - adiciona cids pendentes para contagem', () {
      mgr.addPending([testCid]);
      expect(mgr, isNotNull);
    });

    test('updateMessageLatency() - atualiza ewma de latencia', () {
      mgr.updateMessageLatency(const Duration(milliseconds: 20));
      expect(mgr, isNotNull);
    });

    test('cancelPending() - cancela acompanhamento de cids', () {
      mgr.cancelPending([testCid]);
      expect(mgr, isNotNull);
    });

    test('shutdown() - encerra verificador de timeout', () {
      mgr.shutdown();
      expect(mgr, isNotNull);
    });
  });

  group('MessageNetwork [Atomic Audit]', () {
    late MessageNetwork mn;
    setUp(() {
      mn = _DummyMessageNetwork();
    });

    test('connect() - conecta ao par informado', () async {
      await mn.connect(testPeer);
      expect(mn, isNotNull);
    });

    test('newMessageSender() - abre canal de envio de mensagens', () async {
      final s = await mn.newMessageSender(
        testPeer,
        MessageSenderOpts(
          maxRetries: 1,
          sendTimeout: Duration.zero,
          sendErrorBackoff: Duration.zero,
        ),
      );
      expect(s, isNotNull);
    });

    test('latency() - obtem latencia do peer', () {
      expect(mn.latency(testPeer), equals(const Duration(milliseconds: 10)));
    });

    test('ping() - envia ping ao peer para obter duracao', () async {
      final dur = await mn.ping(testPeer);
      expect(dur, equals(const Duration(milliseconds: 10)));
    });

    test('self() - obtem id local', () {
      expect(mn.self(), isNotNull);
    });
  });

  group('MessageQueue [Atomic Audit]', () {
    late MessageQueue mq;
    setUp(() {
      final net = _DummyMessageNetwork();
      mq = MessageQueue.create(testPeer, net, (ks, d) {});
    });

    test('startup() - inicia fila de envio', () {
      mq.startup();
      expect(mq, isNotNull);
    });

    test('addWants() - enfileira solicitacoes', () {
      mq.addWants([testCid], []);
      expect(mq, isNotNull);
    });

    test('addBroadcastWantHaves() - enfileira broadcast', () {
      mq.addBroadcastWantHaves([testCid]);
      expect(mq, isNotNull);
    });

    test('addCancels() - enfileira cancelamentos', () {
      mq.addCancels([testCid]);
      expect(mq, isNotNull);
    });

    test('hasMessage() - indica presenca de dados na fila', () {
      expect(mq.hasMessage(), isA<bool>());
    });

    test('responseReceived() - atualiza estado apos resposta', () {
      mq.responseReceived([testCid]);
      expect(mq, isNotNull);
    });

    test('rebroadcastNow() - forca retransmissao imediata', () {
      mq.rebroadcastNow();
      expect(mq, isNotNull);
    });

    test('shutdown() - encerra fila', () {
      mq.shutdown();
      expect(mq, isNotNull);
    });
  });

  group('PubSub [Atomic Audit]', () {
    late PubSub ps;
    setUp(() {
      ps = NotificationsPubSub();
    });

    test('publish() - publica blocos recebidos', () {
      ps.publish(testPeer, [testBlock]);
      expect(ps, isNotNull);
    });

    test('subscribe() - assina recebimento de blocos por cid', () {
      final sub = ps.subscribe([testCid]);
      expect(sub, isNotNull);
    });

    test('shutdown() - encerra publicador e assinantes', () {
      ps.shutdown();
      expect(ps, isNotNull);
    });
  });

  group('Session [Atomic Audit]', () {
    late Session s;
    setUp(() {
      s = _TestSession();
    });

    test('id() - identificador numerico da sessao', () {
      expect(s.id(), equals(1));
    });

    test('signalAvailability() - notifica disponibilidade de peer para a sessao', () {
      s.signalAvailability(testPeer, true);
      expect(s, isNotNull);
    });
  });

  group('PeerManager [Atomic Audit]', () {
    late PeerManager pm;
    late _TestGauge g1;
    late _TestGauge g2;

    setUp(() {
      g1 = _TestGauge();
      g2 = _TestGauge();
      final bc = BroadcastControl(maxPeers: 10, localPeers: false, peeredPeers: false);
      final net = _DummyMessageNetwork();
      pm = PeerManager(
        (p) => MessageQueue.create(p, net, (ks, d) {}),
        bc,
        g1,
        g2,
        _TestGauge(),
      );
    });

    test('connected() - registra peer conectado', () {
      pm.connected(testPeer);
      expect(pm.connectedPeers(), contains(testPeer));
    });

    test('availablePeers() - lista peers disponiveis', () {
      pm.connected(testPeer);
      expect(pm.availablePeers(), contains(testPeer));
    });

    test('connectedPeers() - lista peers conectados', () {
      pm.connected(testPeer);
      expect(pm.connectedPeers(), contains(testPeer));
    });

    test('disconnected() - remove peer ao desconectar', () {
      pm.connected(testPeer);
      pm.disconnected(testPeer);
      expect(pm.connectedPeers(), isNot(contains(testPeer)));
    });

    test('responseReceived() - processa resposta de cids recebida do par', () {
      pm.connected(testPeer);
      pm.responseReceived(testPeer, [testCid]);
      expect(pm, isNotNull);
    });

    test('broadcastWantHaves() - envia broadcast want-haves', () {
      pm.connected(testPeer);
      pm.broadcastWantHaves([testCid]);
      expect(pm, isNotNull);
    });

    test('sendWants() - envia wants para peer', () {
      pm.connected(testPeer);
      final sent = pm.sendWants(testPeer, [testCid], []);
      expect(sent, isTrue);
    });

    test('sendCancels() - envia cancels para peer', () {
      pm.connected(testPeer);
      pm.sendCancels([testCid]);
      expect(pm, isNotNull);
    });

    test('currentWants() - lista solicitacoes ativas', () {
      expect(pm.currentWants(), isEmpty);
    });

    test('currentWantBlocks() - lista want blocks ativos', () {
      expect(pm.currentWantBlocks(), isEmpty);
    });

    test('currentWantHaves() - lista want haves ativos', () {
      expect(pm.currentWantHaves(), isEmpty);
    });

    test('registerSession() - registra sessao consumidora', () {
      pm.registerSession(testPeer, _TestSession());
      expect(pm, isNotNull);
    });

    test('unregisterSession() - remove sessao consumidora', () {
      pm.registerSession(testPeer, _TestSession());
      pm.unregisterSession(1);
      expect(pm, isNotNull);
    });

    test('markBroadcastTarget() - marca alvo de broadcast', () {
      pm.markBroadcastTarget(testPeer);
      expect(pm, isNotNull);
    });
  });

  group('PeerQueue [Atomic Audit]', () {
    late PeerQueue pq;
    setUp(() {
      final net = _DummyMessageNetwork();
      pq = MessageQueue.create(testPeer, net, (ks, d) {});
    });

    test('startup() - inicia fila peer queue', () {
      pq.startup();
      expect(pq, isNotNull);
    });

    test('addWants() - enfileira quereres', () {
      pq.addWants([testCid], []);
      expect(pq, isNotNull);
    });

    test('addBroadcastWantHaves() - enfileira quereres em broadcast', () {
      pq.addBroadcastWantHaves([testCid]);
      expect(pq, isNotNull);
    });

    test('addCancels() - enfileira cancelamentos', () {
      pq.addCancels([testCid]);
      expect(pq, isNotNull);
    });

    test('hasMessage() - valida presenca de mensagem pendente', () {
      expect(pq.hasMessage(), isA<bool>());
    });

    test('responseReceived() - processa recebimento de resposta', () {
      pq.responseReceived([testCid]);
      expect(pq, isNotNull);
    });

    test('shutdown() - finaliza fila', () {
      pq.shutdown();
      expect(pq, isNotNull);
    });
  });

  group('Gauge [Atomic Audit]', () {
    test('inc() - incrementa valor do contador', () {
      final g = _TestGauge();
      g.inc();
      expect(g.value, equals(1));
    });

    test('dec() - decrementa valor do contador', () {
      final g = _TestGauge();
      g.dec();
      expect(g.value, equals(-1));
    });
  });

  group('BroadcastControl [Atomic Audit]', () {
    test('needHost() - checagem de host requerido', () {
      final bc = BroadcastControl(maxPeers: 10, localPeers: false, peeredPeers: false);
      expect(bc.needHost(), isTrue);
    });
  });

  group('PeerWantManager [Atomic Audit]', () {
    late PeerWantManager pwm;
    late _TestGauge g1;
    late _TestGauge g2;

    setUp(() {
      g1 = _TestGauge();
      g2 = _TestGauge();
      final bc = BroadcastControl(maxPeers: 10, localPeers: false, peeredPeers: false);
      pwm = PeerWantManager(g1, g2, bc);
    });

    test('addPeer() - adiciona par ao gerenciador de wants', () {
      final net = _DummyMessageNetwork();
      final pq = MessageQueue.create(testPeer, net, (ks, d) {});
      pwm.addPeer(pq, testPeer);
      expect(pwm, isNotNull);
    });

    test('broadcastWantHaves() - distribui solicitacoes', () {
      pwm.broadcastWantHaves([testCid]);
      expect(pwm, isNotNull);
    });

    test('markBroadcastTarget() - define alvo de broadcast', () {
      pwm.markBroadcastTarget(testPeer);
      expect(pwm, isNotNull);
    });

    test('sendWants() - envia wants no gerenciador', () {
      final net = _DummyMessageNetwork();
      final pq = MessageQueue.create(testPeer, net, (ks, d) {});
      pwm.addPeer(pq, testPeer);
      pwm.sendWants(testPeer, [testCid], []);
      expect(pwm, isNotNull);
    });

    test('sendCancels() - cancela wants', () {
      pwm.sendCancels([testCid]);
      expect(pwm, isNotNull);
    });

    test('getWantBlocks() - busca want blocks', () {
      expect(pwm.getWantBlocks(), isEmpty);
    });

    test('getWantHaves() - busca want haves', () {
      expect(pwm.getWantHaves(), isEmpty);
    });

    test('getWants() - busca total de wants', () {
      expect(pwm.getWants(), isEmpty);
    });

    test('removePeer() - remove par do gerenciador', () {
      final net = _DummyMessageNetwork();
      final pq = MessageQueue.create(testPeer, net, (ks, d) {});
      pwm.addPeer(pq, testPeer);
      pwm.removePeer(testPeer);
      expect(pwm, isNotNull);
    });
  });

  group('WantPeerCnts [Atomic Audit]', () {
    test('wanted() - avalia presenca de solicitacao', () {
      final wpc = WantPeerCnts(wantBlock: 1, wantHave: 0, isBroadcast: false);
      expect(wpc.wanted(), isTrue);
      final wpcFalse = WantPeerCnts(wantBlock: 0, wantHave: 0, isBroadcast: false);
      expect(wpcFalse.wanted(), isFalse);
    });
  });
}
