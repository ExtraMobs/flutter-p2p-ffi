// Compila o Go de ../go em native/: libipfs.so (linux/amd64), ipfs.dll
// (windows/amd64) e native/android/<abi>/libipfs.so (x86_64 e arm64-v8a).
// Uso: `dart run tool/build.dart [linux|windows|android]...` (sem argumento,
// linux e windows). Exige Go 1.26.5 (GOTOOLCHAIN=auto baixa) e um compilador C
// para o cgo: no Windows, o mingw-w64 no PATH; no linux, x86_64-w64-mingw32-gcc
// para a DLL; para o Android, o NDK (ANDROID_NDK_HOME, ou o mais novo em
// <Android SDK>/ndk).
import 'dart:io';

/// Alvo → (GOOS, GOARCH, saída relativa a native/).
const targets = {
  'linux': [('linux', 'amd64', 'libipfs.so')],
  'windows': [('windows', 'amd64', 'ipfs.dll')],
  'android': [
    ('android', 'amd64', 'android/x86_64/libipfs.so'),
    ('android', 'arm64', 'android/arm64-v8a/libipfs.so'),
  ],
};

/// API mínima do Android para a lib (a do app pode ser maior).
const androidApi = 24;

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final native = Directory('${root.path}/native')..createSync();
  // A ponte gerada (zz_generated.go, lib/, API.md) sai de go/gen/roots.txt.
  stdout.writeln('go run ./gen');
  final gen = await Process.start('go', ['run', './gen'],
      workingDirectory: '${root.path}/go', mode: ProcessStartMode.inheritStdio);
  if (await gen.exitCode != 0) exit(1);
  for (final name in args.isEmpty ? ['linux', 'windows'] : args) {
    final builds =
        targets[name] ?? (throw ArgumentError('alvo inválido: $name'));
    for (final (goos, goarch, lib) in builds) {
      final env = {'CGO_ENABLED': '1', 'GOOS': goos, 'GOARCH': goarch};
      var ldflags = '-s';
      if (goos == 'windows' && !Platform.isWindows) {
        // Compilando a DLL fora do Windows, o cgo precisa do cross-compiler.
        env['CC'] = 'x86_64-w64-mingw32-gcc';
      }
      if (goos == 'android') {
        env['CC'] = ndkClang(goarch);
        // Páginas de 16 KB (Android 15+ e as imagens `16k` do emulador).
        // -checklinkname=0: o github.com/wlynxg/anet (interfaces de rede do
        // go-libp2p no Android 11+) usa linkname em net.zoneCache, que o Go
        // 1.23+ bloqueia por padrão; é a solução documentada pelo anet.
        ldflags = '-s -checklinkname=0 -extldflags=-Wl,-z,max-page-size=16384';
      }
      final out = '${native.path}/$lib';
      File(out).parent.createSync(recursive: true);
      stdout.writeln('go build ($goos/$goarch) -> $out');
      final p = await Process.start(
        'go',
        [
          'build',
          '-trimpath',
          '-ldflags=$ldflags',
          '-buildmode=c-shared',
          '-o',
          out,
          '.'
        ],
        workingDirectory: '${root.path}/go',
        environment: env,
        mode: ProcessStartMode.inheritStdio,
      );
      if (await p.exitCode != 0) exit(1);
      File(out.replaceFirst(RegExp(r'\.[^.]+$'), '.h')).deleteSync();
    }
  }
}

/// O clang do NDK para [goarch], com o alvo Android na linha (`CC` do cgo).
String ndkClang(String goarch) {
  final env = Platform.environment;
  var ndk = env['ANDROID_NDK_HOME'];
  if (ndk == null) {
    final sdk = env['ANDROID_HOME'] ??
        env['ANDROID_SDK_ROOT'] ??
        (Platform.isWindows
            ? '${env['LOCALAPPDATA']}\\Android\\Sdk'
            : '${env['HOME']}/Android/Sdk');
    final dirs = Directory('$sdk/ndk').existsSync()
        ? Directory('$sdk/ndk').listSync().whereType<Directory>().toList()
        : <Directory>[];
    if (dirs.isEmpty) {
      throw StateError('NDK não encontrado: defina ANDROID_NDK_HOME');
    }
    int major(Directory d) =>
        int.tryParse(d.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .split('.')
            .first) ??
        0;
    dirs.sort((a, b) => major(a).compareTo(major(b)));
    ndk = dirs.last.path;
  }
  final host = Platform.isWindows ? 'windows-x86_64' : 'linux-x86_64';
  final clang =
      '$ndk/toolchains/llvm/prebuilt/$host/bin/clang${Platform.isWindows ? '.exe' : ''}';
  final arch = goarch == 'arm64' ? 'aarch64' : 'x86_64';
  return '$clang --target=$arch-linux-android$androidApi';
}
