# ipfs_ffi

Kubo v0.43.1 (IPFS em Go) usado do Dart sem HTTP: o kubo roda no executável
`ipfs_host`, noutro processo, e o app fala com ele por memória compartilhada (a
`ipfs_shm`, em C; protocolo binário no [`WIRE.md`](WIRE.md)). O app não carrega Go:
um panic do kubo derruba só o serviço, as chamadas pendentes falham com
`IpfsServiceException` e o `onStop` do app recebe o motivo e o relatório do Go e
decide o que fazer (limpar o log, `IpfsService.restart()` e refazer plugins, nó e
CoreAPI: o processo é novo). Nada volta sozinho. No Android, o plugin companheiro
[`ipfs_ffi_flutter`](flutter) trata o segundo plano (ver abaixo).
Alvos: VM/AOT no Windows, no linux e no Android (não serve para JS/Wasm).

A API Dart é a do próprio Go, gerada, e organizada em namespaces, um por módulo
Go: `kubo`, `boxo`, `ipld` (também o `LinkSystem` e os seletores do go-ipld-prime),
`multiformats` (CID, multiaddr, códigos multicodec), `libp2p`, `car` (o
`github.com/ipld/go-car/v2`: arquivos CAR sem nó) e `go` (o que a API usa da
biblioteca padrão do Go: `bytes`, `context`, `io`, `os`); o `ipfs dag
export/import` está no `kubo`, como no Go. Cada namespace tem um arquivo que exporta tudo dele
(`package:ipfs_ffi/kubo.dart`); quem prefere seguir a documentação do Go importa
um pacote por vez, embaixo dele (`package:ipfs_ffi/kubo/repo/fsrepo.dart` as
`fsrepo`). O que existe, e o que ficou de fora com o motivo, está no
[`API.md`](API.md); a tabela módulo → namespace, em `go/gen/namespaces.go`.

```dart
import 'dart:convert';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/kubo.dart' as kubo;

// lança native/ipfs_host; numa parada (queda ou segundo plano), onStop decide
// (padrão: nada)
await IpfsService.start(onStop: (stop) => print('${stop.reason}: ${stop.report}'));
kubo.PluginLoader('')..initialize()..inject(); // 1x por serviço
kubo.init(repo, kubo.initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')])));
final ctx = go.background();
final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repo)));
final api = kubo.newCoreApi(n);
final p = await api.unixfs().add(ctx, boxo.newBytesFile(utf8.encode('oi')),
    [kubo.unixfs.pin(true, '')]);
print(utf8.decode(go.readAll(boxo.toFile(await api.unixfs().get(ctx, p)))));
final car = await kubo.dagExport(n, ctx, p); // o DAG como CARv1 (ipfs dag export)
await n.close();
await IpfsService.stop();
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
   DAG-CBOR/JSON (`package:ipfs_ffi/kubo/core/commands/dag.dart`: `dagPut`/`dagGet`,
   o `ipfs dag put/get` portado à mão, com caminho dentro do nó e links);
7. `dart run example/07_car.dart export|import ...`: arquivos CAR (`dagExport`/`dagExportFile`,
   `dagImport`/`dagImportFiles` no mesmo `dag.dart`: o `ipfs dag export/import`), para
   levar um DAG inteiro de um repo para outro;
8. `dart run example/08_chat.dart <repo> <tópico> [apelido]`: chat em tempo real sobre
   pubsub (`api.pubSub().subscribe/publish`, `sub.next`); o nó precisa de
   `extraOpts: {'pubsub': true}`. Duas instâncias (repos diferentes, perfil
   `randomports`) se acham na rede local pelo mDNS;
9. `dart run example/09_comandos_e_streams.dart`: os comandos do `ipfs` (`files mkdir/
   write/stat/ls/read/rm`, `pin ls`, `cat`) e o `Stream` passo a passo: `.drain()`,
   `.single`, `await for`, `.toList()`, `.listen` (com `onData`/`onError`/`onDone` e
   `cancel`) e o erro do kubo como exceção. Para quem nunca usou `Future`/`Stream`;
10. `dart run example/10_mfs_baixo_nivel.dart`: o mesmo trabalho pelo baixo nível do
   boxo (`mfs.mkdir`, `putNode`, `lookup`/`asFile`, `open`/`seek`/`write`/`close`,
   `ctxReadFull`, `mv`, `list`, `flushPath`), com o código Go equivalente em cada passo;
11. `dart run example/11_contexto_e_erros.dart`: prazo e cancelamento (`withTimeout`,
   `withCancel`), `IpfsException` (o kubo respondeu erro) × `IpfsServiceException` (o
   serviço caiu), o `onStop` e o `IpfsService.restart()` depois de uma queda;
12. `dart run example/12_car_baixo_nivel.dart`: arquivos CAR sem nó, pelo go-car
   (`openReader`/`inspect`, `BlockReader`, `wrapV1File`, o índice num `bytes.Buffer`, um
   CAR novo bloco a bloco com `openReadWrite` e a travessia seletiva com
   `traverseToFile`), com o código Go equivalente em cada passo.

Os exemplos 9 a 12 criam o próprio repo temporário e não dependem do 01.

## O boxo do Go e o do Dart, lado a lado

Além do kubo, o pacote expõe o baixo nível do boxo (a biblioteca do IPFS em Go que o
kubo usa por dentro) com as mesmas funções, os mesmos tipos e a mesma ordem de
argumentos: quem lê a documentação do boxo em pkg.go.dev sabe usar o Dart. Dois
exemplos, o Go primeiro e o Dart logo abaixo.

Escrever no fim de um arquivo do MFS (o sistema de arquivos do nó) e ler de volta:

```go
// Go (boxo/mfs)
root := node.FilesRoot                         // campo da struct IpfsNode
nd, err := mfs.Lookup(root, "/docs/nota.txt")  // devolve a interface FSNode
if err != nil {
    return err
}
file := nd.(*mfs.File)                         // type assertion: é arquivo?
fd, err := file.Open(ctx, mfs.Flags{Write: true, Sync: true})
if err != nil {
    return err
}
fd.Seek(0, io.SeekEnd)
fd.Write([]byte("mais uma linha\n"))
fd.Close()

fd, _ = file.Open(ctx, mfs.Flags{Read: true})
buf := make([]byte, 1024)                      // o Go lê num buffer seu
n, _ := fd.CtxReadFull(ctx, buf)
fmt.Print(string(buf[:n]))
fd.Close()
```

```dart
// Dart (package:ipfs_ffi/boxo/mfs.dart as mfs)
final root = node.filesRoot;                   // o campo vira getter
final file = mfs.lookup(root, '/docs/nota.txt') // erro do Go → IpfsException
    .asFile()!;                                // o type assertion: null se não for
final fd = await file.open(ctx, mfs.Flags(write: true, sync: true)); // a struct,
fd.seek(0, 2);                                 // com parâmetros nomeados
fd.write(utf8.encode('mais uma linha\n'));
fd.close();

final rd = await file.open(ctx, mfs.Flags(read: true));
final bytes = await rd.ctxReadFull(ctx, 1024); // pede 1024, recebe os lidos
print(utf8.decode(bytes));
rd.close();
```

Adicionar com opções e procurar um arquivo, o mesmo trabalho em dois níveis (o kubo
monta as opções do boxo; o comando `ipfs` faz tudo de uma vez):

```go
// Go (kubo CoreAPI + boxo/files)
p, err := api.Unixfs().Add(ctx, files.NewBytesFile(data),
    options.Unixfs.CidVersion(1), options.Unixfs.Pin(true, ""))
if err != nil {
    return err
}
nd, err := api.ResolveNode(ctx, p)
if err != nil {
    return err
}
err = mfs.PutNode(root, "/docs/foto.jpg", nd)
```

```dart
// Dart: o mesmo baixo nível (as opções do Go viram uma lista)
final p = await api.unixfs().add(ctx, files.newBytesFile(data),
    [options.unixfs.cidVersion(1), options.unixfs.pin(true, '')]);
mfs.putNode(root, '/docs/foto.jpg', await api.resolveNode(ctx, p));

// ou o alto nível, o comando `ipfs files write --create` (um Stream; ver o 09)
await kubo.filesWrite(n, ctx, '/docs/foto.jpg', files.newBytesFile(data),
        create: true, cidVersion: 1)
    .drain<void>();
```

O que muda de um para o outro (a lista completa na seção abaixo):
- o `if err != nil { return err }` some: um erro do Go vira `IpfsException`, que se
  trata com `try`/`catch` (ou deixa subir);
- o que no Go espera com `ctx` (`Open`, `CtxReadFull`, `Add`) é `Future` no Dart e pede
  `await`; o resto (`Lookup`, `Seek`, `Write`, `Close`) é síncrono, como no Go;
- struct de opções (`mfs.Flags{...}`) vira o mesmo tipo com parâmetros nomeados; opções
  funcionais (`options.Unixfs.Pin(...)`) viram uma lista;
- type assertion (`nd.(*mfs.File)`) vira `asFile()`, que devolve `null` se não for;
- o `[]byte` que o Go preenche vira um tamanho pedido e os bytes devolvidos.

## Como o Go vira Dart

- `context.Context` é o 1º parâmetro, como no Go (`package:ipfs_ffi/go/context.dart`:
  `background`, `withCancel`, `withTimeout`, `withDeadline`; `cancel()`).
- Função ou método com `context` é assíncrono (`Future`); canal vira `Stream`;
  `(T, error)` vira `T` com `IpfsException` (inclusive em panic do Go).
- Opções funcionais espelham as variáveis do Go:
  `[options.unixfs.cidVersion(1), options.unixfs.rawLeaves(true)]`.
- Objetos com estado ficam no Go (handle solto pelo `Finalizer` do Dart, em lote,
  e válido só no serviço em que nasceu: depois de um reinício, usá-lo dá
  `IpfsServiceException`); o nó e
  o repo continuam exigindo o `close` do Go. CID, path, peer e multiaddr são
  valores (a string); `config.Config` guarda o JSON do kubo em `json`.
- Constantes do Go viram `const` (`mfs.tFile`, `iface.diffAdd`); campos de struct
  viram getter e setter (`node.filesRoot`, `file.rawLeaves = true`); `any` vira
  `Object?` (null, bool, int, double, String, Uint8List, List, Map).
- Uma interface ganha um cast para cada tipo concreto exposto que a implementa, como
  o `switch x.(type)` do Go: `mfs.lookup(root, '/a').asDirectory()` (null se não for).
- `Read`, `ReadAt` e `CtxReadFull` (o Go preenche um `[]byte`) recebem o tamanho e
  devolvem os bytes lidos (`await fd.ctxReadFull(ctx, 4096)`; vazio no fim).

## Além da CoreAPI: MFS, config e peering (0.13)

O baixo nível do Go, como ele é (o alto nível, `ipfs files/config/bootstrap/swarm
peering`, está nos comandos do RPC, abaixo):

```dart
final root = node.filesRoot;                       // IpfsNode.FilesRoot
mfs.mkdir(root, '/docs', mfs.MkdirOpts(mkparents: true, flush: true));
mfs.putNode(root, '/docs/a.txt', await api.resolveNode(ctx, p));
final file = mfs.lookup(root, '/docs/a.txt').asFile()!;
final fd = await file.open(ctx, mfs.Flags(write: true));
fd.truncate(0);
fd.write(utf8.encode('novo'));
fd.close();
await mfs.flushPath(ctx, root, '/docs');            // o CID da pasta

node.repo.setConfigKey('Discovery.MDNS.Enabled', false); // o mesmo que `ipfs config`
node.peering.addPeer(info);                          // vale na hora, não persiste
```

A maior parte da config só vale ao reiniciar o nó (o kubo a lê na subida); o peering
vale na hora mas não vai para a config.

## Arquivos CAR sem nó: o go-car (0.16)

O `github.com/ipld/go-car/v2` como ele é, no namespace `car`: o arquivo aberto e mexido sem
nó (o `kubo.dagExport/dagImport` continua para levar um DAG do nó para um CAR e de volta):

```dart
final r = car.openReader('pasta.car');              // CARv1 ou CARv2
final st = r.inspect(true);                          // confere cada hash
print('${r.roots()} ${st.blockCount} ${st.codecCounts}'); // {0x70: 2, 0x55: 3}
r.close();

car.wrapV1File('pasta.car', 'pasta.v2.car');         // v1 → v2 (com índice)
final idx = car.generateIndexFromFile('pasta.car');
final buf = go.Buffer(Uint8List(0));                 // qualquer io.Writer: os.File...
car.writeTo(idx, buf);

final c = mf.newPrefixV1(0x55, 0x12).sum(dados);     // o CID, sem nó
final rw = car.openReadWrite('novo.car', [c]);
await rw.put(ctx, ipld.Block(cid: c, rawData: dados));
rw.finalize();

final ls = ipld.defaultLinkSystem();                 // recorte por seletor IPLD
ls.setReadStorage(car.openReadable(go.open('pasta.car')));
await car.traverseToFile(ctx, ls, raiz, ipld.commonSelectorMatchPoint, 'raiz.car');
```

Parâmetros `io.Reader`/`io.ReaderAt`/`io.ReadSeeker` aceitam bytes ou um handle (`go.open`);
`io.Writer` aceita um handle (`go.Buffer`, `go.openFile`) ou null (descarta). O fim do
`BlockReader.next()` é o `io.EOF` do Go: `IpfsEof`, uma subclasse de `IpfsException` (as
outras: `IpfsUnexpectedEof`, `IpfsCanceled`, `IpfsDeadlineExceeded`, `IpfsNotFound`), lançada
como o `errors.Is` do Go a acharia, inclusive com o erro embrulhado.

## Correções no upstream (0.15)

Dois bugs do kubo/boxo, reproduzidos em Go puro, que o `tool/build.dart` corrige por patch
em todo build (`upstreamPatches`: o módulo vai copiado do cache com o trecho trocado; se o
trecho mudar numa versão nova, o build para). O `go/upstream_test.go` afirma cada bug no
módulo sem patch e falha quando o upstream o corrigir, avisando que o patch sai:

- boxo v0.43.0 ([ipfs/boxo#1221](https://github.com/ipfs/boxo/issues/1221)): anexar no fim
  de um arquivo do MFS cujo nó guarda os dados embutidos (o nó de um `add` pequeno)
  deixava o tamanho certo, mas a leitura devolvia só o trecho anexado;
- kubo v0.43.1 ([ipfs/kubo#11477](https://github.com/ipfs/kubo/issues/11477)): com
  `Routing.Type` none (`libp2p.nilRouterOption`), o `close` deixava aberto o datastore do
  `provider-keystore`, e reabrir o repo no mesmo processo esbarrava na trava.

## Os comandos do RPC (0.14)

Os comandos do `ipfs` (o RPC `/api/v0`) rodam com o nó do app, sem daemon nem HTTP, pela
mesma árvore do kubo: um por função em `package:ipfs_ffi/kubo/core/commands.dart` (também
no `kubo.dart`). O nome é o caminho em lowerCamel; argumentos posicionais; opções nomeadas
(null = o padrão do kubo); um DTO por retorno:

```dart
await kubo.filesMkdir(n, ctx, '/docs', parents: true).drain<void>();
await kubo.filesWrite(n, ctx, '/docs/a.txt', files.newBytesFile(dados), create: true)
    .drain<void>();
final st = await kubo.filesStat(n, ctx, '/docs/a.txt').single; // StatOutput
final bytes = kubo.filesRead(n, ctx, '/docs/a.txt');            // Stream<Uint8List>
await for (final p in kubo.pinLs(n, ctx, [], type: 'recursive')) {} // um DTO por item
final cfg = await kubo.configShow(n, ctx).single;               // Map<String, Object?>
```

Todo comando devolve um `Stream` (0.15): quem usa decide entre `.single` (um valor),
`.first`, `toList()` ou `drain()` (só o efeito); o `Stream` só roda quando é ouvido. O item
é o DTO do retorno, `Uint8List` nos que emitem bytes (`cat`, `get`, `files read`...) e
`Object?` nos sem tipo declarado. Nos de pubsub o tópico vai cru: o host o codifica como o
CLI do kubo. A lista completa (comando → função → retorno) e os que ficam de fora, com o
motivo, estão no `API.md`; o `test/commands_smoke_test.dart` roda todos. Os de config (`config`, `bootstrap`) gravam no arquivo do repo e, como no kubo,
a maior parte só vale ao reiniciar o nó; os que precisam de rede (`swarm peering ls`)
dão o erro do kubo num nó offline.

## Gerar e compilar

- `dart run tool/build.dart [linux|windows]`: roda o gerador (`go run ./gen` em
  `go/`) e compila em `native/` (fora do git) o host (`ipfs_host`/`ipfs_host.exe`, Go
  sem cgo) e a `ipfs_shm` (`libipfs_shm.so`/`ipfs_shm.dll`, C). Exige Go 1.26.5
  (`GOTOOLCHAIN=auto` baixa) e um compilador C só para a `ipfs_shm`: no Windows, o
  mingw-w64 no PATH (ex. `winget install BrechtSanders.WinLibs.POSIX.UCRT`); no
  linux, gcc e `x86_64-w64-mingw32-gcc` para a DLL.
- Para expor mais do kubo/boxo: acrescente o símbolo em `go/gen/roots.txt`
  (`pacote.Função` ou `pacote.Tipo.Método`) e rode o build. O que o gerador
  não exprime vai à mão em `go/runtime.go` e `go/gen/extra/<library>.extra`.
- `go run ./gen -check` (em `go/`) falha se os arquivos gerados estão
  desatualizados.
- Testes: `dart test` nesta pasta.

### Android (validado no emulador e num aparelho, Android 16 e 17)

`dart run tool/build.dart android` gera em `native/android/{x86_64,arm64-v8a}/` o host
(`libipfs_host.so`, um executável com nome de lib para o APK levar) e a `libipfs_shm.so`, com o
NDK (`ANDROID_NDK_HOME`, ou o mais novo em `<Android SDK>/ndk`), alinhadas em 16 KB, com o
`go-multiaddr` e o `zeroconf` trocados pelo `wlynxg/anet` (no Android 11+ o `net` do Go não
lista interfaces; sem isso o nó só anuncia 127.0.0.1 e o mDNS não funciona). O host do
Android vai com cgo, ligado pelo clang do NDK: sem ele o Go fica sem o resolvedor de DNS
do sistema (procura `/etc/resolv.conf`, que o Android não tem) e o anet sem o nível de API
do aparelho (medido num aparelho arm64 no 0.15). No
Android o host padrão (`defaultHostPath()`) é a `libipfs_host.so` na pasta das libs
nativas do app (o APK precisa extraí-las: `packaging.jniLibs.useLegacyPackaging = true`
no Gradle; o Android só executa da `nativeLibraryDir`). O app de
validação em [`example/android_app`](example/android_app) mostra como empacotar (o Gradle
lê direto de `native/android`), sobe o nó, trata o segundo plano, roda as
verificações ao abrir (com o log copiável) e tem o teste de integração
(`flutter test integration_test -d <aparelho>`). Release para aparelho:
`flutter build apk --release --target-platform android-arm64`. No Android configure
`DNS.Resolvers` (DNS por HTTPS), como o app faz: o resolvedor do Go não acha o DNS do
sistema. Para o mDNS, o app segura um `WifiManager.MulticastLock` (ver `MainActivity.kt`).
Conexões por relay duram até 2 min e não levam pubsub nem bitswap: entre dois aparelhos
atrás de NAT de operadora, a conexão direta vem pelo IPv6 (medido: vira direta em ~14 s) ou
quando um deles é alcançável; por IPv4 o NAT da operadora medido é simétrico e o hole
punching não acontece. `hasIpv6()` (`package:ipfs_ffi/ipfs_ffi.dart`) diz se a rede
atual entrega IPv6 global. Números e achados
em [`TODO.md`](TODO.md).

**Segundo plano.** O `ipfs_host` é um processo filho do app (mesmo usuário Linux,
mesmo contexto SELinux, mesmo cgroup): vale para ele tudo que vale para o app em
segundo plano. No Android 12+ o *phantom process killer* mata o processo filho que
gaste CPU com o app em segundo plano, **e o app junto** (medido no emulador: um
minuto depois do HOME, `excessive cpu ... limit=25`, "Caused by child process").
Por isso o app adiciona o plugin [`ipfs_ffi_flutter`](flutter) (registra-se sozinho)
e escolhe em `IpfsService.background`, lido a cada `start`/`restart`:
- `IpfsBackground.stop` (padrão): ao ir para o segundo plano, o plugin para o
  serviço; as pendentes falham com `IpfsServiceException(reason: background)` e o
  `onStop` recebe `IpfsStopReason.background`. Subir de novo (na volta, ou quando
  quiser) fica com o app: `IpfsService.restart()`.
- `IpfsBackground.foregroundService`: enquanto o host roda, o plugin mantém um
  serviço em primeiro plano do Android (tipo `specialUse`, com notificação), e o nó
  segue online no segundo plano. A notificação no Android 13+ pede a permissão
  `POST_NOTIFICATIONS`: o app a pede com
  `IpfsFfiFlutter.requestNotificationPermission()` (o diálogo do sistema; devolve se
  ficou permitida) antes de subir o serviço. Sem ela o serviço roda, sem aparecer na
  gaveta. Numa queda do host nesse modo, o serviço do Android continua de pé, para o
  `onStop` poder chamar `IpfsService.restart()` do segundo plano (o Android 12+ só
  inicia um serviço em primeiro plano com o app na frente); o `IpfsService.stop()` o
  encerra.

A notificação é do app (o plugin cuida do serviço, do manifesto e do ciclo de vida):

```dart
IpfsFfiFlutter.notification = const IpfsNotification(
    title: 'Meu app', text: 'conectando...', icon: 'ic_stat_ipfs', // res/drawable
    channelName: 'Nó IPFS', importance: IpfsNotificationImportance.low);
// com o serviço rodando, também do segundo plano:
await IpfsFfiFlutter.updateNotification(
    IpfsFfiFlutter.notification.copyWith(text: 'online: $n peers'));
```

Para controle total (ações, estilos, layout próprio), o app registra no código
nativo quem monta a `Notification`, antes de o serviço subir; o canal já vem criado e
o `config` traz os campos do `IpfsNotification` e o `extras` (strings livres do Dart):

```kotlin
IpfsForegroundService.setNotificationFactory { context, channelId, config ->
    Notification.Builder(context, channelId)
        .setContentTitle(config.getString("title"))
        .setSmallIcon(R.drawable.ic_stat_ipfs)
        .build()
}
```

Sem Flutter, o app pode chamar `IpfsService.appInBackground()` ele mesmo.

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
`IpfsException`; numa goroutine interna do kubo derruba o `ipfs_host` (não o app):
`IpfsService.start(crashLog: caminho)` faz o Go gravar o relatório nesse arquivo, e
`IpfsService.exitCode` completa quando o host sai. O serviço **não** volta sozinho:
as pendentes falham com `IpfsServiceException` (`reason: crash`) e o `onStop`
passado ao `start` (padrão `null`: nada acontece) recebe um `IpfsStop` com o motivo
(`IpfsStopReason.crash`), o código de saída, o
relatório do Go (o que o host acrescentou ao `crashLog` desde que subiu, ou o stderr
dele), o caminho do `crashLog`, o pid e quanto tempo ficou de pé. Quem usa o pacote
decide: limpar o arquivo (o host só acrescenta), chamar `IpfsService.restart()` (os
mesmos parâmetros do `start`), quando, e refazer o que usava; os handles do serviço
anterior deixam de valer e os plugins do kubo são injetados de novo (é outro
processo).

Toda chamada vai em binário pelo canal (`WIRE.md`): síncronas bloqueiam a isolate
até a resposta, as com `context` são `Future`, canais são `Stream`;
`dart run tool/bench.dart` mede.

Pendências e roteiro em [`TODO.md`](TODO.md): o que falta do Android (dois aparelhos conectando direto, uso longo).

Limites: os plugins do kubo são injetados uma vez por processo do serviço; um panic
em goroutine interna do kubo (fora da chamada) derruba o serviço (veja o relatório de
crash acima).
