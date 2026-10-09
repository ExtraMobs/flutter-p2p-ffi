part of '../../ipfs_ffi.dart';

/// Memória C compartilhada com o Go: tudo é alocado com `GoMalloc` e
/// liberado com `GoFree`, o mesmo allocator da lib.
extension on _Lib {
  Pointer<T> alloc<T extends NativeType>(int size) {
    final p = malloc(size == 0 ? 1 : size);
    if (p == nullptr) throw IpfsException('GoMalloc falhou');
    return p.cast();
  }

  /// Lê e libera uma string C devolvida pela lib.
  String take(Pointer<Uint8> p) {
    var n = 0;
    while (p[n] != 0) {
      n++;
    }
    final s = utf8.decode(p.asTypedList(n));
    free(p.cast());
    return s;
  }

  /// String C (UTF-8, terminada em 0) liberada com [free].
  Pointer<Uint8> cstr(String s) {
    final b = utf8.encode(s);
    final p = alloc<Uint8>(b.length + 1);
    p.asTypedList(b.length + 1)
      ..setAll(0, b)
      ..[b.length] = 0;
    return p;
  }

  void check(_Err e) {
    if (e != nullptr) throw IpfsException(take(e));
  }
}
