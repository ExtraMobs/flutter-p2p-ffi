part of '../../syscall.dart';

// `syscall.RawConn` e `syscall.Conn` (`net.go` do Go 1.26.5).

/// `syscall.RawConn`: acesso ao descritor de uma conexão. `Read`/`Write`
/// esperam o descritor ficar pronto, então suspendem (`ASYNC_IFACE_METHODS`
/// em `g2d/services/dualio.py`); o callback `f` é síncrono. ⚠️ Nenhum
/// tipo do shim implementa ainda: o `SyscallConn` das conexões devolve erro.
abstract interface class RawConn {
  /// `Control(f)`: chama `f(fd)` sem esperar.
  GoError? control(void Function(Golang.Uintptr fd)? f);

  /// `Read(f)`: chama `f(fd)` até devolver `true`, esperando leitura.
  Future<GoError?> read(bool Function(Golang.Uintptr fd)? f);

  /// `Write(f)`: chama `f(fd)` até devolver `true`, esperando escrita.
  Future<GoError?> write(bool Function(Golang.Uintptr fd)? f);
}

/// `syscall.Conn`: o que tem `SyscallConn()`.
abstract interface class Conn {
  (RawConn?, GoError?) syscallConn();
}
