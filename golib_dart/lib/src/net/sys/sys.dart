/// Motor de rede por plataforma (decisão D4): a API Dart simples sobre a
/// qual o shim `net` do Go é escrito.
///
/// - VM/AOT: `dart:io` (`sys_io.dart`).
/// - JS (dart2js) e Wasm (dart2wasm) sob Node: `node:net`, `node:dgram`,
///   `node:dns`, `node:os` por `dart:js_interop` (`sys_js.dart`).
/// - Navegador (mesmo `sys_js.dart`, decidido em runtime): toda operação
///   falha com `SysError(code: 'EOPNOTSUPP')`; não há emulação de TCP.
///
/// Sockets Unix: só de fluxo (`unix`), com o caminho em [SysAddr.unix]
/// ([sysDialUnix], [sysListenUnix], [sysUnlinkUnix]); ⚠️ datagrama e
/// seqpacket (`unixgram`/`unixpacket`) não existem em nenhuma plataforma.
///
/// Os tipos (`SysAddr`, erros, `SysTcpConn`...) estão em `common.dart`.
library;

export 'common.dart';
export 'sys_stub.dart'
    if (dart.library.io) 'sys_io.dart'
    if (dart.library.js_interop) 'sys_js.dart';
