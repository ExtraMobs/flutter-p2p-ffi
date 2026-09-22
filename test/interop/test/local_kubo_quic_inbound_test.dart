@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/local_kubo_harness.dart';

/// Marco G.1, direcao de entrada -- um Kubo real disca o `/quic-v1` do no Dart.
///
/// O teste complementar `local_kubo_quic_test.dart` prova a discagem (Dart
/// disca Kubo). Aqui o sentido e o oposto e e o unico que exercita
/// `QuicServer`: o no Dart apenas escuta, e quem abre a conexao, negocia o
/// handshake TLS 1.3 em CRYPTO frames e pede o bloco por Bitswap e o Kubo.
/// O no Dart nao disca o Kubo em momento algum, para que uma conexao de saida
/// nao mascare a falha da de entrada.
void main() {
  test(
      'Kubo dials the Dart node over quic-v1 and downloads a block '
      '(Marco G.1, inbound)', () async {
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
              listenAddresses: ['/ip4/127.0.0.1/udp/0/quic-v1'],
              bootstrapPeers: [],
            ),
          ),
        ),
      );

      expect(node.isOnline, isTrue);
      final quicAddr = node.swarmAddresses.firstWhere(
        (a) => a.contains('quic-v1'),
        orElse: () => throw StateError(
          'Dart node published no /quic-v1 address: ${node!.swarmAddresses}',
        ),
      );

      final testBytes = Uint8List.fromList(
        'dart-ipfs-quic-inbound-${DateTime.now().millisecondsSinceEpoch}'
            .codeUnits,
      );
      final cid = await node.putRawBlock(testBytes);
      printOnFailure('Kubo dialling Dart at $quicAddr for cid=$cid');

      await kubo.swarmConnect(quicAddr);

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
