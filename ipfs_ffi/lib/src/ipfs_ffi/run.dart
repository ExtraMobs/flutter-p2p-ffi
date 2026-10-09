part of '../../ipfs_ffi.dart';

/// Roda o CLI do kubo dentro do processo, como `ipfs [args]`, e devolve o
/// código de saída. Bloqueia a isolate até o comando terminar: rode o
/// `daemon` com `Isolate.run`. Uma chamada por vez (o kubo lê `os.Args`).
///
/// [libPath] padrão: `native/libipfs.so` ou `native\ipfs.dll` relativo ao
/// diretório atual.
int ipfsRun(List<String> args, {String? libPath}) {
  final lib = _Lib.open(libPath);
  final argv = lib.alloc<Pointer<Uint8>>(8 * args.length);
  for (var i = 0; i < args.length; i++) {
    argv[i] = lib.cstr(args[i]);
  }
  try {
    return lib.run(args.length, argv);
  } finally {
    for (var i = 0; i < args.length; i++) {
      lib.free(argv[i].cast());
    }
    lib.free(argv.cast());
  }
}
