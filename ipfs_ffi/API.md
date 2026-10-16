# API do ipfs_ffi

Gerado por `go run ./gen` (na pasta `go/`) a partir de `go/gen/roots.txt`; não editar.
Cada linha é um símbolo Go exposto e onde ele está no Dart.

## `github.com/ipfs/boxo/chunker` → `package:ipfs_ffi/boxo/chunker.dart`

| Go | Dart | Modo |
|---|---|---|
| `func chunk.SizeSplitterGen(size int64) chunk.SplitterGen` | `sizeSplitterGen` | síncrona |

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

## `github.com/ipfs/boxo/mfs` → `package:ipfs_ffi/boxo/mfs.dart`

| Go | Dart | Modo |
|---|---|---|
| `const mfs.TFile mfs.NodeType` | `tFile` | const |
| `const mfs.TDir mfs.NodeType` | `tDir` | const |
| `func mfs.Lookup(r *mfs.Root, path string) (mfs.FSNode, error)` | `lookup` | síncrona |
| `func mfs.DirLookup(d *mfs.Directory, pth string) (mfs.FSNode, error)` | `dirLookup` | síncrona |
| `func mfs.Mkdir(r *mfs.Root, pth string, opts mfs.MkdirOpts, dirOpts ...mfs.Option) error` | `mkdir` | síncrona |
| `func mfs.Mv(r *mfs.Root, src string, dst string) error` | `mv` | síncrona |
| `func mfs.PutNode(r *mfs.Root, path string, nd format.Node) error` | `putNode` | síncrona |
| `func mfs.FlushPath(ctx context.Context, rt *mfs.Root, pth string) (format.Node, error)` | `flushPath` | Future |
| `func mfs.Chmod(rt *mfs.Root, pth string, mode os.FileMode) error` | `chmod` | síncrona |
| `func mfs.Touch(rt *mfs.Root, pth string, ts time.Time) error` | `touch` | síncrona |
| `func mfs.IsDir(fsn mfs.FSNode) bool` | `isDir` | síncrona |
| `func mfs.IsFile(fsn mfs.FSNode) bool` | `isFile` | síncrona |
| `func (*mfs.Root).GetDirectory() *mfs.Directory` | `Root.getDirectory` | síncrona |
| `func (*mfs.Root).Flush() error` | `Root.flush` | síncrona |
| `func (*mfs.Root).FlushMemFree(ctx context.Context) error` | `Root.flushMemFree` | Future |
| `func (mfs.FSNode).GetNode() (format.Node, error)` | `FsNode.getNode` | síncrona |
| `func (mfs.FSNode).Flush() error` | `FsNode.flush` | síncrona |
| `func (mfs.FSNode).Type() mfs.NodeType` | `FsNode.type` | síncrona |
| `func (mfs.FSNode).SetMode(mode os.FileMode) error` | `FsNode.setMode` | síncrona |
| `func (mfs.FSNode).SetModTime(ts time.Time) error` | `FsNode.setModTime` | síncrona |
| `func (*mfs.Directory).Child(name string) (mfs.FSNode, error)` | `Directory.child` | síncrona |
| `func (*mfs.Directory).ListNames(ctx context.Context) ([]string, error)` | `Directory.listNames` | Future |
| `func (*mfs.Directory).List(ctx context.Context) ([]mfs.NodeListing, error)` | `Directory.list` | Future |
| `func (*mfs.Directory).Mkdir(name string) (*mfs.Directory, error)` | `Directory.mkdir` | síncrona |
| `func (*mfs.Directory).MkdirWithOpts(name string, opts ...mfs.Option) (*mfs.Directory, error)` | `Directory.mkdirWithOpts` | síncrona |
| `func (*mfs.Directory).Unlink(name string) error` | `Directory.unlink` | síncrona |
| `func (*mfs.Directory).Uncache(name string)` | `Directory.uncache` | síncrona |
| `func (*mfs.Directory).AddChild(name string, nd format.Node) error` | `Directory.addChild` | síncrona |
| `func (*mfs.Directory).Flush() error` | `Directory.flush` | síncrona |
| `func (*mfs.Directory).GetNode() (format.Node, error)` | `Directory.getNode` | síncrona |
| `func (*mfs.Directory).Path() string` | `Directory.path` | síncrona |
| `func (*mfs.Directory).Mode() (os.FileMode, error)` | `Directory.mode` | síncrona |
| `func (*mfs.Directory).ModTime() (time.Time, error)` | `Directory.modTime` | síncrona |
| `func (*mfs.File).Open(ctx context.Context, flags mfs.Flags) (_ mfs.FileDescriptor, _retErr error)` | `File.open` | Future |
| `func (*mfs.File).Size() (int64, error)` | `File.size` | síncrona |
| `func (*mfs.File).GetNode() (format.Node, error)` | `File.getNode` | síncrona |
| `func (*mfs.File).Flush() error` | `File.flush` | síncrona |
| `func (*mfs.File).Sync() error` | `File.sync` | síncrona |
| `func (*mfs.File).Mode() (os.FileMode, error)` | `File.mode` | síncrona |
| `func (*mfs.File).ModTime() (time.Time, error)` | `File.modTime` | síncrona |
| `(*mfs.File).RawLeaves bool` | `File.rawLeaves` | campo |
| `(*mfs.File).RawLeaves bool` | `File.rawLeaves =` | campo |
| `func (io.Reader).Read(p []byte) (n int, err error)` | `FileDescriptor.read` | síncrona |
| `func (mfs.FileDescriptor).CtxReadFull(context.Context, []byte) (int, error)` | `FileDescriptor.ctxReadFull` | Future |
| `func (io.Writer).Write(p []byte) (n int, err error)` | `FileDescriptor.write` | síncrona |
| `func (io.WriterAt).WriteAt(p []byte, off int64) (n int, err error)` | `FileDescriptor.writeAt` | síncrona |
| `func (io.Seeker).Seek(offset int64, whence int) (int64, error)` | `FileDescriptor.seek` | síncrona |
| `func (mfs.FileDescriptor).Truncate(int64) error` | `FileDescriptor.truncate` | síncrona |
| `func (mfs.FileDescriptor).Size() (int64, error)` | `FileDescriptor.size` | síncrona |
| `func (mfs.FileDescriptor).Flush() error` | `FileDescriptor.flush` | síncrona |
| `func (io.Closer).Close() error` | `FileDescriptor.close` | síncrona |
| `mfs.FSNode → x.(*mfs.Directory)` | `FsNode.asDirectory` | cast |
| `mfs.FSNode → x.(*mfs.File)` | `FsNode.asFile` | cast |

## `github.com/ipfs/boxo/peering` → `package:ipfs_ffi/boxo/peering.dart`

| Go | Dart | Modo |
|---|---|---|
| `func (*peering.PeeringService).AddPeer(info peer.AddrInfo)` | `PeeringService.addPeer` | síncrona |
| `func (*peering.PeeringService).RemovePeer(id peer.ID)` | `PeeringService.removePeer` | síncrona |
| `func (*peering.PeeringService).ListPeers() []peer.AddrInfo` | `PeeringService.listPeers` | síncrona |

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
| `format.Node → x.(*merkledag.ProtoNode)` | `Node.asProtoNode` | cast |
| `format.Node → x.(*merkledag.RawNode)` | `Node.asRawNode` | cast |

## `github.com/ipfs/kubo/config` → `package:ipfs_ffi/kubo/config.dart`

| Go | Dart | Modo |
|---|---|---|
| `func config.CreateIdentity(out io.Writer, opts []options.KeyGenerateOption) (config.Identity, error)` | `createIdentity` | síncrona |
| `func config.InitWithIdentity(identity config.Identity) (*config.Config, error)` | `initWithIdentity` | síncrona |
| `func config.ParseBootstrapPeers(addrs []string) ([]peer.AddrInfo, error)` | `parseBootstrapPeers` | síncrona |
| `func config.BootstrapPeerStrings(bps []peer.AddrInfo) []string` | `bootstrapPeerStrings` | síncrona |

## `github.com/ipfs/kubo/core` → `package:ipfs_ffi/kubo/core.dart`

| Go | Dart | Modo |
|---|---|---|
| `func core.NewNode(ctx context.Context, cfg *core.BuildCfg) (*core.IpfsNode, error)` | `newNode` | Future |
| `func (*core.IpfsNode).Close() error` | `IpfsNode.close` | Future |
| `(*core.IpfsNode).FilesRoot *mfs.Root` | `IpfsNode.filesRoot` | campo |
| `(*core.IpfsNode).FilesRoot *mfs.Root` | `IpfsNode.filesRoot =` | campo |
| `(*core.IpfsNode).Repo repo.Repo` | `IpfsNode.repo` | campo |
| `(*core.IpfsNode).Repo repo.Repo` | `IpfsNode.repo =` | campo |
| `(*core.IpfsNode).Peering *peering.PeeringService` | `IpfsNode.peering` | campo |
| `(*core.IpfsNode).Peering *peering.PeeringService` | `IpfsNode.peering =` | campo |

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
| `func (iface.RoutingAPI).Get(context.Context, string) ([]byte, error)` | `RoutingApi.get` | Future |
| `func (iface.RoutingAPI).Put(ctx context.Context, key string, value []byte, opts ...options.RoutingPutOption) error` | `RoutingApi.put` | Future |
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
| `func (iface.CoreAPI).WithOptions(...options.ApiOption) (iface.CoreAPI, error)` | `CoreApi.withOptions` | síncrona |
| `func (iface.CoreAPI).Object() iface.ObjectAPI` | `CoreApi.object` | síncrona |
| `func (iface.ObjectAPI).AddLink(ctx context.Context, base path.Path, name string, child path.Path, opts ...options.ObjectAddLinkOption) (path.ImmutablePath, error)` | `ObjectApi.addLink` | Future |
| `func (iface.ObjectAPI).RmLink(ctx context.Context, base path.Path, link string, opts ...options.ObjectRmLinkOption) (path.ImmutablePath, error)` | `ObjectApi.rmLink` | Future |
| `func (iface.ObjectAPI).Diff(context.Context, path.Path, path.Path) ([]iface.ObjectChange, error)` | `ObjectApi.diff` | Future |
| `func (iface.Reader).Size() uint64` | `Reader.size` | síncrona |
| `const iface.DiffAdd iface.ChangeType` | `diffAdd` | const |
| `const iface.DiffRemove iface.ChangeType` | `diffRemove` | const |
| `const iface.DiffMod iface.ChangeType` | `diffMod` | const |

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
| `func (repo.Repo).SetConfig(*config.Config) error` | `Repo.setConfig` | síncrona |
| `func (repo.Repo).SetConfigKey(key string, value any) error` | `Repo.setConfigKey` | síncrona |
| `func (repo.Repo).GetConfigKey(key string) (any, error)` | `Repo.getConfigKey` | síncrona |
| `func (repo.Repo).BackupConfig(prefix string) (string, error)` | `Repo.backupConfig` | síncrona |

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

- Namespaces: cada módulo Go num namespace (`kubo`, `boxo`, `ipld`, `multiformats`, `libp2p`, `go`; `car` fica para o `github.com/ipld/go-car`), com um arquivo `package:ipfs_ffi/<namespace>.dart` que exporta todas as libraries dele (`import 'package:ipfs_ffi/kubo.dart' as kubo;`); as libraries por pacote Go continuam embaixo. A tabela módulo → namespace fica em `go/gen/namespaces.go`.
- `context` (`package:ipfs_ffi/go/context.dart`, à mão): `background`, `withCancel`, `withTimeout`, `withDeadline`; `CancelFunc` é chamável (`cancel()`).
- `config.Profiles` (à mão): `profiles[nome]!.transform(cfg)`; no Go é um mapa de funções.
- `ipfs dag put`/`ipfs dag get` (`dagPut`/`dagGet` em `package:ipfs_ffi/kubo/core/commands/dag.dart`, porte à mão em `go/manual_dag.go`): no kubo é o corpo dos comandos, não função de biblioteca; mesmos padrões do CLI (dag-json → dag-cbor, limite de 2 MiB), hash padrão `sha2-256`.
- `ipfs dag export`/`ipfs dag import` (arquivos CAR; mesma library do `dagPut`/`dagGet`, porte à mão em `go/manual_car.go`): `dagExport`/`dagExportFile` (CARv1, `localOnly` = `--local-only`) e `dagImport`/`dagImportFiles` (CARv1/v2, `pinRoots` = `--pin-roots`, devolve raízes e estatísticas); recebem o `IpfsNode`, como o comando. Sem barra de progresso nem fast-provide do DAG inteiro; a raiz é anunciada pelo `Provide` da CoreAPI.
- Pubsub: o nó precisa de `node.BuildCfg(extraOpts: {'pubsub': true})` (o `Pubsub.Enabled` do daemon); `sub.next(ctx)` entrega uma mensagem por vez (o exemplo 08 a transforma em `Stream`).
- Handle concreto que implementa uma interface exposta estende a classe dela (`merkledag.RawNode`/`ProtoNode` → `Node`), para valer onde o Go aceita a interface; struct que embute interface é handle, não DTO.
- Mapa com chave tipo-valor (`map[peer.ID][]Multiaddr`) vira `Map<Id, List<Multiaddr>>`.
- Canal `chan<- T` passado numa opção (`options.Unixfs.Events`) vira `StreamSink<T>` (`options.unixfs.events(controller.sink)`); o tipo real dos itens de `chan<- any` vem da tabela `chanElem` do gerador (`AddEvent`). Como o `ipfs add`, o canal é fechado quando a chamada volta: todos os eventos chegam e o sink fecha antes do `Future` completar.
- Variável de pacote vira getter; tipo função nomeado (`libp2p.RoutingOption`) é handle opaco, criado só no Go.
- Métodos e funções com `context.Context` são assíncronos (`Future`); canais viram `Stream`; `(T, error)` vira `T` com `IpfsException`.
- Variádicos viram `List` opcional; opções funcionais espelham as variáveis do pacote (`options.unixfs.pin(true, '')`).
- `NewX` síncrono que devolve `X` do mesmo pacote vira `factory X(...)`.
- `io.Writer` em parâmetro não aparece no Dart: o Go usa `io.Discard`.
- `fsrepo.Open`: o host limpa o caminho (`repoPath`, a forma que o `Repo.Path()` devolve) antes de abrir, para os comandos de config, que reabrem o repo pelo `Path()`, reaproveitarem o repo aberto (o `fsrepo` guarda o aberto pela string crua).
- Inteiros `uint64` vão com os mesmos 64 bits num `int` do Dart (como o `Uint64List`): de 2^63 para cima saem negativos; `BigInt.from(v).toUnsigned(64)` os lê sem sinal (a doc de cada campo avisa).
- `io.Reader` em parâmetro aceita `Uint8List` ou um handle de leitor (ex. o `files.File` devolvido pelo kubo).
- Tipos-valor (CID, path, peer ID, multiaddr) guardam a string; a validação acontece no Go, quando atravessam.
- `config.Config` guarda o JSON do kubo (o mesmo do arquivo `config` do repo) em `json`.
- Resultado `nil` do Go onde o Dart espera um objeto vira `IpfsException`.
- O kubo roda no `ipfs_host`, noutro processo (`IpfsService.start()` antes da API; protocolo no `WIRE.md`): um panic do Go derruba só o serviço, e as chamadas pendentes falham com `IpfsServiceException`.
- Handles são soltos pelo `Finalizer` do Dart (em lote, pela função Free do serviço) e só valem no serviço em que nasceram; recursos do Go (nó, repo) continuam exigindo o `Close` do próprio Go.

## Comandos do RPC (`ipfs ...`) → `package:ipfs_ffi/kubo/core/commands.dart`

Gerados da árvore de comandos do kubo (`core/commands.Root`); o host os chama como o servidor HTTP do kubo (função 36 do `WIRE.md`).

| Comando | Dart | Retorno |
|---|---|---|
| `ipfs add` | `add` | `Stream<CommandsAddEvent>` |
| `ipfs bitswap ledger` | `bitswapLedger` | `Stream<Receipt>` |
| `ipfs bitswap reprovide` | `bitswapReprovide` | `Stream<Object?>` |
| `ipfs bitswap stat` | `bitswapStat` | `Stream<Stat>` |
| `ipfs bitswap wantlist` | `bitswapWantlist` | `Stream<KeyList>` |
| `ipfs block get` | `blockGet` | `Stream<Uint8List>` |
| `ipfs block put` | `blockPut` | `Stream<CommandsBlockStat>` |
| `ipfs block rm` | `blockRm` | `Stream<RemovedBlock>` |
| `ipfs block stat` | `blockStat` | `Stream<CommandsBlockStat>` |
| `ipfs bootstrap` | `bootstrap` | `Stream<BootstrapOutput>` |
| `ipfs bootstrap add` | `bootstrapAdd` | `Stream<BootstrapOutput>` |
| `ipfs bootstrap list` | `bootstrapList` | `Stream<BootstrapOutput>` |
| `ipfs bootstrap rm` | `bootstrapRm` | `Stream<BootstrapOutput>` |
| `ipfs bootstrap rm all` | `bootstrapRmAll` | `Stream<BootstrapOutput>` |
| `ipfs cat` | `cat` | `Stream<Uint8List>` |
| `ipfs cid base32` | `cidBase32` | `Stream<CidFormatRes>` |
| `ipfs cid bases` | `cidBases` | `Stream<List<CodeAndName>>` |
| `ipfs cid codecs` | `cidCodecs` | `Stream<List<CodeAndName>>` |
| `ipfs cid format` | `cidFormat` | `Stream<CidFormatRes>` |
| `ipfs cid hashes` | `cidHashes` | `Stream<List<CodeAndName>>` |
| `ipfs cid inspect` | `cidInspect` | `Stream<CidInspectRes>` |
| `ipfs config` | `config` | `Stream<ConfigField>` |
| `ipfs config profile apply` | `configProfileApply` | `Stream<ConfigUpdateOutput>` |
| `ipfs config replace` | `configReplace` | `Stream<Object?>` |
| `ipfs config show` | `configShow` | `Stream<Map<String, Object?>>` |
| `ipfs dag resolve` | `dagResolve` | `Stream<ResolveOutput>` |
| `ipfs dag stat` | `dagStat` | `Stream<DagStatSummary>` |
| `ipfs dht query` | `dhtQuery` | `Stream<QueryEvent>` |
| `ipfs diag cmds` | `diagCmds` | `Stream<List<ReqLogEntry?>>` |
| `ipfs diag cmds clear` | `diagCmdsClear` | `Stream<Object?>` |
| `ipfs diag cmds set-time` | `diagCmdsSetTime` | `Stream<Object?>` |
| `ipfs diag datastore count` | `diagDatastoreCount` | `Stream<DiagDatastoreCountResult>` |
| `ipfs diag datastore get` | `diagDatastoreGet` | `Stream<DiagDatastoreGetResult>` |
| `ipfs diag datastore put` | `diagDatastorePut` | `Stream<Object?>` |
| `ipfs diag healthy` | `diagHealthy` | `Stream<Object?>` |
| `ipfs diag profile` | `diagProfile` | `Stream<Uint8List>` |
| `ipfs diag sys` | `diagSys` | `Stream<Object?>` |
| `ipfs files chcid` | `filesChcid` | `Stream<Object?>` |
| `ipfs files chmod` | `filesChmod` | `Stream<Object?>` |
| `ipfs files chroot` | `filesChroot` | `Stream<MessageOutput>` |
| `ipfs files cp` | `filesCp` | `Stream<Object?>` |
| `ipfs files flush` | `filesFlush` | `Stream<FlushRes>` |
| `ipfs files ls` | `filesLs` | `Stream<FilesLsOutput>` |
| `ipfs files mkdir` | `filesMkdir` | `Stream<Object?>` |
| `ipfs files mv` | `filesMv` | `Stream<Object?>` |
| `ipfs files read` | `filesRead` | `Stream<Uint8List>` |
| `ipfs files rm` | `filesRm` | `Stream<Object?>` |
| `ipfs files stat` | `filesStat` | `Stream<StatOutput>` |
| `ipfs files touch` | `filesTouch` | `Stream<Object?>` |
| `ipfs files write` | `filesWrite` | `Stream<Object?>` |
| `ipfs filestore dups` | `filestoreDups` | `Stream<RefWrapper>` |
| `ipfs filestore ls` | `filestoreLs` | `Stream<ListRes>` |
| `ipfs filestore verify` | `filestoreVerify` | `Stream<ListRes>` |
| `ipfs get` | `get` | `Stream<Uint8List>` |
| `ipfs id` | `id` | `Stream<IdOutput>` |
| `ipfs key export` | `keyExport` | `Stream<Uint8List>` |
| `ipfs key gen` | `keyGen` | `Stream<KeyOutput>` |
| `ipfs key import` | `keyImport` | `Stream<KeyOutput>` |
| `ipfs key list` | `keyList` | `Stream<KeyOutputList>` |
| `ipfs key ls` | `keyLs` | `Stream<KeyOutputList>` |
| `ipfs key rename` | `keyRename` | `Stream<KeyRenameOutput>` |
| `ipfs key rm` | `keyRm` | `Stream<KeyOutputList>` |
| `ipfs key rotate` | `keyRotate` | `Stream<Object?>` |
| `ipfs key sign` | `keySign` | `Stream<KeySignOutput>` |
| `ipfs key verify` | `keyVerify` | `Stream<KeyVerifyOutput>` |
| `ipfs log level` | `logLevel` | `Stream<LogLevelOutput>` |
| `ipfs log ls` | `logLs` | `Stream<StringList>` |
| `ipfs log tail` | `logTail` | `Stream<Uint8List>` |
| `ipfs ls` | `ls` | `Stream<LsOutput>` |
| `ipfs multibase decode` | `multibaseDecode` | `Stream<Uint8List>` |
| `ipfs multibase encode` | `multibaseEncode` | `Stream<Uint8List>` |
| `ipfs multibase list` | `multibaseList` | `Stream<List<CodeAndName>>` |
| `ipfs multibase transcode` | `multibaseTranscode` | `Stream<Uint8List>` |
| `ipfs name get` | `nameGet` | `Stream<Uint8List>` |
| `ipfs name inspect` | `nameInspect` | `Stream<IpnsInspectResult>` |
| `ipfs name publish` | `namePublish` | `Stream<IpnsEntry>` |
| `ipfs name pubsub cancel` | `namePubsubCancel` | `Stream<IpnsPubsubCancel>` |
| `ipfs name pubsub state` | `namePubsubState` | `Stream<IpnsPubsubState>` |
| `ipfs name pubsub subs` | `namePubsubSubs` | `Stream<NameStringList>` |
| `ipfs name put` | `namePut` | `Stream<IpnsEntry>` |
| `ipfs name resolve` | `nameResolve` | `Stream<ResolvedPath>` |
| `ipfs object diff` | `objectDiff` | `Stream<Changes>` |
| `ipfs object patch add-link` | `objectPatchAddLink` | `Stream<Object$>` |
| `ipfs object patch rm-link` | `objectPatchRmLink` | `Stream<Object$>` |
| `ipfs p2p close` | `p2pClose` | `Stream<int>` |
| `ipfs p2p forward` | `p2pForward` | `Stream<P2pForegroundOutput>` |
| `ipfs p2p listen` | `p2pListen` | `Stream<P2pForegroundOutput>` |
| `ipfs p2p ls` | `p2pLs` | `Stream<P2pLsOutput>` |
| `ipfs p2p stream close` | `p2pStreamClose` | `Stream<Object?>` |
| `ipfs p2p stream ls` | `p2pStreamLs` | `Stream<P2pStreamsOutput>` |
| `ipfs pin add` | `pinAdd` | `Stream<AddPinOutput>` |
| `ipfs pin ls` | `pinLs` | `Stream<PinLsOutputWrapper>` |
| `ipfs pin remote add` | `pinRemoteAdd` | `Stream<RemotePinOutput>` |
| `ipfs pin remote ls` | `pinRemoteLs` | `Stream<RemotePinOutput>` |
| `ipfs pin remote rm` | `pinRemoteRm` | `Stream<Object?>` |
| `ipfs pin remote service add` | `pinRemoteServiceAdd` | `Stream<Object?>` |
| `ipfs pin remote service ls` | `pinRemoteServiceLs` | `Stream<PinServicesList>` |
| `ipfs pin remote service rm` | `pinRemoteServiceRm` | `Stream<Object?>` |
| `ipfs pin rm` | `pinRm` | `Stream<PinOutput>` |
| `ipfs pin update` | `pinUpdate` | `Stream<PinOutput>` |
| `ipfs pin verify` | `pinVerify` | `Stream<PinVerifyRes>` |
| `ipfs ping` | `ping` | `Stream<PingResult>` |
| `ipfs provide clear` | `provideClear` | `Stream<int>` |
| `ipfs provide once` | `provideOnce` | `Stream<ProvideOnceEvent>` |
| `ipfs provide stat` | `provideStat` | `Stream<ProvideStats>` |
| `ipfs pubsub ls` | `pubsubLs` | `Stream<StringList>` |
| `ipfs pubsub peers` | `pubsubPeers` | `Stream<StringList>` |
| `ipfs pubsub pub` | `pubsubPub` | `Stream<Object?>` |
| `ipfs pubsub reset` | `pubsubReset` | `Stream<PubsubResetResult>` |
| `ipfs pubsub sub` | `pubsubSub` | `Stream<PubsubMessage>` |
| `ipfs refs` | `refs` | `Stream<RefWrapper>` |
| `ipfs refs local` | `refsLocal` | `Stream<RefWrapper>` |
| `ipfs repo gc` | `repoGc` | `Stream<GcResult>` |
| `ipfs repo ls` | `repoLs` | `Stream<RefWrapper>` |
| `ipfs repo migrate` | `repoMigrate` | `Stream<Object?>` |
| `ipfs repo stat` | `repoStat` | `Stream<CorerepoStat>` |
| `ipfs repo verify` | `repoVerify` | `Stream<VerifyProgress>` |
| `ipfs repo version` | `repoVersion` | `Stream<RepoVersion>` |
| `ipfs resolve` | `resolve` | `Stream<ResolvedPath>` |
| `ipfs routing findpeer` | `routingFindpeer` | `Stream<QueryEvent>` |
| `ipfs routing findprovs` | `routingFindprovs` | `Stream<QueryEvent>` |
| `ipfs routing get` | `routingGet` | `Stream<QueryEvent>` |
| `ipfs routing provide` | `routingProvide` | `Stream<QueryEvent>` |
| `ipfs routing put` | `routingPut` | `Stream<QueryEvent>` |
| `ipfs routing reprovide` | `routingReprovide` | `Stream<Object?>` |
| `ipfs stats bitswap` | `statsBitswap` | `Stream<Stat>` |
| `ipfs stats bw` | `statsBw` | `Stream<MetricsStats>` |
| `ipfs stats dht` | `statsDht` | `Stream<DhtStat>` |
| `ipfs stats provide` | `statsProvide` | `Stream<ProvideStats>` |
| `ipfs stats repo` | `statsRepo` | `Stream<CorerepoStat>` |
| `ipfs stats reprovide` | `statsReprovide` | `Stream<ProvideStats>` |
| `ipfs swarm addrs` | `swarmAddrs` | `Stream<AddrMap>` |
| `ipfs swarm addrs autonat` | `swarmAddrsAutonat` | `Stream<AutoNatResult>` |
| `ipfs swarm addrs listen` | `swarmAddrsListen` | `Stream<StringList>` |
| `ipfs swarm addrs local` | `swarmAddrsLocal` | `Stream<StringList>` |
| `ipfs swarm connect` | `swarmConnect` | `Stream<StringList>` |
| `ipfs swarm disconnect` | `swarmDisconnect` | `Stream<StringList>` |
| `ipfs swarm filters` | `swarmFilters` | `Stream<StringList>` |
| `ipfs swarm filters add` | `swarmFiltersAdd` | `Stream<StringList>` |
| `ipfs swarm filters rm` | `swarmFiltersRm` | `Stream<StringList>` |
| `ipfs swarm peering add` | `swarmPeeringAdd` | `Stream<PeeringResult>` |
| `ipfs swarm peering ls` | `swarmPeeringLs` | `Stream<AddrInfos>` |
| `ipfs swarm peering rm` | `swarmPeeringRm` | `Stream<PeeringResult>` |
| `ipfs swarm peers` | `swarmPeers` | `Stream<ConnInfos>` |
| `ipfs swarm resources` | `swarmResources` | `Stream<LimitsConfigAndUsage>` |
| `ipfs version` | `version` | `Stream<VersionInfo>` |
| `ipfs version check` | `versionCheck` | `Stream<VersionCheckOutput>` |
| `ipfs version deps` | `versionDeps` | `Stream<Dependency>` |

Fora:

- `ipfs commands`: a ajuda do CLI
- `ipfs commands completion bash`: a ajuda do CLI
- `ipfs commands completion fish`: a ajuda do CLI
- `ipfs commands completion zsh`: a ajuda do CLI
- `ipfs config edit`: abre o $EDITOR no processo do host
- `ipfs dag export`: porte à mão com o mesmo nome (`kubo/core/commands/dag.dart`)
- `ipfs dag get`: porte à mão com o mesmo nome (`kubo/core/commands/dag.dart`)
- `ipfs dag import`: porte à mão com o mesmo nome (`kubo/core/commands/dag.dart`)
- `ipfs dag put`: porte à mão com o mesmo nome (`kubo/core/commands/dag.dart`)
- `ipfs mount`: FUSE: monta no sistema de arquivos do host
- `ipfs shutdown`: desliga o daemon; no ipfs_ffi é `IpfsNode.close`/`IpfsService.stop`
- `ipfs update check`: atualiza o binário do kubo (não é o caso do ipfs_host)
- `ipfs update clean`: atualiza o binário do kubo (não é o caso do ipfs_host)
- `ipfs update install`: atualiza o binário do kubo (não é o caso do ipfs_host)
- `ipfs update revert`: atualiza o binário do kubo (não é o caso do ipfs_host)
- `ipfs update versions`: atualiza o binário do kubo (não é o caso do ipfs_host)
