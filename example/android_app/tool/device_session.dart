// The session on the real device, timed (the cable stays ~1 h): runs the steps
// in order and writes everything to a log. Usage (in example/android_app):
//   dart run tool/device_session.dart <serial> [step...] [--log=file]
// Steps (none: all of them, in this order): info integration network memory
// notification fgs stop. Needs adb on the PATH or in <Android SDK>/platform-tools,
// flutter on the PATH and the binaries of `dart run tool/build.dart android`.
// The log has device data: do not commit it (the summary goes to TODO.md without
// model, serial or IPs).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const app = 'dev.extramobs.p2p_ffi_android';
const host = 'libipfs_host.so';
const steps = [
  'info',
  'integration',
  'network',
  'memory',
  'notification',
  'fgs',
  'stop'
];

late String serial;
late IOSink log;

void out(String s) {
  final t = DateTime.now().toIso8601String().substring(11, 19);
  stdout.writeln('$t $s');
  log.writeln('$t $s');
}

String get adb {
  final sdk = Platform.environment['ANDROID_HOME'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}/Android/Sdk'
          : '${Platform.environment['HOME']}/Android/Sdk');
  final p = '$sdk/platform-tools/adb${Platform.isWindows ? '.exe' : ''}';
  return File(p).existsSync() ? p : 'adb';
}

Future<String> sh(String cmd) async {
  final r = await Process.run(adb, ['-s', serial, 'shell', cmd]);
  return '${r.stdout}${r.stderr}'.trim();
}

/// Runs and mirrors the output to the log; returns the exit code.
Future<int> run(String exe, List<String> args) async {
  out('\$ $exe ${args.join(' ')}');
  final p = await Process.start(exe, args, runInShell: Platform.isWindows);
  await Future.wait([
    for (final s in [p.stdout, p.stderr])
      s.transform(utf8.decoder).transform(const LineSplitter()).forEach(out)
  ]);
  final code = await p.exitCode;
  out('exit code: $code');
  return code;
}

Future<String> hostPid() => sh('pidof $host');

/// The device's --target-platform: arm64 on a phone, x64 on the emulator.
Future<String> platform() async =>
    (await sh('getprop ro.product.cpu.abi')) == 'x86_64'
        ? 'android-x64'
        : 'android-arm64';

/// Installs the app with background mode [mode] and opens it.
Future<void> launch(String mode) async {
  await run('flutter', [
    'build',
    'apk',
    '--debug',
    '--target-platform',
    await platform(),
    '--dart-define=IPFS_BACKGROUND=$mode'
  ]);
  await run(adb, [
    '-s',
    serial,
    'install',
    '-r',
    '-g', // -g grants the runtime permissions, except in the notification step
    'build/app/outputs/flutter-apk/app-debug.apk'
  ]);
  await sh('am start -n $app/.MainActivity');
}

/// Watches the host for [d] with the app in the background (HOME).
Future<void> background(Duration d) async {
  await sh('input keyevent KEYCODE_HOME');
  final sw = Stopwatch()..start();
  while (sw.elapsed < d) {
    out('${sw.elapsed.inSeconds} s in the background: host pid '
        '"${await hostPid()}", app pid "${await sh('pidof $app')}"');
    await Future<void>.delayed(const Duration(seconds: 30));
  }
  await sh('am start -n $app/.MainActivity');
  await Future<void>.delayed(const Duration(seconds: 5));
  out('back: host pid "${await hostPid()}"');
  out((await sh('logcat -d -s flutter | tail -n 40')));
}

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.isEmpty) {
    stderr
        .writeln('usage: dart run tool/device_session.dart <serial> [step...]');
    exit(64);
  }
  serial = positional.first;
  final chosen = positional.length > 1 ? positional.sublist(1) : steps;
  final logPath = args
      .firstWhere((a) => a.startsWith('--log='), orElse: () => '')
      .replaceFirst('--log=', '')
      .ifEmpty('device_session.log');
  log = File(logPath).openWrite(mode: FileMode.append);
  final total = Stopwatch()..start();
  for (final step in chosen) {
    out('=== $step (session at ${total.elapsed.inMinutes} min) ===');
    switch (step) {
      case 'info':
        for (final p in [
          'ro.build.version.release',
          'ro.build.version.sdk',
          'ro.product.cpu.abi',
          'ro.miui.ui.version.name'
        ]) {
          out('$p = ${await sh('getprop $p')}');
        }
        // MIUI sometimes removes the app from profile 0 (TODO.md)
        out(await sh('cmd package install-existing --user 0 $app'));
      case 'integration':
        await run('flutter',
            ['test', 'integration_test/ipfs_test.dart', '-d', serial]);
      case 'network':
        await run('flutter',
            ['test', 'integration_test/network_test.dart', '-d', serial]);
      case 'memory':
        // the app with the node online (the screen starts the node and runs the checks)
        await launch('stop');
        await Future<void>.delayed(const Duration(seconds: 60));
        out(await sh('dumpsys meminfo $app | head -n 30'));
        final pid = await hostPid();
        if (pid.isNotEmpty) {
          out(await sh('dumpsys meminfo $pid | head -n 30'));
        }
      case 'notification':
        // a clean install, without -g: the app asks for the permission (Android 13+)
        await run(adb, ['-s', serial, 'uninstall', app]);
        await run('flutter', [
          'build',
          'apk',
          '--debug',
          '--target-platform',
          await platform(),
          '--dart-define=IPFS_BACKGROUND=foregroundService'
        ]);
        await run(adb, [
          '-s',
          serial,
          'install',
          'build/app/outputs/flutter-apk/app-debug.apk'
        ]);
        await sh('am start -n $app/.MainActivity');
        out('tap "Allow" on the device; 30 s');
        await Future<void>.delayed(const Duration(seconds: 30));
        out(await sh('dumpsys package $app | grep POST_NOTIFICATIONS'));
        out(await sh(
            'dumpsys notification --noredact | grep -A3 $app | head -n 20'));
        out(await sh('dumpsys activity services $app | grep isForeground'));
      case 'fgs':
        await launch('foregroundService');
        await Future<void>.delayed(const Duration(seconds: 20));
        await background(const Duration(minutes: 8));
      case 'stop':
        await launch('stop');
        await Future<void>.delayed(const Duration(seconds: 20));
        await background(const Duration(minutes: 3));
      default:
        out('unknown step: $step');
    }
  }
  out('=== done in ${total.elapsed.inMinutes} min ===');
  await log.close();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
