/// Descritores virtuais: o número que o `RawConn.Control` passa ao `f`
/// quando o socket não tem um fd que o processo enxergue (conexões do
/// `dart:io`, que não expõe o fd, e do Node). As funções do shim `syscall`
/// que recebem um fd (`SetsockoptInt`, `GetsockoptInt`, `Read`, `Write`)
/// consultam esta tabela antes de ir à libc; o dono do socket responde por
/// ele (o `dart:io` por `setRawOption`/`getRawOption` e, em TCP/Unix de
/// fluxo, lendo e escrevendo no `RawSocket` sem esperar; o Node com
/// `ENOPROTOOPT` nas opções e `EOPNOTSUPP` no resto, F4).
///
/// Os números começam em [vfdBase] (2^30), acima de qualquer fd real do
/// linux (`fs.nr_open` vai até 2^20 por padrão e nunca passa de 2^30 - 64),
/// então nunca colidem com um fd da libc.
///
/// Library interna (sem `dart:ffi`), comum ao shim `syscall` e ao `net`.
library;

import 'dart:typed_data';

/// Quem responde por um descritor virtual. Os métodos devolvem como a libc
/// do `sysffi`: `>= 0` (0 no `set`; o tamanho gravado em [out] no `get`; os
/// bytes lidos ou escritos, 0 na leitura sendo o EOF) ou `-errno`
/// (numeração do linux). [read]/[write] não esperam: `-EAGAIN` sem dado ou
/// sem espaço, como num fd não bloqueante.
abstract interface class VirtualFd {
  int setsockopt(int level, int opt, Uint8List value);
  int getsockopt(int level, int opt, Uint8List out);
  int read(Uint8List buf);
  int write(Uint8List data);
}

/// Primeiro número de descritor virtual.
const vfdBase = 1 << 30;

final _table = <int, VirtualFd>{};
var _next = vfdBase;

/// Registra [owner] e devolve o número dele.
int vfdOpen(VirtualFd owner) {
  while (_table.containsKey(_next)) {
    _next = _next >= vfdBase + (1 << 29) ? vfdBase : _next + 1;
  }
  final fd = _next++;
  _table[fd] = owner;
  return fd;
}

/// Tira [fd] da tabela (o dono fechou).
void vfdClose(int fd) => _table.remove(fd);

/// O dono de [fd], ou `null` se [fd] não é virtual (ou já foi fechado).
VirtualFd? vfdLookup(int fd) => fd >= vfdBase ? _table[fd] : null;
