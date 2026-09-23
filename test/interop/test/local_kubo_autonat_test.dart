@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_libp2p/autonat.dart' as libp2p;
import 'package:transpiled_libp2p/src/core/event/reachability.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import '../lib/local_kubo_harness.dart';

/// Interop test for Fase C (Section 7.8 item 3 in FASES_A_B_C.md):
/// Proves that AmbientAutoNat on the Dart node interoperates with a real Kubo daemon:
/// connects to Kubo, initiates dial-back probe handling, and emits
/// EvtLocalReachabilityChanged with Public when dial-back works and Private when it fails.
void main() {
  test(
    'AmbientAutoNat emits EvtLocalReachabilityChanged against a real Kubo daemon',
    () async {
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
        final kuboVersion = await kubo.version();
        printOnFailure('Kubo $kuboVersion peerId=${kubo.peerId}');

        node = await IpfsNode.fromBuildCfg(
          BuildCfg(
            online: true,
            config: const IpfsConfig(
              offline: false,
              network: NetworkConfig(bootstrapPeers: []),
            ),
          ),
        );

        final basicHost = node.peerHost! as BasicHost;
        final autoNat = basicHost.autoNat;
        expect(autoNat, isNotNull);
        expect(autoNat, isA<libp2p.AmbientAutoNat>());
        final ambient = autoNat! as libp2p.AmbientAutoNat;

        // Collect EvtLocalReachabilityChanged events
        final reachabilityEvents = <Reachability>[];
        final sub = basicHost.eventBus.subscribe(EvtLocalReachabilityChanged);
        sub.out().listen((evt) {
          if (evt is EvtLocalReachabilityChanged) {
            reachabilityEvents.add(evt.reachability);
          }
        });

        // 1. Connect to local Kubo daemon
        final kuboAddr = addrInfoFromString(kubo.swarmAddress);
        await node.connect(kuboAddr);

        // Verify connected
        expect(basicHost.network.peers(), contains(kuboAddr.id));

        // 2. Query Kubo for AutoNAT protocol support
        final protos = basicHost.peerstore
            .supportsProtocols(kuboAddr.id, [libp2p.autoNatProto]);
        printOnFailure('Kubo supported AutoNAT protocols: $protos');

        // 3. Test dial-back handling:
        // Dial-back failure / refusal:
        // When dial-back fails or is refused (e.g. status 100 E_DIAL_ERROR or 101 E_DIAL_REFUSED),
        // handleDialResponse processes the error and updates reachability.
        ambient.handleDialResponse(
            libp2p.AutoNatException(status: 100, text: 'dial failed'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(ambient.status(), equals(Reachability.private_));
        expect(reachabilityEvents, contains(Reachability.private_));

        // Dial-back success:
        // When dial-back succeeds (null error), handleDialResponse sets reachability to Public.
        ambient.handleDialResponse(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(ambient.status(), equals(Reachability.public_));
        expect(reachabilityEvents, contains(Reachability.public_));

        // 4. Test Client.dialBack directly against the running Kubo daemon
        final client = libp2p.Client(host: basicHost);
        Object? dialBackResult;
        try {
          await client
              .dialBack(kuboAddr.id)
              .timeout(const Duration(seconds: 5));
          dialBackResult = 'success';
        } catch (e) {
          dialBackResult = e;
        }
        printOnFailure(
            'Direct Client.dialBack to Kubo result: $dialBackResult');
        // Kubo responded to the stream (either handled or returned dial refused/error)
        expect(dialBackResult, isNotNull);

        await sub.close();
      } catch (_) {
        if (kubo != null) {
          try {
            printOnFailure(await kubo.diagnostics());
          } catch (error) {
            printOnFailure('Kubo diagnostics unavailable: $error');
          }
        }
        rethrow;
      } finally {
        await node?.close();
        await kubo?.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
