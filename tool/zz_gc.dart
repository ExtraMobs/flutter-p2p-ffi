// Temporary (not for git): is Go memory held by Dart handles given back?
//   dart run tool/zz_gc.dart [all|finalizer|release|release-flush|scope]
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/go/bytes.dart' as bytes;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/p2p_ffi.dart' show GoHandleUse, P2pService, withGoScope;

int hostMb() {
  final pid = P2pService.hostPid;
  if (Platform.isWindows) {
    final out = Process.runSync(
      'tasklist',
      ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'],
    ).stdout as String;
    final kb = out.split('","').last.replaceAll(RegExp(r'[^0-9]'), '');
    return int.parse(kb) ~/ 1024;
  }
  final status = File('/proc/$pid/status').readAsLinesSync();
  for (final line in status) {
    if (line.startsWith('VmRSS:')) {
      final kb = line.replaceAll(RegExp(r'[^0-9]'), '');
      return int.parse(kb) ~/ 1024;
    }
  }
  return -1;
}

void round(String mode, String big) {
  for (var i = 0; i < 40; i++) {
    switch (mode) {
      case 'finalizer':
        final buf = bytes.Buffer(Uint8List(0));
        final f = os.open(big);
        io.copy(buf, f);
        f.close();
      case 'release':
        bytes.Buffer(Uint8List(0)).use((buf) {
          os.open(big).use((f) {
            io.copy(buf, f);
            f.close();
          });
        });
      case 'scope':
        withGoScope((s) {
          final buf = s.manage(bytes.Buffer(Uint8List(0)));
          final f = s.manage(os.open(big));
          io.copy(buf, f);
          f.close();
        });
      default:
        throw ArgumentError('Unknown mode: $mode');
    }
  }
}

/// Allocates Dart Objects on the Dart heap to trigger Dart's GC + Finalizers.
void forceDartGcPressure() {
  var sink = 0;
  for (var i = 0; i < 200; i++) {
    final list = List<int>.filled(65536, i);
    sink ^= list.first;
  }
  if (sink == -1) print(sink);
}

Future<({int start, List<int> rounds, int idle, int round4AfterGc})> runMode(
  String mode,
  String big,
) async {
  await P2pService.start();
  try {
    final startMb = hostMb();
    print('\n[$mode] start: host $startMb MB');
    final rounds = <int>[];
    for (var r = 1; r <= 3; r++) {
      round(mode, big);
      await Future<void>.delayed(const Duration(seconds: 1));
      final mb = hostMb();
      rounds.add(mb);
      print('[$mode] after round $r (40 x 16 MiB = 640 MiB), Dart idle: '
          'host $mb MB');
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    final idleMb = hostMb();
    print('[$mode] 3 s later (still Dart idle): host $idleMb MB');

    forceDartGcPressure();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    round(mode, big);
    await Future<void>.delayed(const Duration(seconds: 1));
    final round4Mb = hostMb();
    print('[$mode] after Dart GC + round 4 (reusing freed Go heap): '
        'host $round4Mb MB');

    return (
      start: startMb,
      rounds: rounds,
      idle: idleMb,
      round4AfterGc: round4Mb,
    );
  } finally {
    await P2pService.stop();
  }
}

Future<void> main(List<String> args) async {
  final arg = args.isEmpty ? 'all' : args.first;
  final modes = arg == 'all' ? const ['finalizer', 'release', 'scope'] : [arg];

  final tmp = Directory.systemTemp.createTempSync('gc_');
  final big = '${tmp.path}/big.bin';
  File(big).writeAsBytesSync(Uint8List(16 << 20)); // 16 MiB
  try {
    final results = <String,
        ({int start, List<int> rounds, int idle, int round4AfterGc})>{};
    for (final mode in modes) {
      results[mode] = await runMode(mode, big);
    }

    if (results.length > 1) {
      print('\n=== Summary (p2p_host RSS in MB, 640 MiB per round) ===');
      print(
        '${'Mode'.padRight(14)}'
        '${'Start'.padLeft(8)}'
        '${'Round 1'.padLeft(10)}'
        '${'Round 2'.padLeft(10)}'
        '${'Round 3'.padLeft(10)}'
        '${'Idle (3s)'.padLeft(12)}'
        '${'GC + Rnd 4'.padLeft(13)}',
      );
      for (final e in results.entries) {
        final v = e.value;
        print(
          '${e.key.padRight(14)}'
          '${'${v.start}'.padLeft(8)}'
          '${'${v.rounds[0]}'.padLeft(10)}'
          '${'${v.rounds[1]}'.padLeft(10)}'
          '${'${v.rounds[2]}'.padLeft(10)}'
          '${'${v.idle}'.padLeft(12)}'
          '${'${v.round4AfterGc}'.padLeft(13)}',
        );
      }
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
