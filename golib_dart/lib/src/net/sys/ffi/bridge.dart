/// Ponte FFI → `dart:io`: um socket de fluxo conectado criado pelo FFI (dial
/// com `Control`, conexão aceita por um listener do FFI) vira um
/// [RawSocket] do `dart:io`, e daí segue o caminho atual (`io_tcp.dart`:
/// `_IoTcpConn` sobre o `Fd`/`PollDesc` do `internal/poll`).
///
/// O `dart:io` não adota fd cru; o único caminho é receber o fd por
/// `SCM_RIGHTS` num socket Unix ([RawSocket.readMessage] →
/// `ResourceHandle.toRawSocket`). A sessão é um par Unix de fluxo privado:
/// o FFI escuta num nome abstrato aleatório, o `dart:io` conecta, e os dois
/// lados conferem `SO_PEERCRED` (pid igual ao `getpid()`) antes de passar
/// qualquer fd — outro processo pode conectar primeiro no nome abstrato.
/// O listener fecha logo depois do `accept`.
///
/// Só fluxo: o `ResourceHandle` não tem `toRawServerSocket`, e o
/// `toRawDatagramSocket` não funciona na VM (listeners e UDP ficam no FFI).
///
/// Um `RawSocket` aberto segura a VM viva (medido), então a sessão só
/// existe enquanto há transferência: abre sob demanda e fecha quando a
/// última termina (as do mesmo turno do laço de eventos reaproveitam).
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../sysffi/sysffi.dart' as sf;
import '../common.dart';
import 'errors.dart';
import 'fd.dart';

/// Passa [conn] (socket de fluxo conectado do FFI) ao `dart:io`. Consome
/// [conn]: em sucesso ou falha, ele termina fechado (o `dart:io` fica com a
/// cópia recebida). Erros: [FfiErrno] (`getpeername` com `ENOTCONN` se não
/// conectado; `getsockopt` com `EPROTOTYPE` se não for de fluxo; `sendmsg`),
/// [StateError] se a sessão não puder ser aberta ou o par não for este
/// processo.
Future<RawSocket> ffiToRawSocket(FfiFd conn) => heldIo(() async {
  try {
    _checkStream(conn);
    final s = await _Session.acquire();
    try {
      return s.transfer(conn.fd);
    } finally {
      _Session.release();
    }
  } finally {
    conn.close();
  }
});

void _checkStream(FfiFd conn) {
  if (conn.isClosed) throw const SysClosed();
  final (type, err) = sf.getsockoptInt(conn.fd, sf.SOL_SOCKET, sf.SO_TYPE);
  if (err != 0) throw FfiErrno('getsockopt', err);
  if (type != sf.SOCK_STREAM) throw const FfiErrno('getsockopt', sf.EPROTOTYPE);
  if (conn.peerAddr() == null) throw const FfiErrno('getpeername', sf.ENOTCONN);
}

/// pid do par de um socket Unix (`SO_PEERCRED`), ou `null`.
int? _peerPid(int fd) {
  final cred = Uint8List(sizeOf<sf.UCred>());
  if (sf.getsockopt(fd, sf.SOL_SOCKET, sf.SO_PEERCRED, cred) < 0) return null;
  return ByteData.sublistView(cred).getInt32(0, Endian.host);
}

final class _Session {
  _Session(this._ffi, this._io);

  final FfiFd _ffi;
  final RawSocket _io;

  static _Session? _open;
  static Future<_Session>? _opening;
  static int _users = 0;

  static Future<_Session> acquire() {
    _users++;
    final s = _open;
    if (s != null) return Future.value(s);
    return _opening ??= _connect().then(
      (s) {
        _opening = null;
        _open = s;
        return s;
      },
      onError: (Object e, StackTrace st) {
        _opening = null;
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  static void release() {
    if (--_users > 0) return;
    // Fecha no fim do turno: outra transferência do mesmo turno reaproveita.
    scheduleMicrotask(() {
      final s = _open;
      if (_users > 0 || s == null) return;
      _open = null;
      s._ffi.close();
      unawaited(s._io.close());
    });
  }

  static Future<_Session> _connect() async {
    final pid = sf.getpid();
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 4; attempt++) {
      final tag = List.generate(
        16,
        (_) => rnd.nextInt(16).toRadixString(16),
      ).join();
      final name = '@golib-ffi-bridge-$pid-$tag';
      final l = FfiFd.socket(sf.AF_UNIX, sf.SOCK_STREAM);
      try {
        final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
        int r;
        try {
          r = sf.bind(l.fd, sa, sf.encodeSockaddr(sf.Sockaddr.unix(name), sa));
        } finally {
          sf.libcAlloc.free(sa);
        }
        if (r == -sf.EADDRINUSE) continue;
        if (r < 0) throw FfiErrno('bind', -r);
        r = sf.listen(l.fd, 8);
        if (r < 0) throw FfiErrno('listen', -r);
        final io = await RawSocket.connect(
          InternetAddress(name, type: InternetAddressType.unix),
          0,
        );
        // O `dart:io` também confere quem está do outro lado.
        if (_ioPeerPid(io) != pid) {
          unawaited(io.close());
          throw StateError('ponte FFI: par do dart:io não é este processo');
        }
        // A conexão do `dart:io` já está na fila; outras (de outro
        // processo) são descartadas.
        l.readDeadline = DateTime.now().add(const Duration(seconds: 5));
        try {
          while (true) {
            final (c, _) = await l.accept();
            if (_peerPid(c.fd) == pid) return _Session(c, io);
            c.close();
          }
        } catch (_) {
          unawaited(io.close());
          rethrow;
        }
      } finally {
        l.close();
      }
    }
    throw StateError('ponte FFI: nome abstrato sempre ocupado');
  }

  static int? _ioPeerPid(RawSocket io) {
    try {
      final v = io.getRawOption(
        RawSocketOption(sf.SOL_SOCKET, sf.SO_PEERCRED, Uint8List(12)),
      );
      return ByteData.sublistView(v).getInt32(0, Endian.host);
    } on Object {
      return null;
    }
  }

  /// Manda [fd] por `SCM_RIGHTS` (1 byte de dado) e recebe do lado do
  /// `dart:io`. Síncrono: num par Unix o `sendmsg` já deixa a mensagem na
  /// fila do outro lado.
  RawSocket transfer(int fd) {
    final space = sf.cmsgSpace(4);
    final mem = sf.libcAlloc<Uint8>(
      1 + sizeOf<sf.IoVec>() + sizeOf<sf.MsgHdr>() + space + 32,
    );
    try {
      final data = mem;
      data.value = 0x47; // 'G'
      final iov = Pointer<sf.IoVec>.fromAddress(_align(mem.address + 1));
      iov.ref
        ..base = data.cast()
        ..len = 1;
      final mh = Pointer<sf.MsgHdr>.fromAddress(
        _align(iov.address + sizeOf<sf.IoVec>()),
      );
      final ctl = Pointer<sf.CmsgHdr>.fromAddress(
        _align(mh.address + sizeOf<sf.MsgHdr>()),
      );
      ctl.ref
        ..len = sf.cmsgLen(4)
        ..level = sf.SOL_SOCKET
        ..type = sf.SCM_RIGHTS;
      sf.cmsgData(ctl).cast<Int32>().value = fd;
      mh.ref
        ..name = nullptr
        ..namelen = 0
        ..iov = iov
        ..iovlen = 1
        ..control = ctl.cast()
        ..controllen = space
        ..flags = 0;
      int r;
      do {
        r = sf.sendmsg(_ffi.fd, mh, sf.MSG_NOSIGNAL);
      } while (r == -sf.EINTR);
      if (r < 0) throw FfiErrno('sendmsg', -r);
    } finally {
      sf.libcAlloc.free(mem);
    }
    final m = _io.readMessage(1);
    if (m == null || m.controlMessages.isEmpty) {
      throw StateError('ponte FFI: fd não chegou ao dart:io');
    }
    final handles = [for (final c in m.controlMessages) ...c.extractHandles()];
    if (handles.length != 1) {
      throw StateError('ponte FFI: ${handles.length} fds recebidos');
    }
    return handles.single.toRawSocket();
  }

  static int _align(int a) => (a + 7) & ~7;
}
