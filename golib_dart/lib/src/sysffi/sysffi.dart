/// Acesso à libc por `dart:ffi` (decisão F1): o único diretório, junto das
/// libraries da VM que o usam (`src/net/sys/ffi/`), onde `dart:ffi` entra.
///
/// Só é alcançado por import condicional `if (dart.library.ffi)`: o dart2js
/// e o dart2wasm recusam `dart:ffi`, e com o import condicional escolhem o
/// stub. Nunca importe isto de uma library comum a todas as plataformas.
///
/// Serve à rede (poller e ponte em `src/net/sys/ffi/`), e depois ao shim
/// `syscall`, ao `x/sys/unix` (D5) e ao `Fd()` (D3).
///
/// Plataformas (F3): só linux/amd64 por enquanto ([sysFfiSupported]); as
/// constantes e os layouts ficam em `consts_linux.dart` e
/// `structs_linux.dart`. O macOS (E8) entra com `*_darwin.dart` de mesma API
/// e a escolha por [Abi] aqui.
library;

import 'dart:ffi';

export 'alloc.dart';
export 'consts_linux.dart';
export 'libc.dart';
export 'structs_linux.dart';

/// As constantes e layouts desta library valem para o processo atual.
final bool sysFfiSupported = Abi.current() == Abi.linuxX64;
