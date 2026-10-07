/// Alocador de memória nativa sobre `calloc`/`free` da libc, sem
/// `package:ffi` (decisão F1: nenhuma dependência nova).
///
/// Para buffers de dados, prefira passar o próprio `Uint8List` às chamadas
/// leaf com `TypedData.address` (ver `libc.dart`): não copia nem aloca.
/// Este alocador serve às structs (`sockaddr`, `msghdr`, `pollfd`...).
library;

import 'dart:ffi';

@Native<Pointer<Void> Function(Size, Size)>(symbol: 'calloc', isLeaf: true)
external Pointer<Void> _calloc(int n, int size);

@Native<Void Function(Pointer<Void>)>(symbol: 'free', isLeaf: true)
external void _free(Pointer<Void> p);

/// `calloc`/`free` como [Allocator]: a memória nasce zerada.
final class LibcAllocator implements Allocator {
  const LibcAllocator();

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    // O `calloc` alinha a 16 no linux/amd64, o bastante para toda struct
    // de socket.
    final p = _calloc(1, byteCount <= 0 ? 1 : byteCount);
    if (p.address == 0) throw StateError('calloc($byteCount): sem memória');
    return p.cast();
  }

  @override
  void free(Pointer<NativeType> pointer) => _free(pointer.cast());
}

/// O alocador do `sysffi`.
const libcAlloc = LibcAllocator();

/// Roda [body] com [byteCount] bytes zerados e libera na saída (inclusive em
/// exceção). Útil para structs de vida curta em volta de uma chamada.
R withNative<T extends NativeType, R>(
  int byteCount,
  R Function(Pointer<T> p) body,
) {
  final p = libcAlloc.allocate<T>(byteCount);
  try {
    return body(p);
  } finally {
    libcAlloc.free(p);
  }
}
