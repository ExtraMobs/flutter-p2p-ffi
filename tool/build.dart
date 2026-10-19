// Compila em native/ o ipfs_host (o Go de ../go como executável, sem cgo
// menos no Android: o kubo num processo só dele) e a ipfs_shm (shm/ipfs_shm.c, o lado C do canal
// no processo do app), em native/ (linux/amd64 e windows/amd64) e em
// native/android/<abi>/ (x86_64 e arm64-v8a).
// Uso: `dart run tool/build.dart [linux|windows|android]...` (sem argumento,
// linux e windows). Exige Go 1.26.5 (GOTOOLCHAIN=auto baixa) e um compilador C
// só para a ipfs_shm: no Windows, o mingw-w64 no PATH; no linux, gcc e
// x86_64-w64-mingw32-gcc para a DLL; para o Android, o NDK (ANDROID_NDK_HOME,
// ou o mais novo em <Android SDK>/ndk), que também liga o ipfs_host.
import 'dart:io';

/// Alvo → (GOOS, GOARCH, pasta relativa a native/).
const targets = {
  'linux': [('linux', 'amd64', '')],
  'windows': [('windows', 'amd64', '')],
  'android': [
    ('android', 'amd64', 'android/x86_64'),
    ('android', 'arm64', 'android/arm64-v8a'),
  ],
  'android-x64': [('android', 'amd64', 'android/x86_64')],
  'android-arm64': [('android', 'arm64', 'android/arm64-v8a')],
};

/// API mínima do Android para a ipfs_shm (a do app pode ser maior).
const androidApi = 24;

/// Trecho → troca, por arquivo, por módulo. Os módulos vão copiados do cache
/// para .dart_tool/patched_mod/<nome>/, com os trechos trocados, e ligados por
/// `replace` num go.mod gerado (`go build -modfile`; o Go não aceita
/// `-overlay` em arquivos do cache de módulos). Cada trecho tem de existir,
/// senão o build para: dependência atualizada, rever.
typedef Patches = Map<String, Map<String, Map<String, String>>>;

/// Bugs do kubo e do boxo corrigidos em todo build, até o upstream integrar
/// (README, "Correções no upstream"; go/upstream_test.go afirma cada bug no
/// módulo sem patch e falha quando uma versão nova o corrigir).
const upstreamPatches = <String, Map<String, Map<String, String>>>{
  // boxo v0.43.0: append no fim de um arquivo do MFS com os dados embutidos
  // no nó (um add pequeno) deixava a leitura só com o trecho anexado.
  'github.com/ipfs/boxo': {
    'ipld/unixfs/mod/dagmodifier.go': {
      r'''	switch nd := nd.(type) {
	case *mdag.ProtoNode:
		// ProtoNode can be directly passed to trickle.Append
''': r'''	switch nd := nd.(type) {
	case *mdag.ProtoNode:
		// ipfs_ffi (tool/build.dart): a leaf that keeps its file data inline
		// (a small file) would become an internal node in trickle.Append,
		// and readers skip the data of internal nodes: move it into a first
		// leaf, as the RawNode case below does.
		nd, err := dm.inlineDataToLeaf(nd, dagserv)
		if err != nil {
			return nil, err
		}
		// ProtoNode can be directly passed to trickle.Append
''',
      r'''func (dm *DagModifier) appendData(nd ipld.Node, spl chunker.Splitter) (ipld.Node, error) {
''': r'''// inlineDataToLeaf: ipfs_ffi (tool/build.dart), see appendData. A file node
// without links whose data is inline becomes a node with that data as its
// only leaf (raw if RawLeaves), keeping mode and mtime.
func (dm *DagModifier) inlineDataToLeaf(nd *mdag.ProtoNode, dagserv ipld.DAGService) (*mdag.ProtoNode, error) {
	if len(nd.Links()) > 0 {
		return nd, nil
	}
	fsn, err := ft.FSNodeFromBytes(nd.Data())
	if err != nil || len(fsn.Data()) == 0 {
		return nd, nil
	}
	data := fsn.Data()
	var leaf ipld.Node
	if dm.RawLeaves {
		prefix := dm.Prefix
		prefix.Version, prefix.Codec = 1, cid.Raw
		if leaf, err = mdag.NewRawNodeWPrefix(data, prefix); err != nil {
			return nil, err
		}
	} else {
		pn := mdag.NodeWithData(ft.FilePBData(data, uint64(len(data))))
		pn.SetCidBuilder(dm.Prefix)
		leaf = pn
	}
	if err := dagserv.Add(dm.ctx, leaf); err != nil {
		return nil, err
	}
	root := ft.NewFSNode(ft.TFile)
	root.SetMode(fsn.Mode())
	root.SetModTime(fsn.ModTime())
	root.AddBlockSize(uint64(len(data)))
	b, err := root.GetBytes()
	if err != nil {
		return nil, err
	}
	out := mdag.NodeWithData(b)
	out.SetCidBuilder(dm.Prefix)
	if err := out.AddNodeLink("", leaf); err != nil {
		return nil, err
	}
	return out, nil
}

func (dm *DagModifier) appendData(nd ipld.Node, spl chunker.Splitter) (ipld.Node, error) {
''',
    },
  },
  // kubo v0.43.1: com Routing none o keystore do provider ficava aberto
  // depois do close; reabrir o repo no mesmo processo esbarrava na trava.
  'github.com/ipfs/kubo': {
    'core/node/provider.go': {
      r'''		if impl == nil {
			return &NoopProvider{}, nil, nil
		}
''': r'''		if impl == nil {
			// ipfs_ffi (tool/build.dart): no DHT to provide with; the
			// keystore opened above goes unused and nothing closes it (the
			// shutdown hooks skip the NoopProvider), leaving its datastore
			// locked: reopening the repo in the same process fails.
			if err := ks.Close(); err != nil {
				return nil, nil, err
			}
			return &NoopProvider{}, nil, nil
		}
''',
    },
  },
};

/// Android 11+: o `net` do Go lista interfaces por netlink com bind() e
/// RTM_GETLINK, que o sistema nega ao app (golang/go#40569); sem isso o
/// libp2p só anuncia 127.0.0.1/::1 e o mDNS não acha interface. O
/// github.com/wlynxg/anet (já no grafo, pelo pion) faz o mesmo sem eles. Só no
/// build do Android, estes módulos vão com as chamadas trocadas pelo anet.
/// ponytail: só os pontos de endereço local e mDNS; UPnP/NAT-PMP
/// (go-netroute) segue sem rota.
const androidPatches = <String, Map<String, Map<String, String>>>{
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

/// Monta .dart_tool/patched_mod/[name]/ (os módulos de [patches] trocados, e
/// os de [anet] também importando o anet) e devolve o caminho do go.mod para o
/// `-modfile`.
Future<String> patchedModfile(Directory root, String name, Patches patches,
    {Patches anet = const {}}) async {
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

  final dir = Directory('${root.path}/.dart_tool/patched_mod/$name');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final anetVersion = anet.isEmpty
      ? ''
      : await goList('github.com/wlynxg/anet', '{{.Version}}');
  final replaces = StringBuffer(
    '\n// tool/build.dart: módulos com trechos trocados\n',
  );
  for (final MapEntry(key: module, value: files)
      in {...patches, ...anet}.entries) {
    final withAnet = anet.containsKey(module);
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
      // os trechos são escritos com \n; o arquivo do cache também usa \n
      var src = target.readAsStringSync();
      for (final MapEntry(key: a, value: b) in edits.entries) {
        if (!src.contains(a)) {
          throw StateError(
            'patch: o trecho "${a.split('\n').first.trim()}..." não está mais '
            'em $module/$file; reveja os patches em tool/build.dart',
          );
        }
        src = src.replaceAll(a, b);
      }
      if (withAnet) {
        src = src.replaceFirst(
            'import (', 'import (\n\t"github.com/wlynxg/anet"');
      }
      target.writeAsStringSync(src);
    }
    if (withAnet) {
      File('${to.path}/go.mod').writeAsStringSync(
        '\nrequire github.com/wlynxg/anet $anetVersion\n',
        mode: FileMode.append,
      );
    }
    replaces.writeln(
      'replace $module => ../.dart_tool/patched_mod/$name/$module',
    );
  }
  final mod = File('${dir.path}/go.mod')
    ..writeAsStringSync(File('$goDir/go.mod').readAsStringSync() + '$replaces');
  File('$goDir/go.sum').copySync('${dir.path}/go.sum');
  return mod.absolute.path;
}

Future<void> main(List<String> args) async {
  final root = Directory(
    File.fromUri(Platform.script).parent.parent.resolveSymbolicLinksSync(),
  );
  final native = Directory('${root.path}/native')..createSync();
  final noGen = args.contains('--no-gen');
  final targetArgs = args.where((a) => a != '--no-gen').toList();
  // A ponte gerada (zz_generated.go, lib/, API.md) sai de go/gen/roots.txt.
  if (!noGen || !File('${root.path}/go/zz_generated.go').existsSync()) {
    stdout.writeln('go run ./gen');
    final gen = await Process.start(
      'go',
      ['run', './gen'],
      workingDirectory: '${root.path}/go',
      mode: ProcessStartMode.inheritStdio,
    );
    if (await gen.exitCode != 0) exit(1);
  }
  final names = targetArgs.isEmpty ? ['linux', 'windows'] : targetArgs;
  stdout.writeln('go mod download');
  final dl = await Process.start(
    'go',
    ['mod', 'download'],
    workingDirectory: '${root.path}/go',
    mode: ProcessStartMode.inheritStdio,
  );
  if (await dl.exitCode != 0) exit(1);
  final modfile = await patchedModfile(root, 'all', upstreamPatches);
  final androidModfile = names.any((n) => n.startsWith('android'))
      ? await patchedModfile(root, 'android', upstreamPatches,
          anet: androidPatches)
      : null;
  for (final name in names) {
    final builds =
        targets[name] ?? (throw ArgumentError('alvo inválido: $name'));
    for (final (goos, goarch, sub) in builds) {
      // Sem cgo (o Go liga sozinho), menos no Android (abaixo).
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
        // Com cgo nas duas ABIs, ligado pelo clang do NDK, com páginas de
        // 16 KB (Android 15+ e as imagens `16k` do emulador). Sem cgo (o
        // arm64 até o 0.14) o host ficava sem duas coisas, só no aparelho
        // (o emulador x86_64 já tinha cgo, porque o Go não liga
        // android/amd64 sozinho): o resolvedor de DNS do sistema (o Go puro
        // procura /etc/resolv.conf, que o Android não tem, e cai em
        // [::1]:53) e o nível de API do aparelho que o anet lê pelo
        // android_get_device_api_level (sem ele o anet volta ao netlink que
        // o Android 11+ nega: "netlinkrib: permission denied").
        env['CGO_ENABLED'] = '1';
        env['CC'] = cc;
        ldflags += ' -extldflags=-Wl,-z,max-page-size=16384';
      }
      final dir = Directory(sub.isEmpty ? native.path : '${native.path}/$sub')
        ..createSync(recursive: true);
      final goArgs = [
        'build',
        '-trimpath',
        '-ldflags=$ldflags',
        '-modfile=${goos == 'android' ? androidModfile : modfile}',
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
