/// Sem `dart:ffi` (dart2js, dart2wasm): não há rede FFI.
///
/// É também o que a análise estática enxerga em `ffi.dart`: o que as etapas
/// seguintes expuserem por lá precisa existir aqui com a mesma assinatura
/// (só com tipos de `common.dart`), falhando como o Go em js/wasm (F4).
library;

import '../common.dart';

/// A rede FFI existe neste processo: nunca, aqui.
bool get sysFfiAvailable => false;

/// `socket()` do Go (`sock.dart` na VM): aqui, `socket: operation not
/// supported`.
Future<SysSock> ffiSocket({
  required int family,
  required int sotype,
  int proto = 0,
  bool ipv6only = false,
  SysAddr? laddr,
  SysAddr? raddr,
  int backlog = 4096,
  DateTime? deadline,
  Future<void>? cancel,
}) async => throw SysError.unsupported('socket');

/// `supportsIPv4map` do Go: sem rede FFI, não.
bool ffiSupportsIPv4map() => false;
