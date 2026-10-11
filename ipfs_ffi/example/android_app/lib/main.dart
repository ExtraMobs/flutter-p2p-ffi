// App de validação do ipfs_ffi no Android: sobe um nó IPFS (kubo via
// dart:ffi) com repo no diretório de dados do app, mostra peer ID e peers,
// fecha o nó no background e reabre na volta, roda as verificações
// (lib/checks.dart) e junta tudo num log que se copia com um toque. Mostra o
// relatório de crash do Go se o processo anterior caiu.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipfs_ffi/context.dart' as gocontext;
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
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;

import 'checks.dart';

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
    // O Android não tem /etc/resolv.conf: o resolvedor do Go cai em [::1]:53
    // e DNSLink e /dnsaddr falham. DNS por HTTPS (DNS.Resolvers do kubo).
    cfg.json['DNS'] = {
      ...?cfg.json['DNS'] as Map<String, Object?>?,
      'Resolvers': {'.': 'https://cloudflare-dns.com/dns-query'},
    };
    fsrepo.init(repoPath, cfg);
  }
  return previous;
}

/// Sobe o nó online sobre [repoPath], com pubsub ligado.
Future<core.IpfsNode> startNode(gocontext.Context ctx, String repoPath) {
  final repo = fsrepo.open(repoPath);
  return core.newNode(
      ctx,
      node.BuildCfg(
          repo: repo,
          online: true,
          routing: routingFor(repo.config()),
          extraOpts: {'pubsub': true}));
}

/// O log do app: tudo que a tela, as verificações e os erros não tratados
/// escrevem, com hora; é o que o botão "copiar" leva. Cada linha vai também
/// para o logcat (tag `flutter`).
final logText = ValueNotifier('');

void log(String line) {
  final t = DateTime.now().toIso8601String().substring(11, 23);
  logText.value += '$t $line\n';
  Zone.root.print('$t $line');
}

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError =
        (d) => log('erro do Flutter: ${d.exceptionAsString()}\n${d.stack}');
    runApp(const MaterialApp(home: NodePage()));
  }, (e, st) => log('erro não tratado: $e\n$st'),
      zoneSpecification:
          ZoneSpecification(print: (self, parent, zone, line) => log(line)));
}

/// Bateria em % pelo sysfs (nem todo aparelho deixa ler).
String battery() {
  try {
    return '${File('/sys/class/power_supply/battery/capacity').readAsStringSync().trim()}%';
  } catch (_) {
    return 'indisponível';
  }
}

class NodePage extends StatefulWidget {
  const NodePage({super.key});

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  final ctx = gocontext.background();
  late final String repoPath = '$appDataDir/ipfs';
  late final AppLifecycleListener _life;
  Future<void> _busy = Future.value(); // start/stop/verificações em série
  core.IpfsNode? _node;
  iface.CoreApi? _api;
  Timer? _tick;
  final _logView = TextEditingController();
  final _logScroll = ScrollController();
  String _status = 'iniciando...';
  String _peerId = '';
  int _peers = 0;
  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    logText.addListener(_syncLog);
    _life = AppLifecycleListener(
      onPause: () => _serial(_stop),
      onResume: () => _serial(_start),
    );
    _serial(() async {
      log('app: ${Platform.operatingSystemVersion}; Dart ${Platform.version}');
      log('cpus: ${Platform.numberOfProcessors}; bateria: ${battery()}');
      final crash = prepare(repoPath, '$appDataDir/crash.log');
      if (crash != null)
        log('O PROCESSO ANTERIOR CAIU (relatório do Go):\n$crash');
      await _start();
      await _checks();
    });
  }

  @override
  void dispose() {
    logText.removeListener(_syncLog);
    _life.dispose();
    _serial(_stop);
    super.dispose();
  }

  void _syncLog() {
    _logView.text = logText.value;
    // acompanha o fim do log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  void _serial(Future<void> Function() f) {
    _busy = _busy.then((_) => f()).catchError((Object e, StackTrace st) {
      log('erro: $e\n$st');
      if (mounted) setState(() => _status = 'erro: $e');
    });
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _start() async {
    if (_node != null) return;
    _set(() => _status = 'subindo o nó...');
    final sw = Stopwatch()..start();
    final n = await startNode(ctx, repoPath);
    final api = coreapi.newCoreApi(n);
    _node = n;
    _api = api;
    _peerId = (await api.key().self(ctx)).id.toString();
    _cycles++;
    log('nó online em ${sw.elapsedMilliseconds} ms (subida $_cycles): $_peerId');
    _tick = Timer.periodic(const Duration(seconds: 3), (_) async {
      final peers = await api.swarm().peers(ctx);
      _set(() => _peers = peers.length);
    });
    _set(() => _status = 'online');
  }

  Future<void> _stop() async {
    _tick?.cancel();
    final n = _node;
    _node = null;
    _api = null;
    if (n == null) return;
    _set(() => _status = 'fechando (background)...');
    log('fechando o nó (app em background); peers: $_peers');
    await n.close();
    log('nó fechado');
    _set(() => _status = 'fechado');
  }

  /// As verificações, uma vez ao abrir o app, com o nó recém-online.
  Future<void> _checks() async {
    log('=== verificações (bateria ${battery()}) ===');
    _set(() => _status = 'online, rodando os testes...');
    var failed = await networkChecks(_api!, log);
    failed += await localChecks(log);
    log('=== fim: ${failed == 0 ? 'tudo passou' : '$failed falharam'} '
        '(bateria ${battery()}) ===');
    _set(() => _status = 'online, testes concluídos');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: logText.value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('log copiado')));
    }
  }

  Future<void> _crash() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              content: const Text(
                  'Derruba o app com um panic numa goroutine do Go. Abra o app de novo: o relatório aparece no log.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('derrubar')),
              ],
            ));
    if (ok ?? false) {
      log('derrubando o processo de propósito...');
      $callSync('ipfs_ffi/test.PanicInGoroutine', const []);
      await Isolate.current.pause(); // o panic chega antes
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ipfs_ffi'), actions: [
          IconButton(
              tooltip: 'derrubar (teste de crash)',
              onPressed: _crash,
              icon: const Icon(Icons.dangerous_outlined)),
        ]),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('estado: $_status (subidas: $_cycles) · peers: $_peers',
                key: const Key('status')),
            SelectableText('peer: $_peerId', maxLines: 1),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: FilledButton.tonal(
                      onPressed: _copy, child: const Text('copiar log'))),
              IconButton(
                  tooltip: 'limpar',
                  onPressed: () => logText.value = '',
                  icon: const Icon(Icons.delete_outline)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _logView,
                scrollController: _logScroll,
                readOnly: true,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ]),
        ),
      );
}
