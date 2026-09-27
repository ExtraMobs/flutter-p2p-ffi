/// Shim do pacote Go `io/fs` (parcial: `FileMode`, `PathError`, `FileInfo`,
/// `DirEntry` e os erros sentinela; `FS`/`WalkDir`/`ReadFile`/`Sub` ficam de
/// fora — dependem de um `fs.FS` genérico, raro no grafo).
///
/// `os.FileMode`, `os.PathError`, `os.FileInfo` e `os.DirEntry` são apelidos
/// Go (`type X = fs.X`) para os tipos daqui: o `go/types` resolve a
/// identidade do tipo para este pacote (`io/fs`), não para `os`, então o g2d
/// qualifica `os.FileMode` como `fs.FileMode` deste shim. O shim `os`
/// importa este arquivo e reexporta só os identificadores que o Go declara
/// de fato no pacote `os` (as constantes `os.ModeDir`... e os erros
/// `os.ErrNotExist`..., que são `var`/`const` próprios do pacote `os`,
/// não apelidos).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' show Stringer;

/// `fs.ErrInvalid` (`os.ErrInvalid` é a mesma instância).
final GoError errInvalid = ErrorString(Golang.String.fromDart('invalid argument'));

/// `fs.ErrPermission`.
final GoError errPermission = ErrorString(Golang.String.fromDart('permission denied'));

/// `fs.ErrExist`.
final GoError errExist = ErrorString(Golang.String.fromDart('file already exists'));

/// `fs.ErrNotExist`.
final GoError errNotExist = ErrorString(Golang.String.fromDart('file does not exist'));

/// `fs.ErrClosed`.
final GoError errClosed = ErrorString(Golang.String.fromDart('file already closed'));

/// `fs.FileMode`: os 32 bits têm o mesmo layout em todo sistema (porta de
/// `io/fs/fs.go` do Go 1.26); tipo nomeado sobre `uint32`, mesma forma das
/// classes que o g2d gera para `type N uint32`.
final class FileMode extends Golang.Uint32Base<FileMode> implements Stringer {
  FileMode([int v = 0]) : super(v);
  FileMode.from(Golang.IntBase v) : super.from(v);
  FileMode.fromBigInt(BigInt v) : super.fromBigInt(v);

  @override
  FileMode $make(int v) => FileMode(v);

  // `%T`/reflexão do Go resolvem o apelido `os.FileMode` para este tipo.
  @override
  String get $goType => 'fs.FileMode';

  @override
  List<String> get $methods => const ['IsDir', 'IsRegular', 'Perm', 'String', 'Type'];

  /// `IsDir()`.
  bool isDir() => (this & modeDir).toInt() != 0;

  /// `IsRegular()`.
  bool isRegular() => (this & modeType).toInt() == 0;

  /// `Perm()`.
  FileMode perm() => this & modePerm;

  /// `Type()`.
  FileMode type() => this & modeType;

  /// `String()`: `drwxr-xr-x`, `-rw-------`, `Lrwxrwxrwx`... como o Go.
  @override
  Golang.String string() {
    const letters = 'dalTLDpSugct?';
    final v = toInt();
    final buf = <int>[];
    for (var i = 0; i < letters.length; i++) {
      if (v & (1 << (32 - 1 - i)) != 0) buf.add(letters.codeUnitAt(i));
    }
    if (buf.isEmpty) buf.add(0x2d); // '-'
    const rwx = 'rwxrwxrwx';
    for (var i = 0; i < rwx.length; i++) {
      buf.add(v & (1 << (9 - 1 - i)) != 0 ? rwx.codeUnitAt(i) : 0x2d);
    }
    return Golang.String.fromBytes(Uint8List.fromList(buf));
  }
}

/// `fs.ModeDir`: é um diretório.
final FileMode modeDir = FileMode(1 << 31);

/// `fs.ModeAppend`: append-only.
final FileMode modeAppend = FileMode(1 << 30);

/// `fs.ModeExclusive`: uso exclusivo.
final FileMode modeExclusive = FileMode(1 << 29);

/// `fs.ModeTemporary`: arquivo temporário (só Plan 9).
final FileMode modeTemporary = FileMode(1 << 28);

/// `fs.ModeSymlink`: link simbólico.
final FileMode modeSymlink = FileMode(1 << 27);

/// `fs.ModeDevice`: arquivo de dispositivo.
final FileMode modeDevice = FileMode(1 << 26);

/// `fs.ModeNamedPipe`: pipe nomeado (FIFO).
final FileMode modeNamedPipe = FileMode(1 << 25);

/// `fs.ModeSocket`: socket de domínio Unix.
final FileMode modeSocket = FileMode(1 << 24);

/// `fs.ModeSetuid`.
final FileMode modeSetuid = FileMode(1 << 23);

/// `fs.ModeSetgid`.
final FileMode modeSetgid = FileMode(1 << 22);

/// `fs.ModeCharDevice`: dispositivo de caracteres (com `ModeDevice`).
final FileMode modeCharDevice = FileMode(1 << 21);

/// `fs.ModeSticky`.
final FileMode modeSticky = FileMode(1 << 20);

/// `fs.ModeIrregular`: nada mais se sabe sobre o arquivo.
final FileMode modeIrregular = FileMode(1 << 19);

/// `fs.ModeType`: máscara dos bits de tipo.
final FileMode modeType = modeDir | modeSymlink | modeNamedPipe | modeSocket | modeDevice | modeCharDevice | modeIrregular;

/// `fs.ModePerm`: bits de permissão Unix, `0o777`.
final FileMode modePerm = FileMode(0x1ff);

/// `fs.FileInfo` (`os.FileInfo` é o mesmo tipo). `ModTime` fica de fora:
/// ⚠️ ponytail — depende de `time.Time`, ainda sem shim (`docs/mapping-spec.md`).
abstract interface class FileInfo {
  Golang.String name();
  Golang.Int64 size();
  FileMode mode();
  bool isDir();
  Object? sys();
}

/// `fs.DirEntry` (`os.DirEntry` é o mesmo tipo).
abstract interface class DirEntry {
  Golang.String name();
  bool isDir();
  FileMode type();
  (FileInfo, GoError?) info();
}

/// `fs.PathError` (`os.PathError` é o mesmo tipo: alias Go, mesma
/// identidade de tipo para `go/types`, então o g2d qualifica `os.PathError`
/// como `fs.PathError` deste shim).
final class PathError extends GoStruct<PathError> implements GoError, Unwrapper, Timeouter, Golang.GoTyped {
  PathError({Golang.String? op, Golang.String? path, GoError? err})
    : op = op ?? Golang.String(),
      path = path ?? Golang.String(),
      err = err;

  /// `(*PathError)(nil)` dentro de uma interface (não é nil no Go).
  static final PathError $nil = PathError()..$nilPtr = true;

  Golang.String op;
  Golang.String path;
  GoError? err;

  @override
  String get $goType => 'fs.PathError';

  @override
  List<String> get $valueMethods => const [];

  @override
  List<String> get $ptrMethods => const ['Error', 'Timeout', 'Unwrap'];

  @override
  PathError $copy() => PathError(op: op, path: path, err: err);

  @override
  void $set(PathError o) {
    op = o.op;
    path = o.path;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [op, path, err];

  @override
  List<String> get $fieldNames => const ['Op', 'Path', 'Err'];

  /// `Error()`: `op path: err`.
  Golang.String error() =>
      op + Golang.String.fromDart(' ') + path + Golang.String.fromDart(': ') + err!.error();

  /// `Unwrap() error`.
  GoError? unwrap() => err;

  /// `Timeout()`.
  @override
  bool timeout() {
    final e = err;
    return e is Timeouter && goHasMethod(e, 'Timeout') && e.timeout();
  }
}
