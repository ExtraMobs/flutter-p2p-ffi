part of '../../ipfs_ffi.dart';

/// Nó IPFS em memória. Cada chamada bloqueia a isolate até o Go responder.
class IpfsNode {
  IpfsNode._(this._lib, this._handle);

  final _Lib _lib;
  final int _handle;

  /// [online] liga a rede libp2p; [libPath] como em [ipfsRun].
  static IpfsNode start({String? libPath, bool online = false}) {
    final lib = _Lib.open(libPath);
    final h = lib.alloc<Int64>(8);
    try {
      lib.check(lib.start(online ? 1 : 0, h));
      return IpfsNode._(lib, h.value);
    } finally {
      lib.free(h.cast());
    }
  }

  /// Grava [data] como bloco bruto e devolve o CID.
  String add(Uint8List data) {
    final buf = _lib.alloc<Uint8>(data.length);
    final out = _lib.alloc<Pointer<Uint8>>(8);
    try {
      buf.asTypedList(data.length).setAll(0, data);
      _lib.check(_lib.add(_handle, buf, data.length, out));
      return _lib.take(out.value);
    } finally {
      _lib.free(buf.cast());
      _lib.free(out.cast());
    }
  }

  /// Lê o bloco de [cid].
  Uint8List get(String cid) {
    final c = _lib.cstr(cid);
    final out = _lib.alloc<Pointer<Uint8>>(8);
    final len = _lib.alloc<Int32>(4);
    try {
      _lib.check(_lib.get(_handle, c, out, len));
      final data = Uint8List.fromList(out.value.asTypedList(len.value));
      _lib.free(out.value.cast());
      return data;
    } finally {
      for (final p in [c, out, len]) {
        _lib.free(p.cast());
      }
    }
  }

  void stop() => _lib.check(_lib.stop(_handle));
}
