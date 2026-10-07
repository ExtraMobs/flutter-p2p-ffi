// Ajudantes dos testes da rede FFI (`net_ffi_test.dart`,
// `net_ffi_bridge_test.dart`).
import 'dart:ffi';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/ffi/vm.dart';
import 'package:golib_dart/src/sysffi/sysffi.dart' as sf;
import 'package:test/test.dart';

/// Par Unix de fluxo não bloqueante.
(FfiFd, FfiFd) ffiPair() {
  final sv = sf.libcAlloc<Int32>(2);
  try {
    final r = sf.socketpair(
      sf.AF_UNIX,
      sf.SOCK_STREAM | sf.SOCK_NONBLOCK | sf.SOCK_CLOEXEC,
      0,
      sv,
    );
    if (r < 0) throw FfiErrno('socketpair', -r);
    return (FfiFd.adopt(sv[0]), FfiFd.adopt(sv[1]));
  } finally {
    sf.libcAlloc.free(sv);
  }
}

/// Par em que só uma ponta sobrevive: a outra fica sem referência.
@pragma('vm:never-inline')
FfiFd pairForgettingOne() => ffiPair().$1;

/// Listener TCP do FFI em 127.0.0.1 (porta livre).
FfiFd ffiListen() {
  final l = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
  final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
  try {
    final len = sf.encodeSockaddr(ffiLo(0), sa);
    expect(sf.bind(l.fd, sa, len), 0);
    expect(sf.listen(l.fd, 16), 0);
  } finally {
    sf.libcAlloc.free(sa);
  }
  return l;
}

sf.Sockaddr ffiLo(int port) =>
    sf.Sockaddr.inet(Uint8List.fromList([127, 0, 0, 1]), port);
