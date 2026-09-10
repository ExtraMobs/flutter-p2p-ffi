@Tags(['p1'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

import '../lib/deterministic_text_fixture.dart';
import '../lib/local_kubo_harness.dart';

/// Optional hook for the future Dart UnixFS implementation.
///
/// The callback owns the returned file. It receives the isolated Kubo handle,
/// exact fixture, and Kubo root Cid, then returns the Dart-exported file for
/// streaming comparison.
typedef DartUnixFsExporter = Future<File> Function(
  LocalKuboHarness kubo,
  File fixture,
  String cid,
  File kuboCar,
);

void main() {
  test(
    'Kubo adds large deterministic UnixFS files and exports their DAGs',
    () async {
      final executable = await LocalKuboHarness.findExecutable();
      if (executable == null) {
        markTestSkipped('Kubo executable not found; set IPFS_EXECUTABLE');
        return;
      }

      await runLargeUnixfsInterop(
        executable: executable,
        sizes: _selectedSizes(),
        dartExport: _downloadExportImport,
      );
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

Future<File> _downloadExportImport(
  LocalKuboHarness kubo,
  File fixture,
  String encodedCid,
  File kuboCar,
) async {
  final cid = Cid.decode(encodedCid);
  final output = File('${fixture.path}.dart');
  final car = File('${fixture.path}.dart.car');
  IpfsNode? online;
  IpfsNode? offline;
  try {
    online = await IpfsNode.fromBuildCfg(
      BuildCfg(
        online: true,
        config: const IpfsConfig(
          offline: false,
          network: NetworkConfig(bootstrapPeers: []),
          bitswap: BitswapConfig(p2pTimeout: Duration(minutes: 2)),
        ),
      ),
    );
    await online.connect(addrInfoFromString(kubo.swarmAddress));

    final sink = car.openWrite();
    await sink.addStream(online.exportCar(cid));
    await sink.close();
    await kubo.importCar(car);
    final stat = await online.statUnixFs(cid);
    expect(stat.size, await fixture.length());
    final dartCids = await online.listUnixFsCids(cid).toList();
    final kuboCids = await kubo.refsRecursive(encodedCid);
    expect(
      dartCids.skip(1).map((value) => value.encode()).toSet(),
      kuboCids.toSet(),
    );

    offline = await IpfsNode.fromBuildCfg(BuildCfg());
    final header = await offline.importCar(kuboCar.openRead());
    expect(header.roots, [cid]);
    final outputSink = output.openWrite();
    await outputSink.addStream(offline.getUnixFs(cid));
    await outputSink.close();
    return output;
  } finally {
    await offline?.close();
    await online?.close();
    if (await car.exists()) await car.delete();
  }
}

/// Runs the serial Kubo fixture proof and optionally verifies a Dart export.
///
/// Keeping [dartExport] optional allows this test to run before the Dart
/// UnixFS API exists; a caller with that API can inject it without changing
/// the Kubo lifecycle or fixture generation.
Future<void> runLargeUnixfsInterop({
  required String executable,
  required Iterable<int> sizes,
  DartUnixFsExporter? dartExport,
}) async {
  LocalKuboHarness? kubo;
  final created = <File>[];
  try {
    kubo = await LocalKuboHarness.start(executable: executable);
    final version = await kubo.version();
    for (final sizeMiB in sizes) {
      final fixture = await writeDeterministicTextFixture(
        root: LocalKuboHarness.validationRoot(),
        sizeMiB: sizeMiB,
      );
      created.add(fixture);

      final cid = await kubo.addFile(fixture);
      final stat = await kubo.stat(cid);
      final refs = await kubo.refsRecursive(cid);
      final car = await kubo.exportCar(cid);
      created.add(car);

      expect(stat['Cid'], cid);
      expect(refs, isNotEmpty);
      expect(await car.length(), greaterThan(0));
      if (dartExport != null) {
        final dartFile = await dartExport(kubo, fixture, cid, car);
        try {
          expect(await filesEqualStreaming(fixture, dartFile), isTrue);
        } finally {
          if (dartFile.path != fixture.path && await dartFile.exists()) {
            await dartFile.delete();
          }
        }
      }
      printOnFailure(
        'Kubo $version size=${sizeMiB}MiB cid=$cid '
        'stat=$stat refs=${refs.length} car=${await car.length()} bytes',
      );
    }
  } catch (_) {
    if (kubo != null) {
      try {
        printOnFailure(await kubo.diagnostics());
      } catch (error) {
        printOnFailure('Kubo diagnostics unavailable: $error');
      }
      printOnFailure('Kubo stdout:\n${kubo.stdoutLog}');
      printOnFailure('Kubo stderr:\n${kubo.stderrLog}');
    }
    rethrow;
  } finally {
    try {
      for (final file in created.reversed) {
        if (await file.exists()) await file.delete();
      }
    } finally {
      await kubo?.dispose();
    }
  }
}

List<int> _selectedSizes() {
  const configured = String.fromEnvironment('KUBO_LARGE_FIXTURE_SIZES');
  final value = Platform.environment['KUBO_LARGE_FIXTURE_SIZES'] ?? configured;
  if (value.trim().isEmpty || value.trim().toLowerCase() == 'all') {
    return largeFixtureSizesMiB;
  }
  final sizes =
      value.split(',').map((part) => int.tryParse(part.trim())).toList();
  if (sizes
      .any((size) => size == null || !largeFixtureSizesMiB.contains(size))) {
    throw StateError(
      'KUBO_LARGE_FIXTURE_SIZES must be a comma-separated subset of '
      '${largeFixtureSizesMiB.join(',')}',
    );
  }
  return sizes.cast<int>();
}
