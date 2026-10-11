# ipfs_ffi

Kubo v0.43.1 (IPFS em Go) compilado com `-buildmode=c-shared` e usado do
Dart por `dart:ffi`: o nó roda nativo dentro do processo Dart, sem HTTP.
Alvos: VM/AOT no Windows e no linux (não serve para JS/Wasm).

A API Dart é a do próprio Go, gerada: uma library por pacote Go, sem o
prefixo `github.com/<org>/` (`kubo/core.dart`, `boxo/files.dart`...). O que
existe, e o que ficou de fora com o motivo, está no [`API.md`](API.md).

```dart
import 'dart:convert';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

final plugins = loader.PluginLoader('')..initialize()..inject(); // 1x por processo
final ctx = context.background();
final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open('.ipfs-ffi')));
final api = coreapi.newCoreApi(n);
final p = await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('oi')));
print(utf8.decode(io.readAll(files.toFile(await api.unixfs().get(ctx, p)))));
await n.close();
```

Exemplos, na ordem em que o kubo monta um nó:

1. `dart run example/01_init_repo.dart [repo]`: `ipfs init` (plugins, identidade, config, repo);
2. `dart run example/02_add_get.dart [repo] [arquivo-ou-pasta]`: nó sem HTTP, `add`/`get`/`ls`;
3. `dart run example/03_pins_gc.dart [repo]`: pins, blocos crus e GC (`ipfs pin`,
   `ipfs block`, `ipfs repo gc`). A CoreAPI não pina por padrão: passe
   `options.unixfs.pin(true, nome)` no `add` (o `ipfs add` do CLI faz isso).

## Como o Go vira Dart

- `context.Context` é o 1º parâmetro, como no Go (`package:ipfs_ffi/context.dart`:
  `background`, `withCancel`, `withTimeout`, `withDeadline`; `cancel()`).
- Função ou método com `context` é assíncrono (`Future`); canal vira `Stream`;
  `(T, error)` vira `T` com `IpfsException` (inclusive em panic do Go).
- Opções funcionais espelham as variáveis do Go:
  `[options.unixfs.cidVersion(1), options.unixfs.rawLeaves(true)]`.
- Objetos com estado ficam no Go (handle solto por `NativeFinalizer`); o nó e
  o repo continuam exigindo o `close` do Go. CID, path, peer e multiaddr são
  valores (a string); `config.Config` guarda o JSON do kubo em `json`.

## Gerar e compilar

- `dart run tool/build.dart [linux|windows]`: roda o gerador (`go run ./gen` em
  `go/`) e compila `native/` (`libipfs.so`, `ipfs.dll`; fora do git). Exige Go
  1.26.5 (`GOTOOLCHAIN=auto` baixa) e um gcc para o cgo: no Windows, o
  mingw-w64 no PATH (ex. `winget install BrechtSanders.WinLibs.POSIX.UCRT`);
  no linux, `x86_64-w64-mingw32-gcc` para a DLL.
- Para expor mais do kubo/boxo: acrescente o símbolo em `go/gen/roots.txt`
  (`pacote.Função` ou `pacote.Tipo.Método`) e rode o build. O que o gerador
  não exprime vai à mão em `go/runtime.go` e `go/gen/extra/<library>.extra`.
- `go run ./gen -check` (em `go/`) falha se os arquivos gerados estão
  desatualizados.
- Testes: `dart test` nesta pasta.

Limites: os plugins do kubo são injetados uma vez por processo; um panic em
goroutine interna do kubo (fora da chamada) ainda derruba o processo.
