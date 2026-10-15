# API do ipfs_ffi

Gerado por `go run ./gen` (na pasta `go/`) a partir de `go/gen/roots.txt`; não editar.
Cada linha é um símbolo Go exposto e onde ele está no Dart.

## `github.com/ipfs/boxo/files` → `package:ipfs_ffi/boxo/files.dart`

| Go | Dart | Modo |
|---|---|---|
| `func files.NewBytesFile(b []byte) files.File` | `newBytesFile` | síncrona |
| `func files.NewSerialFile(path string, includeHidden bool, stat os.FileInfo) (files.Node, error)` | `newSerialFile` | síncrona |
| `func files.ToFile(n files.Node) files.File` | `toFile` | síncrona |
| `func files.WriteTo(nd files.Node, fpath string) error` | `writeTo` | síncrona |

## `github.com/ipfs/boxo/ipld/merkledag` → `package:ipfs_ffi/boxo/ipld/merkledag.dart`

| Go | Dart | Modo |
|---|---|---|
| `func merkledag.NewRawNode(data []byte) *merkledag.RawNode` | `factory RawNode` | síncrona |
| `func merkledag.NodeWithData(d []byte) *merkledag.ProtoNode` | `nodeWithData` | síncrona |
| `func (*merkledag.ProtoNode).AddNodeLink(name string, that format.Node) error` | `ProtoNode.addNodeLink` | síncrona |
| `func (*merkledag.ProtoNode).SetData(d []byte)` | `ProtoNode.setData` | síncrona |
| `func (*merkledag.ProtoNode).Data() []byte` | `ProtoNode.data` | síncrona |

## `github.com/ipfs/go-ipld-format` → `package:ipfs_ffi/ipld/format.dart`

| Go | Dart | Modo |
|---|---|---|
| `func (format.NodeAdder).Add(context.Context, format.Node) error` | `NodeAdder.add` | Future |
| `func (format.NodeAdder).AddMany(context.Context, []format.Node) error` | `NodeAdder.addMany` | Future |
| `func (blocks.Block).Cid() cid.Cid` | `Node.cid` | síncrona |
| `func (blocks.Block).RawData() []byte` | `Node.rawData` | síncrona |
| `func (format.Node).Links() []*format.Link` | `Node.links` | síncrona |
| `func (format.Node).Size() (uint64, error)` | `Node.size` | síncrona |
| `func (format.Node).Stat() (*format.NodeStat, error)` | `Node.stat` | síncrona |

## `github.com/ipfs/kubo/config` → `package:ipfs_ffi/kubo/config.dart`

| Go | Dart | Modo |
|---|---|---|
| `func config.CreateIdentity(out io.Writer, opts []options.KeyGenerateOption) (config.Identity, error)` | `createIdentity` | síncrona |
| `func config.InitWithIdentity(identity config.Identity) (*config.Config, error)` | `initWithIdentity` | síncrona |

## `github.com/ipfs/kubo/core` → `package:ipfs_ffi/kubo/core.dart`

| Go | Dart | Modo |
|---|---|---|
| `func core.NewNode(ctx context.Context, cfg *core.BuildCfg) (*core.IpfsNode, error)` | `newNode` | Future |
| `func (*core.IpfsNode).Close() error` | `IpfsNode.close` | Future |

## `github.com/ipfs/kubo/core/coreapi` → `package:ipfs_ffi/kubo/core/coreapi.dart`

| Go | Dart | Modo |
|---|---|---|
| `func coreapi.NewCoreAPI(n *core.IpfsNode, opts ...options.ApiOption) (iface.CoreAPI, error)` | `newCoreApi` | síncrona |

## `github.com/ipfs/kubo/core/coreiface` → `package:ipfs_ffi/kubo/core/coreiface.dart`

| Go | Dart | Modo |
|---|---|---|
| `func (iface.CoreAPI).Unixfs() iface.UnixfsAPI` | `CoreApi.unixfs` | síncrona |
| `func (iface.CoreAPI).ResolvePath(context.Context, path.Path) (path.ImmutablePath, []string, error)` | `CoreApi.resolvePath` | Future |
| `func (iface.UnixfsAPI).Add(context.Context, files.Node, ...options.UnixfsAddOption) (path.ImmutablePath, error)` | `UnixfsApi.add` | Future |
| `func (iface.UnixfsAPI).Get(context.Context, path.Path) (files.Node, error)` | `UnixfsApi.get` | Future |
| `func (iface.UnixfsAPI).Ls(context.Context, path.Path, chan<- iface.DirEntry, ...options.UnixfsLsOption) error` | `UnixfsApi.ls` | Stream |
| `func (iface.CoreAPI).Pin() iface.PinAPI` | `CoreApi.pin` | síncrona |
| `func (iface.PinAPI).Add(context.Context, path.Path, ...options.PinAddOption) error` | `PinApi.add` | Future |
| `func (iface.PinAPI).Ls(context.Context, chan<- iface.Pin, ...options.PinLsOption) error` | `PinApi.ls` | Stream |
| `func (iface.PinAPI).IsPinned(context.Context, path.Path, ...options.PinIsPinnedOption) (string, bool, error)` | `PinApi.isPinned` | Future |
| `func (iface.PinAPI).Rm(context.Context, path.Path, ...options.PinRmOption) error` | `PinApi.rm` | Future |
| `func (iface.PinAPI).Update(ctx context.Context, from path.Path, to path.Path, opts ...options.PinUpdateOption) error` | `PinApi.update` | Future |
| `func (iface.PinAPI).Verify(context.Context) (<-chan iface.PinStatus, error)` | `PinApi.verify` | Stream |
| `func (iface.CoreAPI).Block() iface.BlockAPI` | `CoreApi.block` | síncrona |
| `func (iface.BlockAPI).Put(context.Context, io.Reader, ...options.BlockPutOption) (iface.BlockStat, error)` | `BlockApi.put` | Future |
| `func (iface.BlockAPI).Get(context.Context, path.Path) (io.Reader, error)` | `BlockApi.get` | Future |
| `func (iface.BlockAPI).Rm(context.Context, path.Path, ...options.BlockRmOption) error` | `BlockApi.rm` | Future |
| `func (iface.BlockAPI).Stat(context.Context, path.Path) (iface.BlockStat, error)` | `BlockApi.stat` | Future |
| `func (iface.CoreAPI).Key() iface.KeyAPI` | `CoreApi.key` | síncrona |
| `func (iface.KeyAPI).Self(ctx context.Context) (iface.Key, error)` | `KeyApi.self` | Future |
| `func (iface.CoreAPI).Swarm() iface.SwarmAPI` | `CoreApi.swarm` | síncrona |
| `func (iface.SwarmAPI).Connect(context.Context, peer.AddrInfo) error` | `SwarmApi.connect` | Future |
| `func (iface.SwarmAPI).Disconnect(context.Context, multiaddr.Multiaddr) error` | `SwarmApi.disconnect` | Future |
| `func (iface.SwarmAPI).Peers(context.Context) ([]iface.ConnectionInfo, error)` | `SwarmApi.peers` | Future |
| `func (iface.SwarmAPI).ListenAddrs(context.Context) ([]multiaddr.Multiaddr, error)` | `SwarmApi.listenAddrs` | Future |
| `func (iface.SwarmAPI).LocalAddrs(context.Context) ([]multiaddr.Multiaddr, error)` | `SwarmApi.localAddrs` | Future |
| `func (iface.CoreAPI).Routing() iface.RoutingAPI` | `CoreApi.routing` | síncrona |
| `func (iface.RoutingAPI).Provide(context.Context, path.Path, ...options.RoutingProvideOption) error` | `RoutingApi.provide` | Future |
| `func (iface.RoutingAPI).FindProviders(context.Context, path.Path, ...options.RoutingFindProvidersOption) (<-chan peer.AddrInfo, error)` | `RoutingApi.findProviders` | Stream |
| `func (iface.RoutingAPI).FindPeer(context.Context, peer.ID) (peer.AddrInfo, error)` | `RoutingApi.findPeer` | Future |
| `func (iface.CoreAPI).Name() iface.NameAPI` | `CoreApi.name` | síncrona |
| `func (iface.NameAPI).Publish(ctx context.Context, path path.Path, opts ...options.NamePublishOption) (ipns.Name, error)` | `NameApi.publish` | Future |
| `func (iface.NameAPI).Resolve(ctx context.Context, name string, opts ...options.NameResolveOption) (path.Path, error)` | `NameApi.resolve` | Future |
| `func (iface.NameAPI).Search(ctx context.Context, name string, opts ...options.NameResolveOption) (<-chan iface.IpnsResult, error)` | `NameApi.search` | Stream |
| `func (iface.KeyAPI).Generate(ctx context.Context, name string, opts ...options.KeyGenerateOption) (iface.Key, error)` | `KeyApi.generate` | Future |
| `func (iface.KeyAPI).Rename(ctx context.Context, oldName string, newName string, opts ...options.KeyRenameOption) (iface.Key, bool, error)` | `KeyApi.rename` | Future |
| `func (iface.KeyAPI).List(ctx context.Context) ([]iface.Key, error)` | `KeyApi.list` | Future |
| `func (iface.KeyAPI).Remove(ctx context.Context, name string) (iface.Key, error)` | `KeyApi.remove` | Future |
| `func (iface.KeyAPI).Sign(ctx context.Context, name string, data []byte) (iface.Key, []byte, error)` | `KeyApi.sign` | Future |
| `func (iface.KeyAPI).Verify(ctx context.Context, keyOrName string, signature []byte, data []byte) (iface.Key, bool, error)` | `KeyApi.verify` | Future |
| `func (iface.SwarmAPI).KnownAddrs(context.Context) (map[peer.ID][]multiaddr.Multiaddr, error)` | `SwarmApi.knownAddrs` | Future |
| `func (iface.CoreAPI).Dag() iface.APIDagService` | `CoreApi.dag` | síncrona |
| `func (iface.CoreAPI).ResolveNode(context.Context, path.Path) (format.Node, error)` | `CoreApi.resolveNode` | Future |
| `func (format.NodeGetter).Get(context.Context, cid.Cid) (format.Node, error)` | `ApiDagService.get` | Future |
| `func (format.NodeGetter).GetMany(context.Context, []cid.Cid) <-chan *format.NodeOption` | `ApiDagService.getMany` | Stream |
| `func (format.NodeAdder).Add(context.Context, format.Node) error` | `ApiDagService.add` | Future |
| `func (format.NodeAdder).AddMany(context.Context, []format.Node) error` | `ApiDagService.addMany` | Future |
| `func (format.DAGService).Remove(context.Context, cid.Cid) error` | `ApiDagService.remove` | Future |
| `func (format.DAGService).RemoveMany(context.Context, []cid.Cid) error` | `ApiDagService.removeMany` | Future |
| `func (iface.APIDagService).Pinning() format.NodeAdder` | `ApiDagService.pinning` | síncrona |
| `func (iface.CoreAPI).PubSub() iface.PubSubAPI` | `CoreApi.pubSub` | síncrona |
| `func (iface.PubSubAPI).Ls(context.Context) ([]string, error)` | `PubSubApi.ls` | Future |
| `func (iface.PubSubAPI).Peers(context.Context, ...options.PubSubPeersOption) ([]peer.ID, error)` | `PubSubApi.peers` | Future |
| `func (iface.PubSubAPI).Publish(context.Context, string, []byte) error` | `PubSubApi.publish` | Future |
| `func (iface.PubSubAPI).Subscribe(context.Context, string, ...options.PubSubSubscribeOption) (iface.PubSubSubscription, error)` | `PubSubApi.subscribe` | Future |
| `func (iface.PubSubSubscription).Next(context.Context) (iface.PubSubMessage, error)` | `PubSubSubscription.next` | Future |
| `func (io.Closer).Close() error` | `PubSubSubscription.close` | síncrona |

## `github.com/ipfs/kubo/core/corerepo` → `package:ipfs_ffi/kubo/core/corerepo.dart`

| Go | Dart | Modo |
|---|---|---|
| `func corerepo.GarbageCollect(n *core.IpfsNode, ctx context.Context) error` | `garbageCollect` | Future |
| `func corerepo.GarbageCollectAsync(n *core.IpfsNode, ctx context.Context) <-chan gc.Result` | `garbageCollectAsync` | Stream |

## `github.com/ipfs/kubo/core/node/libp2p` → `package:ipfs_ffi/kubo/core/node/libp2p.dart`

| Go | Dart | Modo |
|---|---|---|
| `var libp2p.DHTOption libp2p.RoutingOption` | `dhtOption` | síncrona |
| `var libp2p.DHTClientOption libp2p.RoutingOption` | `dhtClientOption` | síncrona |
| `var libp2p.DHTServerOption libp2p.RoutingOption` | `dhtServerOption` | síncrona |
| `var libp2p.NilRouterOption func(_ libp2p.RoutingOptionArgs) (routing.Routing, error)` | `nilRouterOption` | síncrona |
| `func libp2p.ConstructDefaultRouting(cfg *config.Config, routingOpt libp2p.RoutingOption) libp2p.RoutingOption` | `constructDefaultRouting` | síncrona |

## `github.com/ipfs/kubo/plugin/loader` → `package:ipfs_ffi/kubo/plugin/loader.dart`

| Go | Dart | Modo |
|---|---|---|
| `func loader.NewPluginLoader(repo string) (*loader.PluginLoader, error)` | `factory PluginLoader` | síncrona |
| `func (*loader.PluginLoader).Initialize() error` | `PluginLoader.initialize` | síncrona |
| `func (*loader.PluginLoader).Inject() error` | `PluginLoader.inject` | síncrona |

## `github.com/ipfs/kubo/repo` → `package:ipfs_ffi/kubo/repo.dart`

| Go | Dart | Modo |
|---|---|---|
| `func (repo.Repo).Config() (*config.Config, error)` | `Repo.config` | síncrona |

## `github.com/ipfs/kubo/repo/fsrepo` → `package:ipfs_ffi/kubo/repo/fsrepo.dart`

| Go | Dart | Modo |
|---|---|---|
| `func fsrepo.IsInitialized(path string) bool` | `isInitialized` | síncrona |
| `func fsrepo.Init(repoPath string, conf *config.Config) error` | `init` | síncrona |
| `func fsrepo.Open(repoPath string) (repo.Repo, error)` | `open` | síncrona |

## `github.com/libp2p/go-libp2p/core/peer` → `package:ipfs_ffi/libp2p/core/peer.dart`

| Go | Dart | Modo |
|---|---|---|
| `func peer.AddrInfoFromString(s string) (*peer.AddrInfo, error)` | `addrInfoFromString` | síncrona |
| `func peer.AddrInfoToP2pAddrs(pi *peer.AddrInfo) ([]multiaddr.Multiaddr, error)` | `addrInfoToP2pAddrs` | síncrona |

## `io` → `package:ipfs_ffi/go/io.dart`

| Go | Dart | Modo |
|---|---|---|
| `func io.ReadAll(r io.Reader) ([]byte, error)` | `readAll` | síncrona |

## `os` → `package:ipfs_ffi/go/os.dart`

| Go | Dart | Modo |
|---|---|---|
| `func os.Stat(name string) (os.FileInfo, error)` | `stat` | síncrona |
| `func os.Create(name string) (*os.File, error)` | `create` | síncrona |
| `func (*os.File).Close() error` | `File.close` | síncrona |

## `runtime/debug` → `package:ipfs_ffi/go/runtime/debug.dart`

| Go | Dart | Modo |
|---|---|---|
| `func debug.SetCrashOutput(f *os.File, opts debug.CrashOptions) error` | `setCrashOutput` | síncrona |

## Adaptações (regras do gerador e código à mão)

- Namespaces: cada módulo Go num namespace (`kubo`, `boxo`, `car`, `ipld`, `multiformats`, `libp2p`, `go`), com um arquivo `package:ipfs_ffi/<namespace>.dart` que exporta todas as libraries dele (`import 'package:ipfs_ffi/kubo.dart' as kubo;`); as libraries por pacote Go continuam embaixo. A tabela módulo → namespace fica em `go/gen/namespaces.go`.
- `context` (`package:ipfs_ffi/go/context.dart`, à mão): `background`, `withCancel`, `withTimeout`, `withDeadline`; `CancelFunc` é chamável (`cancel()`).
- `config.Profiles` (à mão): `profiles[nome]!.transform(cfg)`; no Go é um mapa de funções.
- `ipfs dag put`/`ipfs dag get` (`dagPut`/`dagGet` em `package:ipfs_ffi/kubo/core/commands/dag.dart`, porte à mão em `go/manual_dag.go`): no kubo é o corpo dos comandos, não função de biblioteca; mesmos padrões do CLI (dag-json → dag-cbor, limite de 2 MiB), hash padrão `sha2-256`.
- `ipfs dag export`/`ipfs dag import` (arquivos CAR; namespace `package:ipfs_ffi/car.dart`, porte à mão em `go/manual_car.go`): `export`/`exportFile` (CARv1, `localOnly` = `--local-only`) e `import`/`importFiles` (CARv1/v2, `pinRoots` = `--pin-roots`, devolve raízes e estatísticas); recebem o `IpfsNode`, como o comando. Sem barra de progresso nem fast-provide do DAG inteiro; a raiz é anunciada pelo `Provide` da CoreAPI.
- Pubsub: o nó precisa de `node.BuildCfg(extraOpts: {'pubsub': true})` (o `Pubsub.Enabled` do daemon); `sub.next(ctx)` entrega uma mensagem por vez (o exemplo 08 a transforma em `Stream`).
- Handle concreto que implementa uma interface exposta estende a classe dela (`merkledag.RawNode`/`ProtoNode` → `Node`), para valer onde o Go aceita a interface; struct que embute interface é handle, não DTO.
- Mapa com chave tipo-valor (`map[peer.ID][]Multiaddr`) vira `Map<Id, List<Multiaddr>>`.
- Canal `chan<- T` passado numa opção (`options.Unixfs.Events`) vira `StreamSink<T>` (`options.unixfs.events(controller.sink)`); o tipo real dos itens de `chan<- any` vem da tabela `chanElem` do gerador (`AddEvent`). Como o `ipfs add`, o canal é fechado quando a chamada volta: todos os eventos chegam e o sink fecha antes do `Future` completar.
- Variável de pacote vira getter; tipo função nomeado (`libp2p.RoutingOption`) é handle opaco, criado só no Go.
- Métodos e funções com `context.Context` são assíncronos (`Future`); canais viram `Stream`; `(T, error)` vira `T` com `IpfsException`.
- Variádicos viram `List` opcional; opções funcionais espelham as variáveis do pacote (`options.unixfs.pin(true, '')`).
- `NewX` síncrono que devolve `X` do mesmo pacote vira `factory X(...)`.
- `io.Writer` em parâmetro não aparece no Dart: o Go usa `io.Discard`.
- `io.Reader` em parâmetro aceita `Uint8List` ou um handle de leitor (ex. o `files.File` devolvido pelo kubo).
- Tipos-valor (CID, path, peer ID, multiaddr) guardam a string; a validação acontece no Go, quando atravessam.
- `config.Config` guarda o JSON do kubo (o mesmo do arquivo `config` do repo) em `json`.
- Resultado `nil` do Go onde o Dart espera um objeto vira `IpfsException`.
- O kubo roda no `ipfs_host`, noutro processo (`IpfsService.start()` antes da API; protocolo no `WIRE.md`): um panic do Go derruba só o serviço, e as chamadas pendentes falham com `IpfsServiceException`.
- Handles são soltos pelo `Finalizer` do Dart (em lote, pela função Free do serviço) e só valem no serviço em que nasceram; recursos do Go (nó, repo) continuam exigindo o `Close` do próprio Go.
