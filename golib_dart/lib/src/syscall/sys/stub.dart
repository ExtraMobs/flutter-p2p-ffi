/// Sem `dart:ffi` (dart2js, dart2wasm): nenhum descritor do processo está
/// ao alcance (F4). Opções de socket dão `ENOPROTOOPT`; o resto,
/// `EOPNOTSUPP` (`operation not supported`).
///
/// É também o que a análise estática enxerga em `sys.dart`: `vm.dart` tem
/// a mesma API.
library;

import 'dart:typed_data';

const _enoprotoopt = 92;
const _eopnotsupp = 95;

int sysSetsockopt(int fd, int level, int opt, Uint8List value) =>
    -_enoprotoopt;

int sysGetsockopt(int fd, int level, int opt, Uint8List out) => -_enoprotoopt;

int sysRead(int fd, Uint8List buf) => -_eopnotsupp;

int sysWrite(int fd, Uint8List data) => -_eopnotsupp;

int sysSocketpair(int domain, int type, int proto, Int32List out) =>
    -_eopnotsupp;

int sysClose(int fd) => -_eopnotsupp;
