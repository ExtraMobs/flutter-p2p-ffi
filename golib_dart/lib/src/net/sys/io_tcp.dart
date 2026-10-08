part of 'sys_io.dart';

Future<SysTcpConn> _dialTcp(
  SysAddr remote,
  SysAddr? local,
  DateTime? deadline,
  Future<void>? cancel,
) async {
  if (deadline != null && !deadline.isAfter(DateTime.now())) {
    throw const SysTimeout();
  }
  if (_pendingCloses.isNotEmpty) await _closesSettled();
  final source = local == null || local.ip.isEmpty ? null : _inet(local.ip);
  final ConnectionTask<RawSocket> task;
  try {
    task = await RawSocket.startConnect(
      // IP vazio: o próprio sistema, como o Go (`Dial("tcp", ":80")`).
      remote.ip.isEmpty
          ? InternetAddress.loopbackIPv4
          : _inet(remote.ip, remote.zone),
      remote.port,
      sourceAddress: source,
      sourcePort: local?.port ?? 0,
    );
  } catch (e) {
    throw _mapBind(e, 'connect');
  }
  // 1: prazo; 2: cancelado.
  var aborted = 0;
  Timer? timer;
  if (deadline != null) {
    timer = Timer(deadline.difference(DateTime.now()), () {
      aborted = 1;
      task.cancel();
    });
  }
  var settled = false;
  unawaited(
    cancel?.then((_) {
      if (settled || aborted != 0) return;
      aborted = 2;
      task.cancel();
    }),
  );
  final RawSocket socket;
  try {
    socket = await task.socket;
  } catch (e) {
    if (aborted == 1) throw const SysTimeout();
    if (aborted == 2) throw const SysCanceled();
    throw _mapBind(e, 'connect');
  } finally {
    settled = true;
    timer?.cancel();
  }
  if (aborted != 0) {
    unawaited(socket.close());
    throw aborted == 1 ? const SysTimeout() : const SysCanceled();
  }
  return _IoTcpConn.create(socket, local?.ip);
}

/// Conexão TCP sobre o `Fd` do `internal/poll`.
final class _IoTcpConn implements SysTcpConn, SysSockopts {
  _IoTcpConn._(this._socket, this._fd, this.local, this.remote);

  /// Endereços lidos na criação (o `RawSocket` não responde depois de
  /// fechado). O IP local precisa de [_localIp]: o `dart:io` devolve em
  /// `address` o endereço do listener (aceitas) ou o do par (discadas).
  /// O `Fd` (e a inscrição nos eventos) nasce antes de qualquer `await`.
  static Future<_IoTcpConn> create(RawSocket s, Uint8List? boundIp) async {
    final remote = _addrOf(s.remoteAddress, s.remotePort);
    final port = s.port;
    final fd = Fd(s);
    final ip = await _localIp(boundIp, remote, port);
    return _IoTcpConn._(s, fd, SysAddr(ip, port), remote);
  }

  /// Socket Unix de fluxo: os endereços são caminhos, já conhecidos.
  static _IoTcpConn unix(
    RawSocket s, {
    required String local,
    required String remote,
  }) => _IoTcpConn._(s, Fd(s), SysAddr.unix(local), SysAddr.unix(remote));

  final RawSocket _socket;
  final Fd _fd;

  /// Erro de leitura já entregue (ver [read]).
  bool _readErrDone = false;

  @override
  final SysAddr local;

  @override
  final SysAddr remote;

  @override
  Future<int> read(Uint8List buf) async {
    if (buf.isEmpty) return 0;
    return heldIo(() async {
      if (_readErrDone) return 0;
      try {
        final data = await _fd.read(buf.length);
        buf.setRange(0, data.length, data);
        return data.length;
      } catch (e) {
        final mapped = _mapIo(e, 'read');
        // O kernel reporta o erro do socket (um `ECONNRESET`, por exemplo)
        // uma vez só: a leitura seguinte dá EOF, como no Go.
        if (mapped is SysError) _readErrDone = true;
        throw mapped;
      }
    });
  }

  @override
  Future<int> write(Uint8List data) async {
    if (data.isEmpty) return 0;
    return heldIo(() async {
      var written = 0;
      try {
        return await _fd.write(data, progress: (n) => written = n);
      } catch (e) {
        throw _mapIo(e, 'write', written: written);
      }
    });
  }

  @override
  void close() => unawaited(_fd.close());

  @override
  void closeWrite() => _shutdown(SocketDirection.send);

  @override
  void closeRead() => _shutdown(SocketDirection.receive);

  void _shutdown(SocketDirection d) {
    if (_fd.isClosed) throw const SysClosed();
    try {
      _socket.shutdown(d);
    } catch (e) {
      throw _mapIo(e, 'shutdown');
    }
  }

  @override
  set readDeadline(DateTime? d) => _fd.setReadDeadline(d);

  @override
  set writeDeadline(DateTime? d) => _fd.setWriteDeadline(d);

  @override
  void setNoDelay(bool v) =>
      _opt(() => _socket.setOption(SocketOption.tcpNoDelay, v));

  @override
  void setKeepAlive(bool v) => _opt(
    () => _socket.setRawOption(
      RawSocketOption.fromBool(RawSocketOption.levelSocket, _soKeepAlive, v),
    ),
  );

  /// `setsockopt(SOL_SOCKET, SO_LINGER, struct linger)`. ⚠️ Só no linux: a
  /// constante e o formato da struct mudam nos BSD/macOS e no Windows, e
  /// fora do linux isto fica aceito e ignorado (o `close` é imediato).
  @override
  void setLinger(int sec) => _opt(() {
    if (!_linuxSockopt) return;
    // `struct linger { int l_onoff; int l_linger; }` na ordem do host.
    final v = Uint8List(8);
    final d = ByteData.view(v.buffer);
    d.setInt32(0, sec >= 0 ? 1 : 0, Endian.host);
    d.setInt32(4, sec >= 0 ? sec : 0, Endian.host);
    _socket.setRawOption(
      RawSocketOption(RawSocketOption.levelSocket, _soLinger, v),
    );
  });

  @override
  void setKeepAliveIdle(int secs) => _tcpOpt(_tcpKeepIdle, secs);

  @override
  void setKeepAliveInterval(int secs) => _tcpOpt(_tcpKeepIntvl, secs);

  @override
  void setKeepAliveCount(int n) => _tcpOpt(_tcpKeepCnt, n);

  /// ⚠️ Fora do linux as três opções ficam aceitas e ignoradas (constantes
  /// diferentes; no Windows nem existem assim).
  void _tcpOpt(int option, int value) => _opt(() {
    if (!_linuxSockopt) return;
    _socket.setRawOption(
      RawSocketOption.fromInt(RawSocketOption.levelTcp, option, value),
    );
  });

  @override
  int rawSetsockopt(int level, int opt, Uint8List value) => _fd.isClosed
      ? -sf.EBADF
      : _ioSetsockopt(_socket.setRawOption, level, opt, value);

  @override
  int rawGetsockopt(int level, int opt, Uint8List out) => _fd.isClosed
      ? -sf.EBADF
      : _ioGetsockopt(_socket.getRawOption, level, opt, out);

  void _opt(void Function() set) {
    if (_fd.isClosed) throw const SysClosed();
    try {
      set();
    } catch (e) {
      throw _mapIo(e, 'setsockopt');
    }
  }
}

/// `SO_KEEPALIVE`: 9 no linux, 8 nos BSD/macOS e no Windows.
final int _soKeepAlive = Platform.isLinux || Platform.isAndroid ? 9 : 8;

/// Constantes do linux (as de outras plataformas divergem): `SO_LINGER`,
/// `TCP_KEEPIDLE`, `TCP_KEEPINTVL` e `TCP_KEEPCNT`.
const int _soLinger = 13;
const int _tcpKeepIdle = 4;
const int _tcpKeepIntvl = 5;
const int _tcpKeepCnt = 6;

/// Linux (ou Android): só lá as constantes acima valem.
final bool _linuxSockopt = Platform.isLinux || Platform.isAndroid;

/// IP local de uma conexão. Com IP fixado (bind explícito), é ele; no linux,
/// a linha da conexão em `/proc/net/tcp{,6}` (exato); senão, ⚠️ o loopback
/// da família quando o par é loopback, e "não especificado" no resto.
Future<Uint8List> _localIp(Uint8List? bound, SysAddr remote, int port) async {
  if (bound != null && bound.isNotEmpty && !bound.every((b) => b == 0)) {
    return bound;
  }
  if (Platform.isLinux || Platform.isAndroid) {
    final ip = await _procLocalIp(remote, port);
    if (ip != null) {
      return remote.ip.length == 16 ? ipTo16(ip) : (ipTo4(ip) ?? ip);
    }
  }
  final v4 = ipTo4(remote.ip);
  if (isLoopbackIp(remote.ip)) {
    if (v4 == null) return Uint8List(16)..[15] = 1;
    final lo = Uint8List.fromList([127, 0, 0, 1]);
    return remote.ip.length == 16 ? ipTo16(lo) : lo;
  }
  return Uint8List(remote.ip.length);
}

/// Procura `local:port ↔ remote` em `/proc/net/tcp` e `tcp6`.
Future<Uint8List?> _procLocalIp(SysAddr remote, int port) async {
  final want = ipTo16(remote.ip);
  for (final f in const ['/proc/net/tcp', '/proc/net/tcp6']) {
    final String text;
    try {
      text = await File(f).readAsString();
    } on FileSystemException {
      continue;
    }
    for (final line in text.split('\n').skip(1)) {
      final cols = line.trim().split(RegExp(r'\s+'));
      if (cols.length < 3) continue;
      final l = _procAddr(cols[1]), r = _procAddr(cols[2]);
      if (l == null || r == null) continue;
      if (l.$2 != port || r.$2 != remote.port) continue;
      if (!_eq(ipTo16(r.$1), want)) continue;
      return l.$1;
    }
  }
  return null;
}

/// `0100007F:1F90` → (127.0.0.1, 8080): palavras de 32 bits na ordem do host.
(Uint8List, int)? _procAddr(String s) {
  final c = s.indexOf(':');
  if (c < 0) return null;
  final hex = s.substring(0, c);
  final port = int.tryParse(s.substring(c + 1), radix: 16);
  if (port == null || (hex.length != 8 && hex.length != 32)) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var w = 0; w < hex.length ~/ 8; w++) {
    final v = int.tryParse(hex.substring(w * 8, w * 8 + 8), radix: 16);
    if (v == null) return null;
    for (var b = 0; b < 4; b++) {
      final shift = Endian.host == Endian.little ? 8 * b : 8 * (3 - b);
      out[w * 4 + b] = (v >> shift) & 0xff;
    }
  }
  return (out, port);
}
