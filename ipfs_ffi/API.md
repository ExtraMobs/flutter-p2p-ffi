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

## `github.com/libp2p/go-libp2p/core/peer` → `package:ipfs_ffi/go_libp2p/core/peer.dart`

| Go | Dart | Modo |
|---|---|---|
| `func peer.AddrInfoFromString(s string) (*peer.AddrInfo, error)` | `addrInfoFromString` | síncrona |
| `func peer.AddrInfoToP2pAddrs(pi *peer.AddrInfo) ([]multiaddr.Multiaddr, error)` | `addrInfoToP2pAddrs` | síncrona |

## `io` → `package:ipfs_ffi/io.dart`

| Go | Dart | Modo |
|---|---|---|
| `func io.ReadAll(r io.Reader) ([]byte, error)` | `readAll` | síncrona |

## `os` → `package:ipfs_ffi/os.dart`

| Go | Dart | Modo |
|---|---|---|
| `func os.Stat(name string) (os.FileInfo, error)` | `stat` | síncrona |

## Construtores de opção omitidos

- `options.Unixfs.Events` (UnixfsAddOption): parâmetro sink: chan de 

## Adaptações (regras do gerador e código à mão)

- `context` (`package:ipfs_ffi/context.dart`, à mão): `background`, `withCancel`, `withTimeout`, `withDeadline`; `CancelFunc` é chamável (`cancel()`).
- `config.Profiles` (à mão): `profiles[nome]!.transform(cfg)`; no Go é um mapa de funções.
- Métodos e funções com `context.Context` são assíncronos (`Future`); canais viram `Stream`; `(T, error)` vira `T` com `IpfsException`.
- Variádicos viram `List` opcional; opções funcionais espelham as variáveis do pacote (`options.unixfs.pin(true, '')`).
- `NewX` síncrono que devolve `X` do mesmo pacote vira `factory X(...)`.
- `io.Writer` em parâmetro não aparece no Dart: o Go usa `io.Discard`.
- `io.Reader` em parâmetro aceita `Uint8List` ou um handle de leitor (ex. o `files.File` devolvido pelo kubo).
- Tipos-valor (CID, path, peer ID, multiaddr) guardam a string; a validação acontece no Go, quando atravessam.
- `config.Config` guarda o JSON do kubo (o mesmo do arquivo `config` do repo) em `json`.
- Resultado `nil` do Go onde o Dart espera um objeto vira `IpfsException`.
- Handles são soltos por `NativeFinalizer`; recursos do Go (nó, repo) continuam exigindo o `Close` do próprio Go.
