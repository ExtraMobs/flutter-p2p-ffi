// Compila o Go de ../go em native/: libipfs.so (linux/amd64) e ipfs.dll
// (windows/amd64). Uso: `dart run tool/build.dart [linux|windows]...`
// (sem argumento, os dois). Exige Go 1.26.5 (GOTOOLCHAIN=auto baixa) e, fora
// do Windows, x86_64-w64-mingw32-gcc para a DLL.
import 'dart:io';

const targets = {'linux': 'libipfs.so', 'windows': 'ipfs.dll'};

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final native = Directory('${root.path}/native')..createSync();
  for (final os in args.isEmpty ? targets.keys : args) {
    final lib = targets[os] ?? (throw ArgumentError('alvo inválido: $os'));
    final env = {'CGO_ENABLED': '1', 'GOOS': os, 'GOARCH': 'amd64'};
    // Compilando a DLL fora do Windows, o cgo precisa do cross-compiler.
    if (os == 'windows' && !Platform.isWindows) {
      env['CC'] = 'x86_64-w64-mingw32-gcc';
    }
    final out = '${native.path}/$lib';
    stdout.writeln('go build -> $out');
    final p = await Process.start(
      'go',
      [
        'build',
        '-trimpath',
        '-ldflags=-s',
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
