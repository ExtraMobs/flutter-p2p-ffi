// The p2p_ffi validation app on Android: starts the service (kubo in the
// p2p_host, the APK's libp2p_host.so, in another process) and an IPFS node with
// its repo in the app's data directory, shows the peer ID and peers, runs the
// checks (lib/checks.dart) and gathers everything in a log copied with one tap.
// In the background (P2pService.background, through
// --dart-define=P2P_BACKGROUND): `stop` (default), the p2p_ffi_flutter plugin
// stops the service and the app starts it again on return; `foregroundService`,
// the node stays online with a notification. The first time it brings the
// p2p_host down with a Go panic: the app goes on and its onStop shows the
// report, clears the log, restarts the service (P2pService.restart) and reopens
// the node.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:p2p_ffi_flutter/p2p_ffi_flutter.dart';
import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:p2p_ffi/src/runtime.dart' show $callSync;

import 'checks.dart';

/// The app's data directory (/data/user/0/<package>), without path_provider:
/// Flutter's systemTemp on Android is the `cache` inside it.
String get appDataDir => Directory.systemTemp.parent.path;

/// daemon.go's switch over Routing.Type (like example 04).
KuboCoreNodeLibp2pRoutingOption routingFor(KuboConfig cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    'autoclient' => Go.kubo.core.node.libp2p
        .constructDefaultRouting(cfg, Go.kubo.core.node.libp2p.dhtClientOption),
    'dht' => Go.kubo.core.node.libp2p.dhtOption,
    'dhtclient' => Go.kubo.core.node.libp2p.dhtClientOption,
    'dhtserver' => Go.kubo.core.node.libp2p.dhtServerOption,
    'none' => Go.kubo.core.node.libp2p.nilRouterOption,
    _ => Go.kubo.core.node.libp2p
        .constructDefaultRouting(cfg, Go.kubo.core.node.libp2p.dhtOption),
  };
}

/// Prepares the service: reads the crash report of a previous run of the app,
/// launches the p2p_host (Go writes a panic's report to [crashLog]; a stop
/// arrives at [onStop]) and sets the service up ([setupService]). Returns the
/// previous report, if any.
Future<String?> prepare(String repoPath, String crashLog,
    {P2pStopHandler? onStop}) async {
  final f = File(crashLog);
  final previous =
      f.existsSync() && f.lengthSync() > 0 ? f.readAsStringSync() : null;
  if (previous != null) f.writeAsStringSync(''); // already read
  await P2pService.start(crashLog: crashLog, onStop: onStop);
  setupService(repoPath);
  return previous;
}

/// What each service process needs before the node: injects the plugins (once
/// per p2p_host; again after a restart) and creates the repo if needed.
void setupService(String repoPath) {
  KuboPluginLoader('')
    ..initialize()
    ..inject();
  if (!Go.kubo.repo.fsrepo.isInitialized(repoPath)) {
    final cfg = Go.kubo.config.initWithIdentity(Go.kubo.config.createIdentity(
        null, [Go.kubo.core.coreiface.options.key.type('ed25519')]));
    final defaults = ((cfg.json['Addresses'] as Map)['Swarm'] as List)
        .cast<String>()
        .toList();
    for (final p in ['randomports', 'lowpower']) {
      Go.kubo.config.profiles[p]!.transform(cfg);
    }
    // randomports replaces the default list with TCP only; without UDP there is
    // no QUIC nor hole punching (DCUtR). Put kubo's default list back (TCP,
    // QUIC, WebTransport, WebRTC) on the port it picked. The transform replaces
    // the whole JSON: the Addresses map is read after it.
    final addresses = cfg.json['Addresses'] as Map<String, Object?>;
    final port = RegExp(r'/tcp/(\d+)')
        .firstMatch((addresses['Swarm'] as List).first as String)![1]!;
    addresses['Swarm'] = [
      for (final a in defaults) a.replaceAll('/4001', '/$port')
    ];
    // Android has no /etc/resolv.conf: Go's resolver falls back to [::1]:53
    // and DNSLink and /dnsaddr fail. DNS over HTTPS (kubo's DNS.Resolvers).
    cfg.json['DNS'] = {
      ...?cfg.json['DNS'] as Map<String, Object?>?,
      'Resolvers': {'.': 'https://cloudflare-dns.com/dns-query'},
    };
    Go.kubo.repo.fsrepo.init(repoPath, cfg);
  }
}

/// Starts the online node over [repoPath], with pubsub on.
Future<KuboCoreIpfsNode> startNode(Context ctx, String repoPath) {
  final repo = Go.kubo.repo.fsrepo.open(repoPath);
  return Go.kubo.core.newNode(
      ctx,
      KuboCoreNodeBuildCfg(
          repo: repo,
          online: true,
          routing: routingFor(repo.config()),
          extraOpts: {'pubsub': true}));
}

/// The app's log: everything the screen, the checks and the unhandled errors
/// write, with the time; it is what the "copy" button takes. Each line also goes
/// to logcat (tag `flutter`).
final logText = ValueNotifier('');

void log(String line) {
  final t = DateTime.now().toIso8601String().substring(11, 23);
  logText.value += '$t $line\n';
  Zone.root.print('$t $line');
}

/// The background mode: `flutter run --dart-define=P2P_BACKGROUND=
/// foregroundService`; with nothing, the package's default (stop).
const backgroundMode = String.fromEnvironment('P2P_BACKGROUND');

void main() {
  if (backgroundMode == 'foregroundService') {
    P2pService.background = P2pBackground.foregroundService;
  }
  // the foreground service's notification belongs to the app; the text
  // changes with the number of peers (_start)
  P2pFfiFlutter.notification = const P2pNotification(
      title: 'p2p_ffi', text: 'starting the node...', channelName: 'IPFS node');
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError =
        (d) => log('Flutter error: ${d.exceptionAsString()}\n${d.stack}');
    runApp(const MaterialApp(home: NodePage()));
  }, (e, st) => log('unhandled error: $e\n$st'),
      zoneSpecification:
          ZoneSpecification(print: (self, parent, zone, line) => log(line)));
}

/// Battery in % through sysfs (not every device allows reading it).
String battery() {
  try {
    return '${File('/sys/class/power_supply/battery/capacity').readAsStringSync().trim()}%';
  } catch (_) {
    return 'unavailable';
  }
}

class NodePage extends StatefulWidget {
  const NodePage({super.key});

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  /// A context of the current service (the handles of a previous p2p_host are
  /// not valid after a restart).
  Context get ctx => Go.context.background();
  late final String _crashLog = '$appDataDir/crash.log';
  late final String repoPath = '$appDataDir/ipfs';
  late final AppLifecycleListener _life;
  var _foreground = true;
  Future<void> _busy = Future.value(); // start/stop/checks in series
  KuboCoreIpfsNode? _node;
  KuboCoreCoreifaceCoreApi? _api;
  Timer? _tick;
  final _logView = TextEditingController();
  final _logScroll = ScrollController();
  String _status = 'starting...';
  String _peerId = '';
  int _peers = 0;
  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    logText.addListener(_syncLog);
    _life = AppLifecycleListener(
      // in the background P2pService.background decides (the plugin stops
      // the service, or keeps it in a foreground service)
      onPause: () => _foreground = false,
      onResume: () {
        _foreground = true;
        _serial(_resume);
      },
    );

    _serial(() async {
      log('app: ${Platform.operatingSystemVersion}; Dart ${Platform.version}');
      log('cpus: ${Platform.numberOfProcessors}; battery: ${battery()}');
      log('background: ${P2pService.background.name}');
      if (P2pService.background == P2pBackground.foregroundService) {
        // the foreground service's notification only shows with the
        // permission (Android 13+); without it the service runs, without the
        // notification
        final ok = await P2pFfiFlutter.requestNotificationPermission();
        log('notification permission: $ok');
      }
      final crash = await prepare(repoPath, _crashLog, onStop: _onStop);
      if (crash != null) {
        log("THE PREVIOUS P2P_HOST CRASHED (Go's report):\n$crash");
      }
      await _start();
      await _checks();
      // automatic crash test, once per install
      final done = File('$appDataDir/crash-tested');
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
    // follows the end of the log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  void _serial(Future<void> Function() f) {
    _busy = _busy.then((_) => f()).catchError((Object e, StackTrace st) {
      log('error: $e\n$st');
      if (mounted) setState(() => _status = 'error: $e');
    });
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _start() async {
    // service down: the node comes back when the service does (_onStop, _resume)
    if (_node != null || !P2pService.isRunning) return;
    _set(() => _status = 'starting the node...');
    final sw = Stopwatch()..start();
    final n = await startNode(ctx, repoPath);
    final api = Go.kubo.core.coreapi.newCoreApi(n);
    _node = n;
    _api = api;
    _peerId = (await api.key().self(ctx)).id.toString();
    _cycles++;
    _online
      ..reset()
      ..start();
    log('node online in ${sw.elapsedMilliseconds} ms (start $_cycles): $_peerId');
    _tick = Timer.periodic(const Duration(seconds: 3), (_) async {
      final peers = await api.swarm().peers(ctx);
      if (peers.length != _peers) {
        await P2pFfiFlutter.updateNotification(P2pFfiFlutter.notification
            .copyWith(text: 'online: ${peers.length} peers'));
      }
      _set(() => _peers = peers.length);
    });
    _set(() => _status = 'online');
  }

  /// How long the node has been online (reset on each start).
  final _online = Stopwatch();

  /// Closes the node and stops the service (the screen was disposed).
  Future<void> _stop() async {
    _tick?.cancel();
    final n = _node;
    _node = null;
    _api = null;
    if (n != null && P2pService.isRunning) await n.close();
    await P2pService.stop();
  }

  /// The checks, once when the app opens, with the node just online.
  Future<void> _checks() async {
    log('=== checks (battery ${battery()}) ===');
    _set(() => _status = 'online, running the tests...');
    var failed = await networkChecks(_api!, log);
    failed += await localChecks(log);
    _set(() => _status = 'online, waiting to measure reachability...');
    failed += await reachabilityChecks(_api!, _online, log);
    log('=== done: ${failed == 0 ? 'all passed' : '$failed failed'} '
        '(battery ${battery()}) ===');
    _set(() => _status = 'online, tests done');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: logText.value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('log copied')));
    }
  }

  Future<void> _crash() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              content: const Text(
                  'Brings the p2p_host down with a panic in a Go goroutine. The app goes on, shows the report in the log and restarts the service.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('crash it')),
              ],
            ));
    if (ok ?? false) _serial(_crashNow);
  }

  /// A panic in a stray Go goroutine (test function 24 of WIRE.md): only the
  /// p2p_host goes down; the app goes on and [_onStop] handles the rest.
  Future<void> _crashNow() async {
    log('bringing the p2p_host (pid ${P2pService.hostPid}) down on purpose '
        '(a panic in a Go goroutine)');
    _tick?.cancel();
    _node = null;
    _api = null;
    final exit = P2pService.exitCode!;
    $callSync(24); // answers and goes down right after
    log('the p2p_host exited (code ${await exit}); the app went on in pid $pid');
  }

  /// The service stopped without stop() and does not come back on its own; the
  /// old handles are not valid in the new service. Crash: the app shows Go's
  /// report, clears the log, restarts the service and, in the foreground, the
  /// node. Background: it only drops the node; the return ([_resume]) starts
  /// everything again.
  void _onStop(P2pStop stop) => _serial(() async {
        _tick?.cancel();
        _node = null;
        _api = null;
        switch (stop.reason) {
          case P2pStopReason.background:
            log('service stopped in the background (pid ${stop.pid}, up for '
                '${stop.uptime}); the app goes on in pid $pid');
            _set(() => _status = 'stopped (background)');
          case P2pStopReason.crash:
            log('THE P2P_HOST CRASHED (pid ${stop.pid}, exit ${stop.exitCode}, up '
                'for ${stop.uptime}); the app goes on in pid $pid. Go\'s '
                'report:\n${stop.report}');
            if (stop.crashLog case final f?) File(f).writeAsStringSync('');
            await _relaunch();
            if (_foreground) await _start();
        }
      });

  /// Back to the foreground: if the service was stopped, start it again; and the node.
  Future<void> _resume() async {
    if (!P2pService.isRunning) await _relaunch();
    await _start();
  }

  Future<void> _relaunch() async {
    await P2pService.restart();
    setupService(repoPath);
    log('service restarted (pid ${P2pService.hostPid})');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('p2p_ffi'), actions: [
          IconButton(
              tooltip: 'crash it (crash test)',
              onPressed: _crash,
              icon: const Icon(Icons.dangerous_outlined)),
        ]),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('state: $_status (starts: $_cycles) · peers: $_peers',
                key: const Key('status')),
            SelectableText('peer: $_peerId', maxLines: 1),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: FilledButton.tonal(
                      onPressed: _copy, child: const Text('copy log'))),
              IconButton(
                  tooltip: 'clear',
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
