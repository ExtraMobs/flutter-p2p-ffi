// App de validação do ipfs_ffi no Android: sobe um nó IPFS (kubo via
// dart:ffi) com repo no diretório de dados do app, mostra peer ID e peers,
// adiciona e lê um texto, fecha o nó no background e reabre na volta, e mostra
// o relatório de crash do Go se o processo anterior caiu.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/os.dart' as os;
import 'package:ipfs_ffi/runtime/debug.dart' as debug;

/// Diretório de dados do app (/data/user/0/<pacote>), sem path_provider: o
/// systemTemp do Flutter no Android é o `cache` dentro dele.
String get appDataDir => Directory.systemTemp.parent.path;

/// O switch do daemon.go sobre Routing.Type (como o exemplo 04).
libp2p.RoutingOption routingFor(config.Config cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    'autoclient' => libp2p.constructDefaultRouting(cfg, libp2p.dhtClientOption),
    'dht' => libp2p.dhtOption,
    'dhtclient' => libp2p.dhtClientOption,
    'dhtserver' => libp2p.dhtServerOption,
    'none' => libp2p.nilRouterOption,
    _ => libp2p.constructDefaultRouting(cfg, libp2p.dhtOption),
  };
}

var _pluginsInjected = false;

/// Prepara o processo: lê o relatório de crash anterior, aponta o próximo para
/// [crashLog], injeta os plugins (1x) e cria o repo se preciso. Devolve o
/// relatório anterior, se houver.
String? prepare(String repoPath, String crashLog) {
  final f = File(crashLog);
  final previous =
      f.existsSync() && f.lengthSync() > 0 ? f.readAsStringSync() : null;
  final out = os.create(crashLog); // trunca: o anterior já foi lido
  debug.setCrashOutput(out, debug.CrashOptions());
  out.close();
  if (!_pluginsInjected) {
    loader.PluginLoader('')
      ..initialize()
      ..inject();
    _pluginsInjected = true;
  }
  if (!fsrepo.isInitialized(repoPath)) {
    final cfg = config
        .initWithIdentity(config.createIdentity([options.key.type('ed25519')]));
    for (final p in ['randomports', 'lowpower']) {
      config.profiles[p]!.transform(cfg);
    }
    fsrepo.init(repoPath, cfg);
  }
  return previous;
}

/// Sobe o nó online sobre [repoPath], com pubsub ligado.
Future<core.IpfsNode> startNode(context.Context ctx, String repoPath) {
  final repo = fsrepo.open(repoPath);
  return core.newNode(
      ctx,
      node.BuildCfg(
          repo: repo,
          online: true,
          routing: routingFor(repo.config()),
          extraOpts: {'pubsub': true}));
}

void main() => runApp(const MaterialApp(home: NodePage()));

class NodePage extends StatefulWidget {
  const NodePage({super.key});

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  final ctx = context.background();
  late final String repoPath = '$appDataDir/ipfs';
  late final AppLifecycleListener _life;
  Future<void> _busy = Future.value(); // start/stop em série
  core.IpfsNode? _node;
  iface.CoreApi? _api;
  Timer? _tick;
  String _status = 'iniciando...';
  String _peerId = '';
  int _peers = 0;
  int _cycles = 0;
  String _last = '';
  String? _crash;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onPause: () => _serial(_stop),
      onResume: () => _serial(_start),
    );
    _serial(() async {
      _crash = prepare(repoPath, '$appDataDir/crash.log');
      await _start();
    });
  }

  @override
  void dispose() {
    _life.dispose();
    _serial(_stop);
    super.dispose();
  }

  void _serial(Future<void> Function() f) {
    _busy = _busy.then((_) => f()).catchError((Object e) {
      if (mounted) setState(() => _status = 'erro: $e');
    });
  }

  Future<void> _start() async {
    if (_node != null) return;
    setState(() => _status = 'subindo o nó...');
    final n = await startNode(ctx, repoPath);
    final api = coreapi.newCoreApi(n);
    _node = n;
    _api = api;
    _peerId = (await api.key().self(ctx)).id.toString();
    _cycles++;
    _tick = Timer.periodic(const Duration(seconds: 3), (_) async {
      final peers = await api.swarm().peers(ctx);
      if (mounted) setState(() => _peers = peers.length);
    });
    setState(() => _status = 'online');
  }

  Future<void> _stop() async {
    _tick?.cancel();
    final n = _node;
    _node = null;
    _api = null;
    if (n == null) return;
    if (mounted) setState(() => _status = 'fechando (background)...');
    await n.close();
    if (mounted) setState(() => _status = 'fechado');
  }

  Future<void> _addGet() async {
    final api = _api;
    if (api == null) return;
    final text = 'olá do Android ${DateTime.now()}';
    final p = await api.unixfs().add(ctx, files.newBytesFile(utf8.encode(text)),
        [options.unixfs.pin(true, '')]);
    final back =
        utf8.decode(io.readAll(files.toFile(await api.unixfs().get(ctx, p))));
    setState(() => _last = '$p\n$back');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ipfs_ffi')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('estado: $_status (subidas: $_cycles)',
              key: const Key('status')),
          SelectableText('peer: $_peerId'),
          Text('peers conectados: $_peers', key: const Key('peers')),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _api == null ? null : _addGet,
              child: const Text('add + get')),
          SelectableText(_last, key: const Key('last')),
          if (_crash != null) ...[
            const SizedBox(height: 12),
            const Text('o processo anterior caiu (relatório do Go):'),
            SelectableText(_crash!, style: const TextStyle(fontSize: 10)),
          ],
        ]),
      );
}
