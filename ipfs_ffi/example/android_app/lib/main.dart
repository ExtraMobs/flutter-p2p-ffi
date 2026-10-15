// App de validação do ipfs_ffi no Android: sobe o serviço (o kubo no
// ipfs_host, a libipfs_host.so do APK, noutro processo) e um nó IPFS com repo
// no diretório de dados do app, mostra peer ID e peers, fecha o nó no
// background e reabre na volta, roda as verificações (lib/checks.dart) e junta
// tudo num log que se copia com um toque. Na primeira vez derruba o ipfs_host
// com um panic do Go: o app segue, mostra o relatório e relança o serviço.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipfs_ffi/context.dart' as gocontext;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
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

/// Prepara o serviço: lê o relatório de crash do ipfs_host anterior, lança um
/// novo (o Go grava o relatório de um panic em [crashLog]), injeta os plugins
/// (1x por processo do serviço) e cria o repo se preciso. Devolve o relatório
/// anterior, se houver.
Future<String?> prepare(String repoPath, String crashLog) async {
  final f = File(crashLog);
  final previous =
      f.existsSync() && f.lengthSync() > 0 ? f.readAsStringSync() : null;
  if (previous != null) f.writeAsStringSync(''); // já foi lido
  await IpfsService.start(crashLog: crashLog);
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  if (!fsrepo.isInitialized(repoPath)) {
    final cfg = config
        .initWithIdentity(config.createIdentity([options.key.type('ed25519')]));
    final defaults = ((cfg.json['Addresses'] as Map)['Swarm'] as List)
        .cast<String>()
        .toList();
    for (final p in ['randomports', 'lowpower']) {
      config.profiles[p]!.transform(cfg);
    }
    // O randomports troca a lista padrão por só TCP; sem UDP não há QUIC nem
    // hole punching (DCUtR). Volta a lista padrão do kubo (TCP, QUIC,
    // WebTransport, WebRTC) na porta que ele sorteou. O transform troca o
    // JSON inteiro: o mapa Addresses é lido depois dele.
    final addresses = cfg.json['Addresses'] as Map<String, Object?>;
    final port = RegExp(r'/tcp/(\d+)')
        .firstMatch((addresses['Swarm'] as List).first as String)![1]!;
    addresses['Swarm'] = [
      for (final a in defaults) a.replaceAll('/4001', '/$port')
    ];
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
  /// Um contexto do serviço atual (os handles de um ipfs_host anterior não
  /// valem depois de relançado).
  gocontext.Context get ctx => gocontext.background();
  late final String _crashLog = '$appDataDir/crash.log';
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
      final crash = await prepare(repoPath, _crashLog);
      if (crash != null) {
        log('O IPFS_HOST ANTERIOR CAIU (relatório do Go):\n$crash');
      }
      await _start();
      await _checks();
      // teste de crash automático, uma vez por instalação
      final done = File('$appDataDir/crash-testado');
      if (!done.existsSync()) {
        done.writeAsStringSync('');
        await _crashNow();
      }
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
    if (_node != null && IpfsService.isRunning) return;
    if (!IpfsService.isRunning) {
      // o ipfs_host caiu sozinho (panic do kubo): relança o serviço
      _tick?.cancel();
      _node = null;
      _api = null;
      final crash = await prepare(repoPath, _crashLog);
      log('o ipfs_host tinha caído; relançado. Relatório do Go:\n'
          '${crash ?? '(nenhum)'}');
    }
    _set(() => _status = 'subindo o nó...');
    final sw = Stopwatch()..start();
    final n = await startNode(ctx, repoPath);
    final api = coreapi.newCoreApi(n);
    _node = n;
    _api = api;
    _peerId = (await api.key().self(ctx)).id.toString();
    _cycles++;
    _online
      ..reset()
      ..start();
    log('nó online em ${sw.elapsedMilliseconds} ms (subida $_cycles): $_peerId');
    _tick = Timer.periodic(const Duration(seconds: 3), (_) async {
      final peers = await api.swarm().peers(ctx);
      _set(() => _peers = peers.length);
    });
    _set(() => _status = 'online');
  }

  /// Há quanto tempo o nó está online (zerado a cada subida).
  final _online = Stopwatch();

  Future<void> _stop() async {
    _tick?.cancel();
    final n = _node;
    _node = null;
    _api = null;
    if (n == null || !IpfsService.isRunning) return;
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
    _set(() => _status = 'online, esperando para medir a alcançabilidade...');
    failed += await reachabilityChecks(_api!, _online, log);
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
                  'Derruba o ipfs_host com um panic numa goroutine do Go. O app segue, mostra o relatório no log e relança o serviço.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('derrubar')),
              ],
            ));
    if (ok ?? false) _serial(_crashNow);
  }

  /// Panic numa goroutine solta do Go (função de teste 24 do WIRE.md): só o
  /// ipfs_host cai; o app segue, lê o relatório do Go e relança o serviço e o nó.
  Future<void> _crashNow() async {
    log('derrubando o ipfs_host de propósito (panic numa goroutine do Go)');
    _tick?.cancel();
    _node = null;
    _api = null;
    final exit = IpfsService.exitCode!;
    $callSync(24); // responde e cai logo depois
    log('o ipfs_host saiu (código ${await exit}); o app seguiu');
    final crash = await prepare(repoPath, _crashLog);
    log('relatório do Go:\n${crash ?? '(nenhum)'}');
    await _start();
    log('serviço e nó relançados');
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
