# ipfs_ffi

Kubo v0.43.1 (IPFS em Go) compilado com `-buildmode=c-shared` e usado do
Dart por `dart:ffi`. Alternativa à transpilação: o Go roda nativo dentro do
processo Dart (VM/AOT no linux e no Windows; não serve para JS/Wasm).

- `go/main.go`: API C — `IpfsStart`/`IpfsAdd`/`IpfsGet`/`IpfsStop` (nó em
  memória), `IpfsRun` (CLI completo do kubo: `init`, `daemon`, ...),
  `GoMalloc`/`GoFree`.
- `native/`: `libipfs.so` (linux/amd64) e `ipfs.dll` (windows/amd64), fora do
  git; gere com o `tool/build.dart` antes de usar.
- `dart run tool/build.dart [linux|windows]`: recompila `native/`. Exige Go
  1.26.5 (`GOTOOLCHAIN=auto` baixa) e um gcc para o cgo: no Windows, o
  mingw-w64 no PATH (ex. `winget install BrechtSanders.WinLibs.POSIX.UCRT`);
  no linux, `x86_64-w64-mingw32-gcc` para a DLL.
- `lib/ipfs_ffi.dart` (partes em `lib/src/ipfs_ffi/`: `native` abre a lib,
  `memory` aloca com `GoMalloc`/`GoFree`, `node`, `run`, `daemon`): `IpfsNode` (nó em memória), `ipfsRun` (CLI) e
  `IpfsDaemon` (daemon com repo em disco, rede, API RPC e gateway).

```dart
final node = IpfsNode.start();           // nó em memória, offline
final cid = node.add(utf8.encode('oi')); // bloco bruto -> CID
print(node.get(cid));
node.stop();

final daemon = await IpfsDaemon.start('.ipfs');  // init na 1ª vez
print(await daemon.rpc('id'));                     // POST /api/v0/id
await daemon.stop();
```

Daemon completo: `dart run example/daemon.dart [repo]` (Ctrl-C para).
Testes: `dart test` nesta pasta.

Limites: um daemon por processo (o kubo usa métricas globais); `ipfsRun`
uma chamada por vez enquanto o kubo lê os argumentos; a config de plugins do
primeiro repo vale para o processo todo.
