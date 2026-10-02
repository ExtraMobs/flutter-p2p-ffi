/// Shim do pacote Go `os` (primeiro recorte: o que se comporta igual em VM,
/// AOT, JS e Wasm).
///
/// Dentro: ambiente (`Getenv`, `LookupEnv`), `Exit`, `Getpid`, `Args`,
/// `Stdin`/`Stdout`/`Stderr` como `*File` (`Write`, `WriteString`, `Close`,
/// `Name`, `Fd`), os erros sentinela, `IsNotExist`/`IsExist`/`IsPermission`/
/// `IsTimeout`, `PathError` (alias de `io/fs.PathError`, que vive em `io/fs.dart`) e
/// `FileMode`. Fora, de propósito: o sistema de arquivos (`Open`, `ReadFile`,
/// `Stat`...), que exige `dart:io` por import condicional e uma decisão
/// (`TODO/P0-design-os-arquivos.md`); esses símbolos seguem `Unsupported`
/// `shim-simbolo:os.*`.
///
/// Limites por plataforma: `Getenv` no JS/Wasm sem Node (navegador) devolve
/// `""` e `LookupEnv` `false`; `Args` é só `[nome do programa]` (o shim não
/// vê os argumentos do `main` Dart); `File.Read` em `Stdin` não existe.
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'io.dart' as io;
import 'io/fs.dart' as fs;
import 'src/runtime/output.dart' as out;

part 'src/os/errors.dart';
part 'src/os/file.dart';

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);

/// `os.Args`: só o nome do programa.
Slice<Golang.String> args = Slice.of([
  Golang.String.fromDart('main'),
], _strElem);

/// `os.LookupEnv(key)`.
(Golang.String, bool) lookupEnv(Golang.String key) {
  final v = out.getEnv(key.toString());
  return v == null
      ? (Golang.String(), false)
      : (Golang.String.fromDart(v), true);
}

/// `os.Getenv(key)`: `""` se não definida.
Golang.String getenv(Golang.String key) => lookupEnv(key).$1;

/// `os.Getpid()`.
Golang.Int getpid() => Golang.Int(out.getPid());

/// `os.Exit(code)`: encerra sem rodar `defer`.
void exit(Golang.Int code) => out.exitProcess(code.toInt());
