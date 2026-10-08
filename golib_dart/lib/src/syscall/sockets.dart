part of '../../syscall.dart';

// Chamadas de sistema sobre descritores (porta de `syscall_unix.go`,
// `syscall_linux.go` e `zsyscall_linux_amd64.go` do Go 1.26.5), pela libc
// do `sysffi` na VM no linux (`src/syscall/sys/`).
//
// Descritor virtual (`src/syscall/vfd.dart`: o que o `RawConn.Control` de
// uma conexão do `dart:io` ou do Node passa ao `f`): as opções vão ao dono
// do socket (opções; `Read`/`Write` sem esperar num TCP/Unix de fluxo do
// `dart:io`). ⚠️ No Node (e no navegador) não há descritor real (F4): as
// opções de socket dão `ENOPROTOOPT`, e `Read`, `Write`, `Socketpair` e
// `Close`, `EOPNOTSUPP`.

/// `-errno` → o `Errno` (nil em `r >= 0`).
GoError? _errOf(int r) => r < 0 ? Errno(-r) : null;

/// `SetsockoptInt(fd, level, opt, value)`: o valor vai como `int32`.
GoError? setsockoptInt(
  Golang.Int fd,
  Golang.Int level,
  Golang.Int opt,
  Golang.Int value,
) {
  final v = Uint8List(4);
  ByteData.sublistView(v).setInt32(0, value.toInt(), Endian.host);
  return _errOf(_setsockopt(fd.toInt(), level.toInt(), opt.toInt(), v));
}

/// `GetsockoptInt(fd, level, opt)`: lê um `int32` (0 se falhar).
(Golang.Int, GoError?) getsockoptInt(
  Golang.Int fd,
  Golang.Int level,
  Golang.Int opt,
) {
  final v = Uint8List(4);
  final r = _getsockopt(fd.toInt(), level.toInt(), opt.toInt(), v);
  return (
    Golang.Int(ByteData.sublistView(v).getInt32(0, Endian.host)),
    _errOf(r),
  );
}

int _setsockopt(int fd, int level, int opt, Uint8List v) {
  if (fd >= vfd.vfdBase) {
    final owner = vfd.vfdLookup(fd);
    return owner == null ? -9 : owner.setsockopt(level, opt, v);
  }
  return sys.sysSetsockopt(fd, level, opt, v);
}

int _getsockopt(int fd, int level, int opt, Uint8List out) {
  if (fd >= vfd.vfdBase) {
    final owner = vfd.vfdLookup(fd);
    return owner == null ? -9 : owner.getsockopt(level, opt, out);
  }
  return sys.sysGetsockopt(fd, level, opt, out);
}

/// `Read(fd, p)`: `-1` e o errno na falha (o `r0` do Go). ⚠️ Num fd
/// bloqueante, a espera segura o isolate (ver `src/syscall/sys/vm.dart`).
(Golang.Int, GoError?) read(Golang.Int fd, Slice<Golang.Uint8> p) {
  final buf = Uint8List(p.length);
  final r = fd.toInt() >= vfd.vfdBase
      ? (vfd.vfdLookup(fd.toInt())?.read(buf) ?? -9)
      : sys.sysRead(fd.toInt(), buf);
  if (r < 0) return (Golang.Int(-1), Errno(-r));
  for (var i = 0; i < r; i++) {
    p[i] = Golang.Uint8(buf[i]);
  }
  return (Golang.Int(r), null);
}

/// `Write(fd, p)`: `-1` e o errno na falha.
(Golang.Int, GoError?) write(Golang.Int fd, Slice<Golang.Uint8> p) {
  final buf = Uint8List(p.length);
  for (var i = 0; i < buf.length; i++) {
    buf[i] = p[i].toInt();
  }
  final r = fd.toInt() >= vfd.vfdBase
      ? (vfd.vfdLookup(fd.toInt())?.write(buf) ?? -9)
      : sys.sysWrite(fd.toInt(), buf);
  if (r < 0) return (Golang.Int(-1), Errno(-r));
  return (Golang.Int(r), null);
}

/// `Socketpair(domain, typ, proto)`: `[0 0]` na falha.
(GoArray<Golang.Int>, GoError?) socketpair(
  Golang.Int domain,
  Golang.Int typ,
  Golang.Int proto,
) {
  final out = Int32List(2);
  final r = sys.sysSocketpair(domain.toInt(), typ.toInt(), proto.toInt(), out);
  if (r < 0) return (GoArray<Golang.Int>.zero(2, _intElem), Errno(-r));
  return (
    GoArray<Golang.Int>.of([Golang.Int(out[0]), Golang.Int(out[1])], _intElem),
    null,
  );
}

/// `Close(fd)`.
GoError? close(Golang.Int fd) {
  if (fd.toInt() >= vfd.vfdBase) return Errno(9); // não é deste processo
  return _errOf(sys.sysClose(fd.toInt()));
}
