// Compila em native/ o ipfs_host (o Go de ../go como executável, sem cgo
// menos no android/amd64: o kubo num processo só dele) e a ipfs_shm (shm/ipfs_shm.c, o lado C do canal
// no processo do app), em native/ (linux/amd64 e windows/amd64) e em
// native/android/<abi>/ (x86_64 e arm64-v8a).
// Uso: `dart run tool/build.dart [linux|windows|android]...` (sem argumento,
// linux e windows). Exige Go 1.26.5 (GOTOOLCHAIN=auto baixa) e um compilador C
// só para a ipfs_shm: no Windows, o mingw-w64 no PATH; no linux, gcc e
// x86_64-w64-mingw32-gcc para a DLL; para o Android, o NDK (ANDROID_NDK_HOME,
// ou o mais novo em <Android SDK>/ndk), que também liga o ipfs_host x86_64.
import 'dart:io';

/// Alvo → (GOOS, GOARCH, pasta relativa a native/).
const targets = {
  'linux': [('linux', 'amd64', '')],
  'windows': [('windows', 'amd64', '')],
  'android': [
    ('android', 'amd64', 'android/x86_64'),
    ('android', 'arm64', 'android/arm64-v8a'),
  ],
};

/// API mínima do Android para a ipfs_shm (a do app pode ser maior).
const androidApi = 24;

/// Android 11+: o `net` do Go lista interfaces por netlink com bind() e
/// RTM_GETLINK, que o sistema nega ao app (golang/go#40569); sem isso o
/// libp2p só anuncia 127.0.0.1/::1 e o mDNS não acha interface. O
/// github.com/wlynxg/anet (já no grafo, pelo pion) faz o mesmo sem eles. Só no
/// build do Android, estes módulos vão com as chamadas trocadas pelo anet:
/// copiados do cache para .dart_tool/android_mod/ e ligados por `replace` num
/// go.mod gerado (`go build -modfile`; o Go não aceita `-overlay` em arquivos
/// do cache de módulos). Cada trecho tem de existir, senão o build para
/// (dependência atualizada: rever).
/// ponytail: só os pontos de endereço local e mDNS; UPnP/NAT-PMP
/// (go-netroute) segue sem rota.
const androidPatches = {
  'github.com/multiformats/go-multiaddr': {
    'net/net.go': {'net.InterfaceAddrs()': 'anet.InterfaceAddrs()'},
  },
  'github.com/libp2p/zeroconf/v2': {
    'connection.go': {'net.Interfaces()': 'anet.Interfaces()'},
    'server.go': {
      'net.InterfaceByIndex(': 'anet.InterfaceByIndex(',
      'iface.Addrs()': 'anet.InterfaceAddrsByInterface(iface)',
    },
  },
};

/// Monta .dart_tool/android_mod/ (módulos trocados + android.mod/.sum) e
/// devolve o caminho do android.mod para o `-modfile`.
Future<String> androidModfile(Directory root) async {
  final goDir = '${root.path}/go';
  Future<String> goList(String module, String field) async {
    final r = await Process.run(
        'go',
        [
          'list',
          '-m',
          '-f',
          field,
          module,
        ],
        workingDirectory: goDir);
    if (r.exitCode != 0) throw StateError('go list -m $module: ${r.stderr}');
    return (r.stdout as String).trim();
  }

  final dir = Directory('${root.path}/.dart_tool/android_mod');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final anet = await goList('github.com/wlynxg/anet', '{{.Version}}');
  final replaces = StringBuffer(
    '\n// tool/build.dart: módulos trocados pelo anet\n',
  );
  for (final MapEntry(key: module, value: files) in androidPatches.entries) {
    final from = Directory(await goList(module, '{{.Dir}}'));
    final to = Directory('${dir.path}/$module');
    for (final f in from.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(from.path.length + 1);
      File('${to.path}/$rel')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(f.readAsBytesSync());
    }
    for (final MapEntry(key: file, value: edits) in files.entries) {
      final target = File('${to.path}/$file');
      var src = target.readAsStringSync();
      for (final MapEntry(key: a, value: b) in edits.entries) {
        if (!src.contains(a)) {
          throw StateError(
            'patch do Android: "$a" não está mais em '
            '$module/$file; reveja androidPatches em tool/build.dart',
          );
        }
        src = src.replaceAll(a, b);
      }
      target.writeAsStringSync(
        src.replaceFirst('import (', 'import (\n\t"github.com/wlynxg/anet"'),
      );
    }
    File('${to.path}/go.mod').writeAsStringSync(
      '\nrequire github.com/wlynxg/anet $anet\n',
      mode: FileMode.append,
    );
    replaces.writeln(
      'replace $module => ${to.absolute.path.replaceAll(r'\', '/')}',
    );
  }
  final mod = File('${dir.path}/android.mod')
    ..writeAsStringSync(File('$goDir/go.mod').readAsStringSync() + '$replaces');
  File('$goDir/go.sum').copySync('${dir.path}/android.sum');
  return mod.absolute.path;
}

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final native = Directory('${root.path}/native')..createSync();
  // A ponte gerada (zz_generated.go, lib/, API.md) sai de go/gen/roots.txt.
  stdout.writeln('go run ./gen');
  final gen = await Process.start(
    'go',
    ['run', './gen'],
    workingDirectory: '${root.path}/go',
    mode: ProcessStartMode.inheritStdio,
  );
  if (await gen.exitCode != 0) exit(1);
  final names = args.isEmpty ? ['linux', 'windows'] : args;
  final modfile = names.contains('android') ? await androidModfile(root) : null;
  for (final name in names) {
    final builds =
        targets[name] ?? (throw ArgumentError('alvo inválido: $name'));
    for (final (goos, goarch, sub) in builds) {
      // Sem cgo (o Go liga sozinho), menos no android/amd64 (abaixo).
      final env = {'CGO_ENABLED': '0', 'GOOS': goos, 'GOARCH': goarch};
      var ldflags = '-s';
      String? cc;
      if (goos == 'windows' && !Platform.isWindows) {
        cc = 'x86_64-w64-mingw32-gcc'; // a ipfs_shm.dll fora do Windows
      }
      if (goos == 'android') {
        cc = ndkClang(goarch);
        // -checklinkname=0: o github.com/wlynxg/anet (interfaces de rede do
        // go-libp2p no Android 11+) usa linkname em net.zoneCache, que o Go
        // 1.23+ bloqueia por padrão; é a solução documentada pelo anet.
        ldflags = '-s -checklinkname=0';
        if (goarch == 'amd64') {
          // O Go não liga android/amd64 sozinho ("requires external (cgo)
          // linking"): o clang do NDK liga, com páginas de 16 KB (Android 15+
          // e as imagens `16k` do emulador). Nenhum pacote importa "C"; o
          // cgo só traz o linker externo.
          env['CGO_ENABLED'] = '1';
          env['CC'] = cc;
          ldflags += ' -extldflags=-Wl,-z,max-page-size=16384';
        }
        // arm64: linker interno, segmentos PT_LOAD alinhados em 64 KB
        // (readelf -lW: Align 0x10000), o que já serve às páginas de 16 KB.
      }
      final dir = Directory(sub.isEmpty ? native.path : '${native.path}/$sub')
        ..createSync(recursive: true);
      final goArgs = [
        'build',
        '-trimpath',
        '-ldflags=$ldflags',
        if (goos == 'android') '-modfile=$modfile',
      ];
      // No Android o executável leva nome de lib para o APK empacotá-lo.
      final host = '${dir.path}/${switch (goos) {
        'windows' => 'ipfs_host.exe',
        'android' => 'libipfs_host.so',
        _ => 'ipfs_host',
      }}';
      stdout.writeln('go build ($goos/$goarch) -> $host');
      await run('go', [...goArgs, '-o', host, '.'], '${root.path}/go', env);
      final shm =
          '${dir.path}/${goos == 'windows' ? 'ipfs_shm.dll' : 'libipfs_shm.so'}';
      final ccArgs = (cc ?? 'gcc').split(' ');
      stdout.writeln('${ccArgs.first} -> $shm');
      await run(
        ccArgs.first,
        [
          ...ccArgs.skip(1),
          '-std=c11',
          '-O2',
          '-Wall',
          '-shared',
          if (goos != 'windows') ...['-fPIC', '-pthread', '-D_GNU_SOURCE'],
          if (goos == 'android') '-Wl,-z,max-page-size=16384',
          '-o',
          shm,
          'shm/ipfs_shm.c',
        ],
        root.path,
        const {},
      );
    }
  }
}

/// Roda [exe] e para o build se falhar.
Future<void> run(
  String exe,
  List<String> args,
  String dir,
  Map<String, String> env,
) async {
  final p = await Process.start(
    exe,
    args,
    workingDirectory: dir,
    environment: env,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await p.exitCode != 0) exit(1);
}

/// O clang do NDK para [goarch], com o alvo Android na linha (para a ipfs_shm).
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
        int.tryParse(
          d.uri.pathSegments.where((s) => s.isNotEmpty).last.split('.').first,
        ) ??
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
