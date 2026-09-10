// ignore_for_file: avoid_print
//
// test/routing/dht_public_discovery_network_test.dart
//
// Marco E.3 -- prova de descoberta cega publica.
//
// Um bloco novo, gerado aleatoriamente nesta execucao e hospedado
// exclusivamente pelo no Dart, e anunciado na Amino DHT publica via
// DhtClient.provide (que por sua vez usa o caminhamento iterativo Kademlia de
// getClosestPeers -- Marcos E.1 e E.2). Em seguida o teste consulta gateways
// HTTPS publicos APENAS pelo CID: nenhum multiaddr, nenhum `swarm connect`
// manual e nenhum daemon Kubo intermediando o anuncio.
//
// Se um gateway devolver os bytes exatos, a unica explicacao possivel e que
// ele resolveu o CID -> provider na DHT a partir do ADD_PROVIDER emitido pelo
// no Dart, conectou no endereco WAN anunciado e baixou o bloco via Bitswap.
//
// Depende de internet real e de um endereco WAN discavel, entao e marcado
// 'network' e pulado por padrao (ver dart_test.yaml). Rode explicitamente com
// `dart test --preset network test/routing/dht_public_discovery_network_test.dart`.
//
// Requer a variavel de ambiente DART_IPFS_ANNOUNCE_ADDR com o multiaddr WAN
// publicamente alcancavel deste host, por exemplo:
//   DART_IPFS_ANNOUNCE_ADDR=/ip4/203.0.113.47/tcp/4002
// Opcionalmente DART_IPFS_LISTEN_ADDR (padrao /ip4/0.0.0.0/tcp/4002).
@Tags(['network'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

/// Bootstrappers publicos da Amino DHT usados como ponto de entrada do
/// caminhamento iterativo. Um unico bootstrapper alcancavel ja basta: o resto
/// da rede e descoberto pelos `closerPeers` das respostas FIND_NODE.
const List<String> _publicBootstrapPeers = [
  '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
  '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
  '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
  '/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
];

/// Gateways HTTPS publicos consultados apenas pelo CID.
const List<String> _publicGateways = [
  'https://ipfs.io',
  'https://dweb.link',
  'https://gateway.pinata.cloud',
];

/// Tempo total concedido para o bloco se tornar publicamente descobrivel.
const Duration _discoveryBudget = Duration(minutes: 6);

/// Intervalo entre rodadas de consulta aos gateways.
const Duration _pollInterval = Duration(seconds: 20);

/// Intervalo de reanuncio na DHT enquanto a descoberta nao acontece.
const Duration _reprovideInterval = Duration(minutes: 2);

void main() {
  final announceAddr = Platform.environment['DART_IPFS_ANNOUNCE_ADDR'];
  final listenAddr =
      Platform.environment['DART_IPFS_LISTEN_ADDR'] ?? '/ip4/0.0.0.0/tcp/4002';

  test(
    'gateways publicos descobrem bloco hospedado so pelo no Dart usando apenas o CID (Marco E.3)',
    () async {
      final config = IpfsConfig(
        offline: false,
        network: NetworkConfig(
          listenAddresses: [listenAddr],
          announceAddresses: [announceAddr!],
          bootstrapPeers: _publicBootstrapPeers,
        ),
      );

      final node = await IpfsNode.fromBuildCfg(
        BuildCfg(config: config, online: true),
      );
      addTearDown(node.close);

      // Impresso sempre (nao so em falha): e a evidencia auditavel do marco.
      print('[E.3] PeerId do no Dart: ${node.peerId.toBase58()}');
      print('[E.3] Enderecos anunciados: ${node.listenAddresses}');

      // Conecta na rede publica. Falhas individuais sao toleradas: basta um
      // bootstrapper responder para o caminhamento iterativo comecar.
      var connected = 0;
      for (final boot in _publicBootstrapPeers) {
        try {
          await node.connect(addrInfoFromString(boot));
          connected++;
        } catch (e) {
          printOnFailure('Falha ao conectar em $boot: $e');
        }
      }
      expect(
        connected,
        greaterThan(0),
        reason: 'nenhum bootstrapper publico alcancado; sem rede nao ha prova',
      );

      // Bloco novo e irrepetivel: garante que nenhum gateway possa ja te-lo em
      // cache e que nenhum outro no do planeta o esteja hospedando.
      final rng = Random.secure();
      final payload = Uint8List.fromList(
        List<int>.generate(256, (_) => rng.nextInt(256)),
      );
      final cid = await node.putRawBlock(payload);
      final cidString = cid.encode();
      print('[E.3] CID recem-gerado: $cidString');

      // Anuncio autonomo na DHT: getClosestPeers -> ADD_PROVIDER aos 20 mais
      // proximos. Sem `ipfs routing provide` de daemon externo.
      await node.provide(cid);

      final found = await _pollGatewaysUntilServed(
        cidString: cidString,
        expected: payload,
        reprovide: () => node.provide(cid),
      );

      expect(
        found,
        isNotNull,
        reason:
            'nenhum gateway publico serviu o bloco $cidString em '
            '${_discoveryBudget.inMinutes} min a partir do CID sozinho',
      );
      print('[E.3] Gateway que serviu o bloco: $found');
    },
    timeout: const Timeout(Duration(minutes: 12)),
    skip: announceAddr == null
        ? 'defina DART_IPFS_ANNOUNCE_ADDR com o multiaddr WAN publico deste host'
        : null,
  );
}

/// Consulta os gateways em rodadas ate um deles devolver [expected], ou ate
/// esgotar [_discoveryBudget]. Retorna a URL que serviu o bloco, ou null.
Future<String?> _pollGatewaysUntilServed({
  required String cidString,
  required Uint8List expected,
  required Future<void> Function() reprovide,
}) async {
  final client = HttpClient();
  try {
    final deadline = DateTime.now().add(_discoveryBudget);
    var nextReprovide = DateTime.now().add(_reprovideInterval);

    while (DateTime.now().isBefore(deadline)) {
      for (final gateway in _publicGateways) {
        final url = '$gateway/ipfs/$cidString?format=raw';
        final body = await _fetchRawBlock(client, url);
        if (body != null && _bytesEqual(body, expected)) return url;
      }

      if (DateTime.now().isAfter(nextReprovide)) {
        try {
          await reprovide();
        } catch (e) {
          printOnFailure('Falha ao reanunciar na DHT: $e');
        }
        nextReprovide = DateTime.now().add(_reprovideInterval);
      }

      await Future<void>.delayed(_pollInterval);
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Busca o bloco bruto em [url]. Retorna null em qualquer falha ou status != 200,
/// que e o caso esperado enquanto o CID ainda nao foi propagado na DHT.
Future<Uint8List?> _fetchRawBlock(HttpClient client, String url) async {
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.ipld.raw');
    final response = await request.close().timeout(const Duration(seconds: 45));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      printOnFailure('$url -> HTTP ${response.statusCode}');
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } catch (e) {
    printOnFailure('$url -> $e');
    return null;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
