/// Rede FFI da VM (decisão F1): o que o motor `sys_io.dart` usa para o que
/// o `dart:io` não faz (`Control` antes do `bind`, `SyscallConn`, UDP com
/// oob, `unixgram`/`unixpacket`...). Só alcançada por `ffi.dart`
/// (`if (dart.library.ffi)`) ou por outra library da VM que já esteja atrás
/// dessa condição.
///
/// API interna para as etapas seguintes (E2–E7):
///
/// - [FfiFd]: socket não bloqueante da libc com `waitRead`/`waitWrite`,
///   prazos, `io` (repete uma chamada leaf até não dar `EAGAIN`), `read`,
///   `write`, `connect` não bloqueante (`POLLOUT` + `SO_ERROR`), `accept`
///   (`accept4`), `localAddr`/`peerAddr` e `close` síncrono.
/// - [ffiToRawSocket]: conexão de fluxo do FFI → `RawSocket` do `dart:io`.
/// - [FfiErrno]: errno cru; prazo/fechado/cancelado são os `SysTimeout`/
///   `SysClosed`/`SysCanceled` do motor.
/// - `sf.*` (`src/sysffi/sysffi.dart`): libc, constantes e layouts.
library;

import '../../../sysffi/sysffi.dart' show sysFfiSupported;

export '../../../sysffi/sysffi.dart' show Sockaddr, sysFfiSupported;
export 'bridge.dart' show ffiToRawSocket;
export 'errors.dart';
export 'fd.dart';

/// A rede FFI existe neste processo (VM no linux/amd64; F3).
bool get sysFfiAvailable => sysFfiSupported;
