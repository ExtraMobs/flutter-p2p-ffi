/// Motor de rede por plataforma (decisão D4): a API Dart simples sobre a
/// qual o shim `net` do Go é escrito.
///
/// - VM/AOT: `dart:io` (`sys_io.dart`).
/// - JS (dart2js) e Wasm (dart2wasm) sob Node: `node:net`, `node:dgram`,
///   `node:dns`, `node:os` por `dart:js_interop` (`sys_js.dart`).
/// - Navegador (mesmo `sys_js.dart`, decidido em runtime): toda operação
///   falha com `SysError(code: 'EOPNOTSUPP')`; não há emulação de TCP.
///
/// Sockets Unix de fluxo pela plataforma ([sysDialUnix], [sysListenUnix],
/// [sysUnlinkUnix], caminho em [SysAddr.unix]). Socket genérico do Go
/// ([sysSocket]: `unix`/`unixgram`/`unixpacket`, IP bruto) só com
/// [sysSockSupported] (rede FFI, VM no linux); ⚠️ sem ela, `unixgram`,
/// `unixpacket` e IP bruto dão `EOPNOTSUPP`.
///
/// Os tipos (`SysAddr`, erros, `SysTcpConn`...) estão em `common.dart`.
///
/// Rede FFI (VM no linux, F1): `ffi/ffi.dart`, só por import condicional
/// `if (dart.library.ffi)`; o dart2js e o dart2wasm ficam com o stub e nunca
/// veem `dart:ffi`. Por ora só [sysFfiAvailable] sai daqui; o poller, o
/// `FfiFd` e a ponte para o `dart:io` estão em `ffi/vm.dart`.
library;

export 'common.dart';
export 'ffi/ffi.dart' show sysFfiAvailable;
export 'sys_stub.dart'
    if (dart.library.io) 'sys_io.dart'
    if (dart.library.js_interop) 'sys_js.dart';
