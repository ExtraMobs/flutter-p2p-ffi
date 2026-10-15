// O canal com o ipfs_host (marco 0.9.0): lança o processo do serviço, conecta
// pela ipfs_shm (shm/ipfs_shm.c: memória compartilhada + sininho) e troca
// mensagens: pedido = u32 id, u32 função, u8 modo, argumentos; resposta = u32
// id, u8 tipo (valor, item, fim, erro), dados. O app nunca carrega a libipfs.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'runtime.dart' show IpfsException;

/// Caminho da ipfs_shm; padrão `native/libipfs_shm.so` ou
/// `native\ipfs_shm.dll` relativo ao diretório atual, e no Android
/// `libipfs_shm.so` (empacotada no APK).
String ipfsShmLibraryPath = Platform.isAndroid
    ? 'libipfs_shm.so'
    : Platform.isWindows
        ? r'native\ipfs_shm.dll'
        : 'native/libipfs_shm.so';

/// O serviço caiu (o processo do host saiu) ou o canal fechou.
class IpfsServiceException extends IpfsException {
  IpfsServiceException(super.message);

  @override
  String toString() => 'IpfsServiceException: $message';
}

typedef _WakeNative = Void Function(Int64);

// Chamadas folha (isLeaf): curtas e sem callback ao Dart, pulam a troca de
// contexto do dart:ffi. shm_wait e shm_connect bloqueiam: ficam normais.
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

/// Byte de C (o Dart não tem `Char` portátil no dart:ffi sem package:ffi).
typedef Utf8Char = Uint8;

final _shm = _Shm(DynamicLibrary.open(ipfsShmLibraryPath));

// Tipos de resposta (os ev* de go/runtime.go).
const _evValue = 0, _evItem = 1, _evEnd = 2, _evError = 3;

/// Um canal aberto com um processo ipfs_host.
final class ShmChannel {
  ShmChannel._(this._process, this._h, this._wake, this._stderr);

  final Process _process;
  final Pointer<Void> _h;
  final NativeCallable<_WakeNative> _wake;
  final StringBuffer _stderr;
  final _pending = <int, Object>{}; // Completer ou StreamController
  final _n = _scratch;
  var _nextId = 0;
  var _closed = false;
  String? _deadReason;

  static final _scratch = _malloc4();
  static Pointer<Uint32> _malloc4() => _bytes(4).cast();

  /// Lança [hostPath] (o executável ipfs_host), espera o "ready" e conecta.
  /// [endpoint]: caminho do Unix socket (linux/Android) ou nome base dos
  /// pipes no Windows (`\\.\pipe\...`); padrão: um nome aleatório.
  static Future<ShmChannel> start(String hostPath,
      {String? endpoint, String? crashLog, int spin = 20000}) async {
    endpoint ??= _defaultEndpoint();
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
        ready.completeError(IpfsServiceException(
            'o ipfs_host saiu ($c) antes de ficar pronto: $stderr'));
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
      throw IpfsServiceException(msg);
    }
    _shm.free(err.cast());
    ch = ShmChannel._(p, h, wake, stderr);
    unawaited(p.exitCode.then(ch._onExit));
    return ch;
  }

  static String _defaultEndpoint() {
    final rnd = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
        pid.toRadixString(36);
    if (Platform.isWindows) return r'\\.\pipe\ipfs_ffi_' + rnd;
    // caminho curto: sun_path tem 108 bytes
    return '${Directory.systemTemp.path}/ipfs_ffi_$rnd.sock';
  }

  /// Maior corpo de argumentos que cabe numa mensagem.
  int get maxArgs => _shm.maxMessage(_h) - 9;

  void _send(int id, int fn, int mode, Uint8List? args) {
    if (_deadReason case final r?) throw IpfsServiceException(r);
    final n = 9 + (args?.length ?? 0);
    final p = _shm.reserve(_h, n);
    if (p == nullptr) {
      throw IpfsServiceException(
          _deadReason ?? 'mensagem grande demais ($n bytes)');
    }
    // o corpo começa em 4 mod 8 no anel: os u32 ficam alinhados (todas as
    // plataformas alvo são little-endian)
    p.cast<Uint32>().value = id;
    (p + 4).cast<Uint32>().value = fn;
    p[8] = mode;
    if (args != null && args.isNotEmpty) p.asTypedList(n).setRange(9, n, args);
    _shm.commit(_h, n);
  }

  /// Chamada assíncrona: a resposta chega pelo callback.
  Future<Uint8List> call(int fn, [Uint8List? args]) {
    final c = Completer<Uint8List>();
    final id = ++_nextId;
    _pending[id] = c;
    try {
      _send(id, fn, 1, args);
    } catch (e, st) {
      _pending.remove(id);
      return Future.error(e, st); // assíncrona: falha pelo Future
    }
    return c.future;
  }

  /// Chamada síncrona: bloqueia a isolate até a resposta (gira, depois
  /// dorme), entregando as outras que chegarem no caminho.
  Uint8List callSync(int fn, [Uint8List? args]) {
    final id = ++_nextId;
    _send(id, fn, 0, args);
    for (;;) {
      if (_shm.wait(_h) == 0) {
        throw IpfsServiceException(_deadReason ?? 'o ipfs_host caiu');
      }
      final p = _shm.peek(_h, _n);
      if (p == nullptr) continue;
      final (rid, kind, data) = _read(p);
      _shm.advance(_h);
      if (rid == id) {
        if (kind == _evError) throw IpfsException(utf8.decode(data));
        return data;
      }
      _deliver(rid, kind, data);
    }
  }

  static final _empty = Uint8List(0);

  (int, int, Uint8List) _read(Pointer<Uint8> p) {
    final n = _n.value;
    final data =
        n > 5 ? Uint8List.fromList(p.asTypedList(n).sublist(5)) : _empty;
    return (p.cast<Uint32>().value, p[4], data);
  }

  void _deliver(int id, int kind, Uint8List data) {
    final sink = _pending[id];
    switch ((kind, sink)) {
      case (_evValue, Completer<Uint8List> c):
        _pending.remove(id);
        c.complete(data);
      case (_evError, Completer<Uint8List> c):
        _pending.remove(id);
        c.completeError(IpfsException(utf8.decode(data)));
      case (_evItem, StreamController<Uint8List> s):
        s.add(data);
      case (_evEnd, StreamController<Uint8List> s):
        _pending.remove(id);
        s.close();
      case (_evError, StreamController<Uint8List> s):
        _pending.remove(id);
        s
          ..addError(IpfsException(utf8.decode(data)))
          ..close();
    }
  }

  void _onWake(int v) {
    if (v < 0) {
      _fail(_deadReason ?? 'o ipfs_host caiu');
      return;
    }
    if (_closed) return;
    do {
      for (var p = _shm.peek(_h, _n); p != nullptr; p = _shm.peek(_h, _n)) {
        final (id, kind, data) = _read(p);
        _shm.advance(_h);
        _deliver(id, kind, data);
      }
    } while (_shm.rearm(_h) == 1);
  }

  void _onExit(int code) {
    if (_closed) return;
    final report = _stderr.toString().trim();
    _fail('o ipfs_host saiu ($code)${report.isEmpty ? '' : ': $report'}');
  }

  void _fail(String reason) {
    _deadReason ??= reason;
    final e = IpfsServiceException(_deadReason!);
    for (final s in _pending.values) {
      switch (s) {
        case Completer<Uint8List> c:
          c.completeError(e);
        case StreamController<Uint8List> c:
          c
            ..addError(e)
            ..close();
      }
    }
    _pending.clear();
  }

  /// O pid do processo do serviço.
  int get hostPid => _process.pid;

  /// O processo do serviço terminou: código de saída.
  Future<int> get exitCode => _process.exitCode;

  /// Fecha o canal; o host sai sozinho ao ver o canal fechado.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _shm.close(_h);
    _wake.close();
    _fail('canal fechado');
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill();
      return -1;
    });
  }
}

// Memória C do mesmo runtime da ipfs_shm.
final _malloc = DynamicLibrary.open(ipfsShmLibraryPath).lookupFunction<
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
  if (p == nullptr) return 'ipfs_shm: erro desconhecido';
  var n = 0;
  while (p[n] != 0) {
    n++;
  }
  final s = utf8.decode(p.asTypedList(n));
  _shm.free(p.cast());
  return s;
}
