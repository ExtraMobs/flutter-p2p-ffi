/// Shim do pacote Go `syscall` (parcial, sem chamada de sistema): o tipo
/// `Errno` com a numeração e os textos do linux em toda plataforma (o build
/// do g2d é `GOOS=linux GOARCH=amd64`), as constantes de errno e de rede
/// (`AF_*`, `SOCK_*`, `SOL_*`, `SO_*`, `IPPROTO_*`, `IP_*`, `IPV6_*`,
/// `TCP_*`, `MSG_*`, `SCM_*`, `SOMAXCONN`) e as interfaces `RawConn` e
/// `Conn`.
///
/// Funções que fazem syscall (pela libc do `sysffi` na VM no linux, F1):
/// `SetsockoptInt`, `GetsockoptInt`, `Read`, `Write`, `Socketpair` e
/// `Close` (`src/syscall/sockets.dart`; no Node, falham como o Go em
/// js/wasm, F4). ⚠️ As outras (`Socket`, `Bind`...) viram `Unsupported`
/// `shim-simbolo:syscall.*` no código gerado; os outros tipos e constantes
/// (`Stat_t`, `Signal`, `O_*`...) também não estão aqui.
///
/// As constantes o g2d dobra no literal (`syscall.Errno(111)`, o número);
/// as daqui servem aos shims escritos à mão (`net`, `os`).
// ignore_for_file: library_prefixes, constant_identifier_names, non_constant_identifier_names
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'errors.dart' as errors;
import 'fixed_types/golang.dart' as Golang;
import 'io/fs.dart' as fs;
import 'src/syscall/errno_table.dart';
import 'src/syscall/sys/sys.dart' as sys;
import 'src/syscall/vfd.dart' as vfd;

part 'src/syscall/errno.dart';
part 'src/syscall/consts_linux_amd64.dart';
part 'src/syscall/rawconn.dart';
part 'src/syscall/sockets.dart';
