@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

/// Marco G.4, direcao de entrada -- um Kubo real disca o
/// `/quic-v1/webtransport` do no Dart.
///
/// Complementa `local_kubo_webtransport_quic_test.dart`, que prova a discagem.
/// Aqui quem abre a sessao e o Kubo: QUIC com ALPN `h3`, certificado fixado
/// pelo `certhash` que o no Dart publica no proprio multiaddr, Extended
/// CONNECT em `/.well-known/libp2p-webtransport?type=noise` e handshake Noise
/// dentro da sessao. O no Dart nao disca o Kubo, para que uma conexao de saida
/// nao mascare a falha da de entrada.
void main() {
  test(
      'Kubo dials the Dart node over quic-v1/webtransport and downloads a '
      'block (Marco G.4, inbound)', () async {
    final executable = await LocalKuboHarness.findExecutable();
    if (executable == null) {
      markTestSkipped(
        'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
      );
      return;
    }

    LocalKuboHarness? kubo;
    IpfsNode? node;
    try {
      kubo = await LocalKuboHarness.start(executable: executable);

      node = await IpfsNode.fromBuildCfg(
        BuildCfg(
          online: true,
          config: const IpfsConfig(
            offline: false,
            network: NetworkConfig(
              listenAddresses: ['/ip4/127.0.0.1/udp/0/quic-v1/webtransport'],
              bootstrapPeers: [],
            ),
          ),
        ),
      );

      expect(node.isOnline, isTrue);
      final wtAddr = node.swarmAddresses.firstWhere(
        (a) => a.contains('webtransport'),
        orElse: () => throw StateError(
          'Dart node published no /webtransport address: '
          '${node!.swarmAddresses}',
        ),
      );
      expect(
        wtAddr,
        contains('certhash'),
        reason: 'a WebTransport multiaddr without certhash cannot be dialled: '
            'the peer has no way to pin the certificate',
      );

      final testBytes = Uint8List.fromList(
        'dart-ipfs-webtransport-inbound-'
                '${DateTime.now().millisecondsSinceEpoch}'
            .codeUnits,
      );
      final cid = await node.putRawBlock(testBytes);
      printOnFailure('Kubo dialling Dart at $wtAddr for cid=$cid');

      await kubo.swarmConnect(wtAddr);

      final downloaded = await kubo.getRawBlock(cid.toString());
      expect(downloaded, orderedEquals(testBytes));
    } catch (_) {
      printOnFailure('Kubo stdout:\n${kubo?.stdoutLog}');
      printOnFailure('Kubo stderr:\n${kubo?.stderrLog}');
      rethrow;
    } finally {
      if (node != null) await node.close();
      await kubo?.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
