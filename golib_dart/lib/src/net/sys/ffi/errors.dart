/// Falha de syscall da rede FFI, com o errno cru (numeração do linux).
///
/// Prazo, fechamento e cancelamento usam os erros comuns do motor
/// (`SysTimeout`, `SysClosed`, `SysCanceled`, de `common.dart`); quem liga o
/// FFI ao shim `net` (E2–E7) converte [FfiErrno] para o `syscall.Errno` do
/// shim `syscall` (`os.SyscallError` do Go: `connect: connection refused`).
library;

final class FfiErrno implements Exception {
  const FfiErrno(this.syscall, this.errno, {this.written = 0});

  /// Nome da syscall no vocabulário do Go (`connect`, `accept`, `read`...).
  final String syscall;

  /// errno do linux (`ECONNREFUSED` = 111...).
  final int errno;

  /// Quanto um `write` já tinha entregue quando falhou.
  final int written;

  @override
  String toString() => '$syscall: errno $errno';
}
