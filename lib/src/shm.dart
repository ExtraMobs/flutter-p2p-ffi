// The channel to the p2p_host (milestone 0.9.0): launches the service
// process, connects through p2p_shm (shm/p2p_shm.c: shared memory + bell)
// and exchanges messages: request = u32 id, u32 function, u8 mode, arguments;
// response = u32 id, u8 type (value, item, end, error), data. The app never
// loads libipfs.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'runtime.dart' show $goError, P2pServiceException, P2pStopReason;

/// Path of p2p_shm; default bundled next to the executable (Flutter
/// Windows/linux plugin), `native/libp2p_shm.so` or `native\p2p_shm.dll`
/// relative to the current directory, and on Android `libp2p_shm.so`
/// (packaged in the APK).
String p2pShmLibraryPath = _defaultShmLibraryPath();

String _defaultShmLibraryPath() {
  if (Platform.isAndroid) return 'libp2p_shm.so';
  final dir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isWindows) {
    for (final p in [
      '$dir\\p2p_shm.dll',
      r'native\p2p_shm.dll',
      packageNativePath('p2p_shm.dll'),
    ]) {
      if (p != null && File(p).existsSync()) return p;
    }
    return r'native\p2p_shm.dll';
  }
  for (final p in [
    '$dir/lib/libp2p_shm.so',
    '$dir/libp2p_shm.so',
    'native/libp2p_shm.so',
    packageNativePath('libp2p_shm.so'),
  ]) {
    if (p != null && File(p).existsSync()) return p;
  }
  return 'native/libp2p_shm.so';
}

/// Resolves `native/[fileName]` inside the `p2p_ffi` package root from
/// `.dart_tool/package_config.json` when running `dart run` or `flutter test`
/// from a consumer package.
String? packageNativePath(String fileName) {
  try {
    final cfgFile = File('.dart_tool/package_config.json');
    if (!cfgFile.existsSync()) return null;
    final cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, Object?>;
    final pkgs = cfg['packages'] as List<Object?>?;
    if (pkgs == null) return null;
    for (final p in pkgs) {
      if (p is Map<String, Object?> && p['name'] == 'p2p_ffi') {
        final rootUri = p['rootUri'] as String?;
        if (rootUri == null) return null;
        final rootDir =
            Directory.fromUri(cfgFile.absolute.parent.uri.resolve(rootUri));
        final sep = Platform.pathSeparator;
        return '${rootDir.path}${sep}native$sep$fileName';
      }
    }
  } catch (_) {}
  return null;
}

typedef _WakeNative = Void Function(Int64);

// Leaf calls (isLeaf): short and without callbacks into Dart, they skip the
// dart:ffi context switch. shm_wait and shm_connect block: they stay normal.
final class _Shm {
  _Shm(DynamicLibrary l)
      : connect = l.lookupFunction<
            Pointer<Void> Function(Pointer<Utf8Char>, Int32,
                Pointer<NativeFunction<_WakeNative>>, Pointer<Pointer<Uint8>>),
            Pointer<Void> Function(
                Pointer<Utf8Char>,
                int,
                Pointer<NativeFunction<_WakeNative>>,
                Pointer<Pointer<Uint8>>)>('shm_connect'),
        reserve = l.lookupFunction<
            Pointer<Uint8> Function(Pointer<Void>, Uint32),
            Pointer<Uint8> Function(
                Pointer<Void>, int)>('shm_reserve', isLeaf: true),
        commit = l.lookupFunction<Void Function(Pointer<Void>, Uint32),
            void Function(Pointer<Void>, int)>('shm_commit', isLeaf: true),
        peek = l.lookupFunction<
            Pointer<Uint8> Function(Pointer<Void>, Pointer<Uint32>),
            Pointer<Uint8> Function(
                Pointer<Void>, Pointer<Uint32>)>('shm_peek', isLeaf: true),
        advance = l.lookupFunction<Void Function(Pointer<Void>),
            void Function(Pointer<Void>)>('shm_advance', isLeaf: true),
        wait = l.lookupFunction<Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)>('shm_wait'),
        rearm = l.lookupFunction<Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)>('shm_rearm', isLeaf: true),
        maxMessage = l.lookupFunction<Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)>('shm_max_message'),
        close = l.lookupFunction<Void Function(Pointer<Void>),
            void Function(Pointer<Void>)>('shm_close'),
        free = l.lookupFunction<Void Function(Pointer<Void>),
            void Function(Pointer<Void>)>('shm_free');

  final Pointer<Void> Function(Pointer<Utf8Char>, int,
      Pointer<NativeFunction<_WakeNative>>, Pointer<Pointer<Uint8>>) connect;
  final Pointer<Uint8> Function(Pointer<Void>, int) reserve;
  final void Function(Pointer<Void>, int) commit;
  final Pointer<Uint8> Function(Pointer<Void>, Pointer<Uint32>) peek;
  final void Function(Pointer<Void>) advance;
  final int Function(Pointer<Void>) wait;
  final int Function(Pointer<Void>) rearm;
  final int Function(Pointer<Void>) maxMessage;
  final void Function(Pointer<Void>) close;
  final void Function(Pointer<Void>) free;
}

/// C byte (Dart has no portable `Char` in dart:ffi without package:ffi).
typedef Utf8Char = Uint8;

final _shm = _Shm(DynamicLibrary.open(p2pShmLibraryPath));

// Response types used here (the ev* of go/runtime.go).
const _evValue = 0, _evError = 3;

/// An open channel to an p2p_host process.
final class ShmChannel {
  ShmChannel._(this._process, this._h, this._wake, this._stderr);

  final Process _process;
  final Pointer<Void> _h;
  final NativeCallable<_WakeNative> _wake;
  final StringBuffer _stderr;
  final _pending = <int, Completer<Uint8List>>{}; // from call()
  final _n = _scratch;
  var _nextId = 0;
  var _closed = false;
  P2pServiceException? _dead;

  static final _scratch = _malloc4();
  static Pointer<Uint32> _malloc4() => _bytes(4).cast();

  /// Launches [hostPath] (the p2p_host executable), waits for "ready" and
  /// connects. [endpoint]: Unix socket path (linux/Android) or base name of
  /// the pipes on Windows (`\\.\pipe\...`); default: a random name.
  static Future<ShmChannel> start(String hostPath,
      {String? endpoint, String? crashLog, int spin = 20000}) async {
    endpoint ??= _defaultEndpoint();
    if (!Platform.isWindows && !Platform.isAndroid) {
      final st = FileStat.statSync(hostPath);
      if (st.type != FileSystemEntityType.notFound && (st.mode & 0x49) == 0) {
        Process.runSync('chmod', ['+x', hostPath]);
      }
    }
    final p = await Process.start(hostPath, [
      '-endpoint',
      endpoint,
      if (crashLog != null) ...['-crash-log', crashLog],
      '-spin',
      '$spin',
    ]);
    final stderr = StringBuffer();
    p.stderr.transform(utf8.decoder).listen(stderr.write);
    final ready = Completer<void>();
    p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) {
      if (l == 'ready' && !ready.isCompleted) ready.complete();
    });
    unawaited(p.exitCode.then((c) {
      if (!ready.isCompleted) {
        ready.completeError(P2pServiceException(
            'p2p_host exited ($c) before becoming ready: $stderr'));
      }
    }));
    await ready.future;
    late final ShmChannel ch;
    final wake = NativeCallable<_WakeNative>.listener((int v) => ch._onWake(v));
    final err = _bytes(8).cast<Pointer<Uint8>>();
    final ep = _cstr(endpoint);
    final h = _shm.connect(ep, spin, wake.nativeFunction, err);
    _shm.free(ep.cast());
    if (h == nullptr) {
      final msg = _take(err.value);
      _shm.free(err.cast());
      wake.close();
      p.kill();
      throw P2pServiceException(msg);
    }
    _shm.free(err.cast());
    ch = ShmChannel._(p, h, wake, stderr);
    unawaited(p.exitCode.then(ch._onExit));
    return ch;
  }

  static String _defaultEndpoint() {
    // random: isolates of the same process (same pid) start hosts in the
    // same clock tick (coarse on Windows), and a repeated name fails with
    // "All pipe instances are busy"
    final r = Random.secure();
    final rnd = [for (var i = 0; i < 4; i++) r.nextInt(1 << 32)]
        .map((v) => v.toRadixString(36))
        .join();
    if (Platform.isWindows) return r'\\.\pipe\p2p_ffi_' + rnd;
    // short path: sun_path has 108 bytes
    return '${Directory.systemTemp.path}/p2p_ffi_$rnd.sock';
  }

  /// Messages for ids that are not from [call]/[callSync] of this channel
  /// (the service mode runtime registers its own).
  void Function(int id, int kind, Uint8List data)? onMessage;

  /// Notified once when the host crashes or the channel closes.
  void Function(P2pServiceException e)? onDead;

  /// A new id for [send]/[waitFor].
  int newId() => ++_nextId;

  /// Sends request [id] (u32 id, u32 [fn], u8 [mode], [body]) in frames
  /// `[u32 continues][chunk]`, splitting what does not fit in one frame. One
  /// producer at a time: the channel belongs to one isolate.
  void send(int id, int fn, int mode, [Uint8List? body]) {
    if (_dead case final e?) throw e;
    final total = 9 + (body?.length ?? 0);
    final max = _shm.maxMessage(_h) - 4;
    if (total <= max) {
      final p = _reserve(total + 4);
      p.cast<Uint32>().value = 0;
      // the frame body starts at 0 mod 8: the u32s stay aligned (all
      // target platforms are little-endian)
      (p + 4).cast<Uint32>().value = id;
      (p + 8).cast<Uint32>().value = fn;
      p[12] = mode;
      if (body != null && body.isNotEmpty) {
        p.asTypedList(total + 4).setRange(13, total + 4, body);
      }
      _shm.commit(_h, total + 4);
      return;
    }
    final whole = Uint8List(total);
    ByteData.sublistView(whole)
      ..setUint32(0, id, Endian.little)
      ..setUint32(4, fn, Endian.little);
    whole[8] = mode;
    whole.setRange(9, total, body!);
    for (var off = 0; off < total; off += max) {
      final n = total - off < max ? total - off : max;
      final p = _reserve(n + 4);
      p.cast<Uint32>().value = off + n < total ? 1 : 0;
      p.asTypedList(n + 4).setRange(4, n + 4, whole, off);
      _shm.commit(_h, n + 4);
    }
  }

  Pointer<Uint8> _reserve(int n) {
    final p = _shm.reserve(_h, n);
    if (p == nullptr) throw _crashed;
    return p;
  }

  /// Asynchronous call: the response arrives through the callback.
  Future<Uint8List> call(int fn, [Uint8List? args]) {
    final c = Completer<Uint8List>();
    final id = newId();
    _pending[id] = c;
    try {
      send(id, fn, 1, args);
    } catch (e, st) {
      _pending.remove(id);
      return Future.error(e, st); // async: fails through the Future
    }
    return c.future;
  }

  /// Synchronous call: blocks the isolate until the response (spins, then
  /// sleeps), delivering the others that arrive along the way.
  Uint8List callSync(int fn, [Uint8List? args]) {
    final id = newId();
    send(id, fn, 0, args);
    final (kind, data) = waitFor(id);
    if (kind == _evError) throw $goError(data);
    return data;
  }

  /// Waits for response [id] (type and data), delivering the others that
  /// arrive along the way.
  (int, Uint8List) waitFor(int id) {
    for (;;) {
      if (_shm.wait(_h) == 0) {
        throw _crashed;
      }
      final p = _shm.peek(_h, _n);
      if (p == nullptr) continue;
      final m = _frame(p);
      _shm.advance(_h);
      if (m == null) continue;
      final (rid, kind, data) = m;
      if (rid == id) return (kind, data);
      _deliver(rid, kind, data);
    }
  }

  static final _empty = Uint8List(0);
  final _parts = BytesBuilder(copy: true);

  /// Reads a frame; returns the message when it is complete.
  (int, int, Uint8List)? _frame(Pointer<Uint8> p) {
    final n = _n.value - 4;
    final body = p + 4;
    if (p.cast<Uint32>().value == 1) {
      _parts.add(body.asTypedList(n));
      return null;
    }
    if (_parts.isNotEmpty) {
      _parts.add(body.asTypedList(n));
      final m = _parts.takeBytes();
      final id = ByteData.sublistView(m).getUint32(0, Endian.little);
      return (id, m[4], Uint8List.sublistView(m, 5));
    }
    final data =
        n > 5 ? Uint8List.fromList(body.asTypedList(n).sublist(5)) : _empty;
    return (body.cast<Uint32>().value, body[4], data);
  }

  void _deliver(int id, int kind, Uint8List data) {
    final sink = _pending[id];
    switch ((kind, sink)) {
      case (_evValue, Completer<Uint8List> c):
        _pending.remove(id);
        c.complete(data);
      case (_evError, Completer<Uint8List> c):
        _pending.remove(id);
        c.completeError($goError(data));
      case (_, null):
        onMessage?.call(id, kind, data);
    }
  }

  void _onWake(int v) {
    if (v < 0) {
      _fail(_crashed);
      return;
    }
    if (_closed) return;
    do {
      for (var p = _shm.peek(_h, _n); p != nullptr; p = _shm.peek(_h, _n)) {
        final m = _frame(p);
        _shm.advance(_h);
        if (m != null) _deliver(m.$1, m.$2, m.$3);
      }
    } while (_shm.rearm(_h) == 1);
  }

  void _onExit(int code) {
    if (_closed) return;
    final report = _stderr.toString().trim();
    _fail(P2pServiceException(
        'p2p_host exited ($code)${report.isEmpty ? '' : ': $report'}',
        reason: P2pStopReason.crash));
  }

  /// The crash still without the process's reason (the p2p_shm notice
  /// arrives before the exit code).
  P2pServiceException get _crashed =>
      _dead ??
      P2pServiceException('p2p_host crashed', reason: P2pStopReason.crash);

  void _fail(P2pServiceException e) {
    final first = _dead == null;
    e = _dead ??= e;
    for (final s in _pending.values) {
      if (s case Completer<Uint8List> c) c.completeError(e);
    }
    _pending.clear();
    if (first) onDead?.call(e);
  }

  /// Why the channel died (the host crashed or the channel closed); null
  /// while alive.
  String? get deadReason => _dead?.message;

  /// What the host wrote to stderr (the report of a panic, if it crashed).
  String get hostStderr => _stderr.toString();

  /// The pid of the service process.
  int get hostPid => _process.pid;

  /// The service process ended: exit code.
  Future<int> get exitCode => _process.exitCode;

  /// Closes the channel; the host exits on its own when it sees the channel
  /// closed. Pending calls fail with [reason] (null: closed by the app).
  Future<void> close({P2pStopReason? reason}) async {
    if (_closed) return;
    _closed = true;
    _shm.close(_h);
    _wake.close();
    _fail(P2pServiceException(
        reason == P2pStopReason.background
            ? 'the service was stopped: the app went to the background'
            : 'channel closed',
        reason: reason));
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill();
      return -1;
    });
  }
}

// C memory from the same runtime as p2p_shm.
final _malloc = DynamicLibrary.open(p2pShmLibraryPath).lookupFunction<
    Pointer<Uint8> Function(Uint64),
    Pointer<Uint8> Function(int)>('shm_malloc');
Pointer<Uint8> _bytes(int n) => _malloc(n);

Pointer<Utf8Char> _cstr(String s) {
  final b = utf8.encode(s);
  final p = _bytes(b.length + 1);
  p.asTypedList(b.length + 1)
    ..setAll(0, b)
    ..[b.length] = 0;
  return p;
}

String _take(Pointer<Uint8> p) {
  if (p == nullptr) return 'p2p_shm: unknown error';
  var n = 0;
  while (p[n] != 0) {
    n++;
  }
  final s = utf8.decode(p.asTypedList(n));
  _shm.free(p.cast());
  return s;
}
