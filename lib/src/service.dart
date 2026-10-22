/// The service: kubo runs in the `ipfs_host` executable, in another process;
/// the app only talks to it through `ipfs_shm` (shared memory; protocol in
/// `WIRE.md`). A Go panic takes down only the service, and on Android the
/// package stops it when the app goes to the background
/// ([P2pService.background]): pending calls fail with
/// [P2pServiceException] (carrying the [P2pStopReason]) and the `onStop` of
/// [P2pService.start] receives an [P2pStop]; the package user decides what
/// to do (clear the log, [P2pService.restart], recreate the node and
/// CoreAPI: handles from the previous service are no longer valid).
///
/// ```dart
/// await P2pService.start(crashLog: 'crash.log', onStop: (stop) async {
///   print('${stop.reason}: ${stop.report}');
///   if (stop.reason == P2pStopReason.crash) await P2pService.restart();
/// });
/// final ctx = context.background();
/// // ... the generated API ...
/// await P2pService.stop();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'runtime.dart';
import 'shm.dart';
import 'table.dart';

export 'runtime.dart'
    show
        GoHandle,
        GoHandleUse,
        GoScope,
        P2pBusy,
        GolangCanceledException,
        GolangDeadlineExceededException,
        GolangDeadlockException,
        GolangEofException,
        GolangException,
        GolangNotFoundException,
        P2pServiceException,
        P2pStopReason,
        GolangUnexpectedEofException,
        withGoScope;
export 'shm.dart' show p2pShmLibraryPath;

/// Hello function (WIRE.md): `u64` table hash → empty, or error.
const _fnHello = 4;

/// What happens to the service when the app goes to the background (only
/// matters on Android, with the `ipfs_ffi_flutter` plugin).
enum P2pBackground {
  /// The package stops the service (the host exits) and reports it in
  /// `onStop` with [P2pStopReason.background]; starting it again is up to
  /// the app. The default: Android 12+ kills a child process that uses CPU
  /// while the app is in the background, and the app along with it.
  stop,

  /// The service keeps running: the plugin keeps an Android foreground
  /// service (with a notification) while the host is up.
  foregroundService,
}

/// The platform side (on Android, the `ipfs_ffi_flutter` plugin installs its
/// own when the app opens): notified when the service starts and when it
/// stops.
abstract interface class P2pPlatform {
  /// The service started in mode [mode] (the app is in the foreground).
  Future<void> serviceStarted(P2pBackground mode);

  /// The service stopped (stop or background, or a crash outside
  /// [P2pBackground.foregroundService]). After a crash in that mode it is
  /// not called: the platform keeps the app alive in the background so that
  /// `onStop` can [P2pService.restart] (Android only starts a foreground
  /// service from the foreground); [P2pService.stop] ends it.
  Future<void> serviceStopped();
}

/// A stop of the ipfs_host without [P2pService.stop]: it crashed or was
/// stopped in the background ([reason]).
final class P2pStop {
  P2pStop._(this.reason, this.exitCode, this.report, this.crashLog, this.pid,
      this.uptime);

  /// Crashed ([P2pStopReason.crash]) or stopped with the app in the
  /// background ([P2pStopReason.background]).
  final P2pStopReason reason;

  /// The host's exit code (2 on a Go panic).
  final int exitCode;

  /// Go's report on a crash: what the host appended to [crashLog] since it
  /// started, or its stderr (without a crashLog, or if the file stayed
  /// empty). Empty in the background case.
  final String report;

  /// The crash file passed to [P2pService.start] (null if none); the host
  /// only appends to it, and clearing it is up to the package user.
  final String? crashLog;

  /// The pid of the host that stopped.
  final int pid;

  /// How long it stayed up.
  final Duration uptime;

  /// The same exception the pending calls received.
  P2pServiceException get exception => P2pServiceException(
      switch (reason) {
        P2pStopReason.crash => 'ipfs_host crashed (exit $exitCode)'
            '${report.isEmpty ? '' : ': $report'}',
        P2pStopReason.background =>
          'the service was stopped: the app went to the background',
      },
      reason: reason);

  @override
  String toString() => exception.message;
}

/// What to do when the ipfs_host stops; see [P2pService.start].
typedef P2pStopHandler = FutureOr<void> Function(P2pStop stop);

/// This isolate's service (one channel per isolate).
abstract final class P2pService {
  static ShmChannel? _ch;
  static ({
    String hostPath,
    String? crashLog,
    int spin,
    P2pStopHandler? onStop
  })? _params;
  static var _mode = P2pBackground.stop; // read from [background] on start
  static var _logStart = 0; // crashLog size when the current host started
  static final _up = Stopwatch();

  /// What to do with the service when the app goes to the background
  /// (default: stop). Read on each [start] and [restart]: changing it while
  /// the service is up takes effect on the next start.
  static P2pBackground background = P2pBackground.stop;

  /// The platform side; on Android, the `ipfs_ffi_flutter` plugin installs it
  /// when the app opens. Without it the package does not know about the
  /// background (an app without Flutter can call [appInBackground] itself).
  static P2pPlatform? platform;

  /// Launches the ipfs_host ([hostPath]; default [defaultHostPath]), connects,
  /// checks in the Hello that app and host came from the same generator and
  /// binds the generated API to it. [crashLog]: file where Go appends the
  /// report of a panic that takes the host down. [spin]: busy-wait iterations
  /// before sleeping on the bell.
  ///
  /// If the host stops without [stop] (crashed, or the app went to the
  /// background in [P2pBackground.stop] mode), nothing comes back on its
  /// own: pending calls fail with [P2pServiceException] and [onStop]
  /// (default: none) receives an [P2pStop] with the reason; it decides
  /// whether to clear the [crashLog], whether to call [restart] and when.
  /// Already running, it is a [StateError].
  static Future<void> start(
      {String? hostPath,
      String? crashLog,
      int spin = 20000,
      P2pStopHandler? onStop}) async {
    if (isRunning) {
      throw StateError('P2pService is already running (stop() first)');
    }
    _params = (
      hostPath: hostPath ?? defaultHostPath(),
      crashLog: crashLog,
      spin: spin,
      onStop: onStop
    );
    await _launch();
  }

  /// Launches the host again with the parameters of the last [start]
  /// (including `onStop`) and the current [background]; for use after a stop.
  /// Without a [start] before (or after [stop]), it is a [StateError];
  /// already running, too.
  static Future<void> restart() async {
    if (_params == null) {
      throw StateError('P2pService was not started (start() first)');
    }
    if (isRunning) {
      throw StateError('P2pService is already running (stop() first)');
    }
    await _launch();
  }

  static Future<void> _launch() async {
    if (_ch case final old?) {
      _ch = null;
      $detach();
      await old.close();
    }
    final mode = background;
    if (mode == P2pBackground.foregroundService &&
        Platform.isAndroid &&
        platform == null) {
      throw StateError('P2pBackground.foregroundService on Android requires '
          'the ipfs_ffi_flutter plugin in the app');
    }
    final p = _params!;
    if (p.crashLog case final f?) {
      final file =
          File(f); // the host appends: the new report comes after this point
      _logStart = file.existsSync() ? file.lengthSync() : 0;
    }
    final ch =
        await ShmChannel.start(p.hostPath, crashLog: p.crashLog, spin: p.spin);
    try {
      final hello = Uint8List(8)
        ..buffer.asByteData().setInt64(0, p2pTableHash, Endian.little);
      ch.callSync(_fnHello, hello);
    } catch (_) {
      await ch.close();
      rethrow;
    }
    _ch = ch;
    _mode = mode;
    $attach(ch);
    _up
      ..reset()
      ..start();
    unawaited(ch.exitCode.then((code) => _died(ch, code)));
    try {
      await platform?.serviceStarted(mode);
    } catch (_) {
      // the platform side failed (e.g. Android denied the foreground
      // service): the service is not left half up
      await _stop(true);
      rethrow;
    }
  }

  /// The host [ch] exited without stop(): releases the channel and delivers
  /// the crash to onStop.
  static Future<void> _died(ShmChannel ch, int code) async {
    if (!identical(_ch, ch)) return; // stopped or already replaced
    final crashLog = _params?.crashLog;
    var report = '';
    if (crashLog != null) {
      try {
        final all = File(crashLog).readAsBytesSync();
        report = utf8
            .decode(all.sublist(_logStart.clamp(0, all.length)),
                allowMalformed: true)
            .trim();
      } on FileSystemException {
        // no file: stderr is used
      }
    }
    if (report.isEmpty) report = ch.hostStderr.trim();
    final s = P2pStop._(
        P2pStopReason.crash, code, report, crashLog, ch.hostPid, _up.elapsed);
    _ch = null;
    $detach(s.exception);
    await ch.close();
    // foregroundService: the platform keeps the app alive for the restart
    // (see P2pPlatform.serviceStopped)
    if (_mode != P2pBackground.foregroundService) {
      await platform?.serviceStopped();
    }
    // an error from onStop goes to the zone of whoever called start()
    await _params?.onStop?.call(s);
  }

  /// The app went to the background: in [P2pBackground.stop] mode (the
  /// [background] of the current start), stops the service and reports it in
  /// `onStop` with [P2pStopReason.background]; pending calls fail with that
  /// reason and [restart] starts it again. In
  /// [P2pBackground.foregroundService], or without a service, does nothing.
  /// The `ipfs_ffi_flutter` plugin calls it on its own.
  static Future<void> appInBackground() async {
    final ch = _ch;
    if (ch == null || !isRunning || _mode != P2pBackground.stop) return;
    _ch = null;
    await ch.close(reason: P2pStopReason.background);
    final s = P2pStop._(P2pStopReason.background, await ch.exitCode, '',
        _params?.crashLog, ch.hostPid, _up.elapsed);
    $detach(s.exception);
    await platform?.serviceStopped();
    await _params?.onStop?.call(s);
  }

  /// Stops the service; the host exits on its own. The service's handles are
  /// no longer valid. Does not call `onStop`.
  static Future<void> stop() => _stop(false);

  /// The objects in use by calls with a callback (an index iterating, a
  /// selector builder in `exploreFields`...): one event when each enters and
  /// leaves use. Calling one from inside its callback may wait for a lock
  /// that call holds; the host detects it ([GolangDeadlockException]). For the
  /// app to show what cannot be touched yet (Riverpod, a `ValueNotifier`...);
  /// `isBusy` on the object answers the same now.
  static Stream<P2pBusy> get busy => $busyChanges;

  static Future<void> _stop(bool keepParams) async {
    if (!keepParams) _params = null;
    final ch = _ch;
    if (ch == null) {
      // after a crash in foregroundService mode the platform is still up
      await platform?.serviceStopped();
      return;
    }
    _ch = null;
    $detach();
    await ch.close();
    await platform?.serviceStopped();
  }

  /// Whether the service is up (after a stop, false until [restart]).
  static bool get isRunning => _ch != null && _ch!.deadReason == null;

  /// The current host's exit code (completes when it exits, including on a
  /// panic); null without a service.
  static Future<int>? get exitCode => _ch?.exitCode;

  /// The current host's pid; null without a service.
  static int? get hostPid => _ch?.hostPid;
}

/// Default ipfs_host path: bundled next to the executable (Flutter Windows/linux
/// plugin) or `native\ipfs_host.exe` (Windows) / `native/ipfs_host` relative to
/// the current directory; on Android, the `libipfs_host.so` in the app's native
/// library folder (`nativeLibraryDir`), found through `libapp.so`/`libflutter.so`
/// in `/proc/self/maps` (the APK must extract the libs: an executable does not
/// run from inside the APK).
String defaultHostPath() {
  if (Platform.isWindows) {
    final dir = File(Platform.resolvedExecutable).parent.path;
    for (final p in [
      '$dir\\ipfs_host.exe',
      r'native\ipfs_host.exe',
      packageNativePath('ipfs_host.exe'),
    ]) {
      if (p != null && File(p).existsSync()) return p;
    }
    return r'native\ipfs_host.exe';
  }
  if (!Platform.isAndroid) {
    final dir = File(Platform.resolvedExecutable).parent.path;
    for (final p in [
      '$dir/lib/ipfs_host',
      '$dir/ipfs_host',
      'native/ipfs_host',
      packageNativePath('ipfs_host'),
    ]) {
      if (p != null && File(p).existsSync()) return p;
    }
    return 'native/ipfs_host';
  }
  for (final line in File('/proc/self/maps').readAsLinesSync()) {
    final i = line.indexOf('/');
    if (i < 0) continue;
    final f = line.substring(i);
    if (f.endsWith('/libapp.so') || f.endsWith('/libflutter.so')) {
      return '${f.substring(0, f.lastIndexOf('/'))}/libipfs_host.so';
    }
  }
  throw P2pServiceException('ipfs_host: the native library folder of the '
      'app did not appear in /proc/self/maps; pass hostPath');
}
