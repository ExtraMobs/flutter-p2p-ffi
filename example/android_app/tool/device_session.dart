// A sessão no aparelho real, com tempo contado (o cabo fica ~1 h): roda os
// passos em ordem e grava tudo num log. Uso (na pasta example/android_app):
//   dart run tool/device_session.dart <serial> [passo...] [--log=arquivo]
// Passos (sem nenhum: todos, nesta ordem): info integracao rede memoria
// notificacao fgs stop. Exige adb no PATH ou em <Android SDK>/platform-tools,
// flutter no PATH e os binários de `dart run tool/build.dart android`.
// O log tem dados do aparelho: não versionar (o resumo vai para o TODO.md sem
// modelo, serial nem IPs).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const app = 'dev.extramobs.ipfs_ffi_android';
const host = 'libipfs_host.so';
const steps = [
  'info',
  'integracao',
  'rede',
  'memoria',
  'notificacao',
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

/// Roda e espelha a saída no log; devolve o código de saída.
Future<int> run(String exe, List<String> args) async {
  out('\$ $exe ${args.join(' ')}');
  final p = await Process.start(exe, args, runInShell: Platform.isWindows);
  await Future.wait([
    for (final s in [p.stdout, p.stderr])
      s.transform(utf8.decoder).transform(const LineSplitter()).forEach(out)
  ]);
  final code = await p.exitCode;
  out('código de saída: $code');
  return code;
}

Future<String> hostPid() => sh('pidof $host');

/// O --target-platform do aparelho: arm64 num celular, x64 no emulador.
Future<String> platform() async =>
    (await sh('getprop ro.product.cpu.abi')) == 'x86_64'
        ? 'android-x64'
        : 'android-arm64';

/// Instala o app com o modo de segundo plano [mode] e o abre.
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
    '-g', // -g dá as permissões de execução, menos no passo de notificação
    'build/app/outputs/flutter-apk/app-debug.apk'
  ]);
  await sh('am start -n $app/.MainActivity');
}

/// Acompanha o host por [d] com o app no segundo plano (HOME).
Future<void> background(Duration d) async {
  await sh('input keyevent KEYCODE_HOME');
  final sw = Stopwatch()..start();
  while (sw.elapsed < d) {
    out('${sw.elapsed.inSeconds} s no segundo plano: host pid '
        '"${await hostPid()}", app pid "${await sh('pidof $app')}"');
    await Future<void>.delayed(const Duration(seconds: 30));
  }
  await sh('am start -n $app/.MainActivity');
  await Future<void>.delayed(const Duration(seconds: 5));
  out('de volta: host pid "${await hostPid()}"');
  out((await sh('logcat -d -s flutter | tail -n 40')));
}

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.isEmpty) {
    stderr
        .writeln('uso: dart run tool/device_session.dart <serial> [passo...]');
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
    out('=== $step (sessão em ${total.elapsed.inMinutes} min) ===');
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
        // o MIUI às vezes tira o app do perfil 0 (TODO.md)
        out(await sh('cmd package install-existing --user 0 $app'));
      case 'integracao':
        await run('flutter',
            ['test', 'integration_test/ipfs_test.dart', '-d', serial]);
      case 'rede':
        await run('flutter',
            ['test', 'integration_test/network_test.dart', '-d', serial]);
      case 'memoria':
        // o app com o nó online (a tela sobe o nó e roda as verificações)
        await launch('stop');
        await Future<void>.delayed(const Duration(seconds: 60));
        out(await sh('dumpsys meminfo $app | head -n 30'));
        final pid = await hostPid();
        if (pid.isNotEmpty) {
          out(await sh('dumpsys meminfo $pid | head -n 30'));
        }
      case 'notificacao':
        // instalação limpa, sem -g: o app pede a permissão (Android 13+)
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
        out('toque em "Permitir" no aparelho; 30 s');
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
        out('passo desconhecido: $step');
    }
  }
  out('=== fim em ${total.elapsed.inMinutes} min ===');
  await log.close();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
