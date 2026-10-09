// Abertura da lib nativa e lookup das funções exportadas pelo Go.
part of '../../ipfs_ffi.dart';

/// Erro devolvido pelo Go: NULL em sucesso, senão a mensagem (liberar com GoFree).
typedef _Err = Pointer<Uint8>;

final class _Lib {
  /// [libPath] padrão: `native/libipfs.so` ou `native\ipfs.dll` relativo ao
  /// diretório atual.
  factory _Lib.open(String? libPath) => _Lib(
    DynamicLibrary.open(
      libPath ??
          (Platform.isWindows ? r'native\ipfs.dll' : 'native/libipfs.so'),
    ),
  );

  _Lib(DynamicLibrary l)
    : run = l
          .lookupFunction<
            Int32 Function(Int32, Pointer<Pointer<Uint8>>),
            int Function(int, Pointer<Pointer<Uint8>>)
          >('IpfsRun'),
      start = l
          .lookupFunction<
            _Err Function(Int32, Pointer<Int64>),
            _Err Function(int, Pointer<Int64>)
          >('IpfsStart'),
      add = l
          .lookupFunction<
            _Err Function(
              Int64,
              Pointer<Uint8>,
              Int32,
              Pointer<Pointer<Uint8>>,
            ),
            _Err Function(int, Pointer<Uint8>, int, Pointer<Pointer<Uint8>>)
          >('IpfsAdd'),
      get = l
          .lookupFunction<
            _Err Function(
              Int64,
              Pointer<Uint8>,
              Pointer<Pointer<Uint8>>,
              Pointer<Int32>,
            ),
            _Err Function(
              int,
              Pointer<Uint8>,
              Pointer<Pointer<Uint8>>,
              Pointer<Int32>,
            )
          >('IpfsGet'),
      stop = l.lookupFunction<_Err Function(Int64), _Err Function(int)>(
        'IpfsStop',
      ),
      malloc = l
          .lookupFunction<
            Pointer<Void> Function(Size),
            Pointer<Void> Function(int)
          >('GoMalloc'),
      free = l
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('GoFree');

  final int Function(int, Pointer<Pointer<Uint8>>) run;
  final _Err Function(int, Pointer<Int64>) start;
  final _Err Function(int, Pointer<Uint8>, int, Pointer<Pointer<Uint8>>) add;
  final _Err Function(
    int,
    Pointer<Uint8>,
    Pointer<Pointer<Uint8>>,
    Pointer<Int32>,
  )
  get;
  final _Err Function(int) stop;
  final Pointer<Void> Function(int) malloc;
  final void Function(Pointer<Void>) free;
}
