import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:transpiled_ipfs/transpiled_ipfs.dart';

Future<void> main() async {
  // 1. Configuração declarativa do nó embutido seguindo os padrões do Kubo
  final announceAddr = Platform.environment['DART_IPFS_ANNOUNCE_ADDR'];
  final config = IpfsConfig(
    offline: false,
    network: NetworkConfig(
      listenAddresses: const ['/ip4/0.0.0.0/tcp/4002'],
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

  dev.log('Iniciando o nó IPFS embutido...', name: 'ipfs.daemon');
  final node = await IpfsNode.fromBuildCfg(
    BuildCfg(config: config, online: true),
  );

  dev.log('Nó ativo localmente. PeerId: ${node.peerId}', name: 'ipfs.daemon');

  // 2. Fase de Bootstrap e Negociação de Rede (seguindo o ciclo do daemon do Kubo)
  // Conecta aos nós de bootstrap para iniciar o caminhamento Kademlia,
  // troca de Identify (Observed Addresses), AutoNAT e mapeamento UPnP.
  dev.log('Conectando aos pares de bootstrap e negociando presença na rede...', name: 'ipfs.daemon');
  for (final boot in config.network.bootstrapPeers) {
    try {
      await node.connect(addrInfoFromString(boot));
      dev.log('  Conectado: $boot', name: 'ipfs.daemon');
    } catch (e) {
      dev.log('  Aviso ao conectar em $boot: $e', name: 'ipfs.daemon');
    }
  }

  // Aguarda a estabilização da negociação de rede (Identify / UPnP / Kademlia table)
  dev.log('Aguardando estabilização da rede e descoberta de endereços...', name: 'ipfs.daemon');
  await Future<void>.delayed(const Duration(seconds: 4));

  dev.log('Daemon pronto! Endereços swarm ativos:', name: 'ipfs.daemon');
  for (final addr in node.swarmAddresses) {
    dev.log('  $addr', name: 'ipfs.daemon');
  }

  // 3. SOMENTE AGORA (com o nó pronto e negociado) armazenamos o conteúdo no Blockstore
  final content = Uint8List.fromList('Exemplo Nó Embutido Dart IPFS'.codeUnits);
  final cid = await node.putRawBlock(content);
  dev.log('Conteúdo armazenado no blockstore: $cid', name: 'ipfs.daemon');

  // 4. Anúncio público na Amino DHT com os endereços já consolidados
  dev.log('Anunciando CID na Amino DHT com os endereços consolidados...', name: 'ipfs.daemon');
  await node.provide(cid);
  dev.log('CID anunciado com sucesso na DHT!', name: 'ipfs.daemon');

  dev.log('Daemon em execução contínua servindo Bitswap e DHT.', name: 'ipfs.daemon');

  // 5. Ciclo de vida: Aguarda encerramento (sinal do SO) e realiza shutdown limpo
  final cancelSignal = Completer<void>();
  StreamSubscription<ProcessSignal>? sub;
  try {
    sub = ProcessSignal.sigint.watch().listen((_) {
      if (!cancelSignal.isCompleted) cancelSignal.complete();
    });
  } catch (_) {}

  await cancelSignal.future;
  await sub?.cancel();

  dev.log('Encerrando o nó IPFS...', name: 'ipfs.daemon');
  await node.close();
  dev.log('Nó encerrado com sucesso!', name: 'ipfs.daemon');
}
