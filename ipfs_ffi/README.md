# ipfs_ffi

Kubo v0.43.1 (IPFS em Go) compilado com `-buildmode=c-shared` e usado do
Dart por `dart:ffi`: o nó roda nativo dentro do processo Dart, sem HTTP.
Alvos: VM/AOT no Windows, no linux e no Android (não serve para JS/Wasm).

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
2. `dart run example/02_add_get.dart [repo] [arquivo-ou-pasta]`: nó sem HTTP, `add`/`get`/`ls`,
   com o progresso do `add` (`options.unixfs.events(controller.sink)` + `progress(true)`:
   eventos `AddEvent` com os `bytes` de cada arquivo e, no fim, o `path`);
3. `dart run example/03_pins_gc.dart [repo]`: pins, blocos crus e GC (`ipfs pin`,
   `ipfs block`, `ipfs repo gc`). A CoreAPI não pina por padrão: passe
   `options.unixfs.pin(true, nome)` no `add` (o `ipfs add` do CLI faz isso);
4. `dart run example/04_online.dart [repo] [segundos] [cid]`: o nó na rede pública,
   como o `ipfs daemon` sem HTTP; o roteamento sai do `Routing.Type` da config como
   no `daemon.go` (`libp2p.constructDefaultRouting(cfg, libp2p.dhtOption)`...).
   Inicialize o repo com `randomports` se a 4001 estiver ocupada (IPFS Desktop);
5. `dart run example/05_two_nodes.dart`: dois nós no mesmo processo; B conecta em A
   (`swarm().connect`), acha A como provedor (`routing().findProviders`) e lê por
   bitswap. O `routing().provide` do kubo 0.43 só enfileira o anúncio: quem busca
   logo em seguida pode precisar repetir;
6. `dart run example/06_ipns_dag.dart [repo]`: IPNS (`name().publish/resolve`), chaves
   (`key().generate/sign/verify`), nós IPLD dag-pb/raw (`merkledag`, `dag().add/get`) e
   DAG-CBOR/JSON (`package:ipfs_ffi/kubo/core/commands/dag.dart`: `dag.put`/`dag.get`,
   o `ipfs dag put/get` portado à mão, com caminho dentro do nó e links);
7. `dart run example/07_car.dart export|import ...`: arquivos CAR (`dag.exportCar`/
   `exportCarFile`, `dag.importCar`/`importCarFiles`: o `ipfs dag export/import`), para
   levar um DAG inteiro de um repo para outro;
8. `dart run example/08_chat.dart <repo> <tópico> [apelido]`: chat em tempo real sobre
   pubsub (`api.pubSub().subscribe/publish`, `sub.next`); o nó precisa de
   `extraOpts: {'pubsub': true}`. Duas instâncias (repos diferentes, perfil
   `randomports`) se acham na rede local pelo mDNS.

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

### Android (validado no emulador, Android 17)

`dart run tool/build.dart android` gera `native/android/{x86_64,arm64-v8a}/libipfs.so` com o
NDK (`ANDROID_NDK_HOME`, ou o mais novo em `<Android SDK>/ndk`), alinhadas em 16 KB. No
Android o `ipfsLibraryPath` padrão é `libipfs.so`: a lib vai dentro do APK. O app de
validação em [`example/android_app`](example/android_app) mostra como empacotar (o Gradle
lê direto de `native/android`), sobe o nó, fecha no background e reabre na volta, roda as
verificações ao abrir (com o log copiável) e tem o teste de integração
(`flutter test integration_test -d <aparelho>`). Release para aparelho:
`flutter build apk --release --target-platform android-arm64`. No Android configure
`DNS.Resolvers` (DNS por HTTPS), como o app faz: o resolvedor do Go não acha o DNS do
sistema. Números e achados em [`TODO.md`](TODO.md).

### Linux pelo WSL (validado no Ubuntu 26.04)

Instale as ferramentas do linux no Ubuntu do WSL (o `dart` do Windows vaza pelo
PATH do WSL; use o do linux):

```bash
sudo apt-get install -y build-essential curl gpg
# Dart: repositório apt oficial (storage.googleapis.com/download.dartlang.org, "stable main")
sudo apt-get install -y dart
# Go 1.26.5 no diretório do usuário
mkdir -p ~/go-sdk && curl -fsSL https://go.dev/dl/go1.26.5.linux-amd64.tar.gz | tar -xz -C ~/go-sdk
export PATH="$HOME/go-sdk/go/bin:/usr/lib/dart/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

Depois, na mesma pasta do repo (`/mnt/<drive>/...`): `dart run tool/build.dart linux`
e `dart test`. O gerador produz exatamente os mesmos arquivos nos dois sistemas. No
linux o QUIC pede um buffer UDP maior (aviso do quic-go, não erro):
`sudo sysctl -w net.core.rmem_max=7500000 net.core.wmem_max=7500000`.

Relatório de crash: um panic numa chamada ou numa goroutine do próprio ipfs_ffi vira
`IpfsException`; numa goroutine interna do kubo derruba o processo (não dá para
recuperar); grave o relatório com `debug.setCrashOutput(os.create(caminho),
debug.CrashOptions())` (`package:ipfs_ffi/runtime/debug.dart`, `package:ipfs_ffi/os.dart`)
e leia o arquivo no próximo início.

Chamadas síncronas só com número, `bool`, string e handle usam um export C direto
(sem JSON; `dart run tool/bench.dart` mede); o resto passa pelo `IpfsCall`.

Pendências e roteiro em [`TODO.md`](TODO.md): o resto do JSON (exports diretos para bytes e tipos-valor, medição das assíncronas, formato binário) e o que falta do Android (aparelho real: rede móvel, bateria, crash).

Limites: os plugins do kubo são injetados uma vez por processo; um panic em
goroutine interna do kubo (fora da chamada) derruba o processo (veja o relatório de crash acima).
