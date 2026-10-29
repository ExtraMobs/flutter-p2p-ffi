# p2p_ffi

Peer-to-peer networking from Go, used from Dart: [kubo](https://github.com/ipfs/kubo) (an
IPFS node), [boxo](https://github.com/ipfs/boxo) (its building blocks) and
[go-libp2p](https://github.com/libp2p/go-libp2p), at the versions pinned in
[`go/go.mod`](go/go.mod), without HTTP. The Go code runs in the `p2p_host` executable, in
another process, and the app talks to it through shared memory (the `p2p_shm`, in C; binary
protocol in [`WIRE.md`](WIRE.md)). A Go panic stops only the service, never the app.
Targets: VM/AOT on Windows, linux and Android (not JS/Wasm).

The Dart API is Go's own, generated: the same functions, types and argument order as in
pkg.go.dev, so the Go documentation applies. One import brings all of it,
`package:p2p_ffi/p2p_ffi.dart`. A Go package's functions, constants and variables hang
from `Go`, one getter per segment of the package's path in its module (the module named
without `go-` and the major version, the Go standard library beside the modules). Dart has
no nested types, so a type is a top-level class named after the same path, minus the words
the Go name already starts with:

| Go | Dart |
|---|---|
| `mfs.NewRoot` (`github.com/ipfs/boxo/mfs`) | `Go.boxo.mfs.newRoot` |
| `mfs.Root` | `BoxoMfsRoot` |
| `fsrepo.Open` (`github.com/ipfs/kubo/repo/fsrepo`) | `Go.kubo.repo.fsrepo.open` |
| `cid.Decode`, `cid.Cid` (`github.com/ipfs/go-cid`) | `Go.cid.decode`, `Cid` |
| `index.ReadFrom` (`github.com/ipld/go-car/v2/index`) | `Go.car.v2.index.readFrom` |
| `context.Background`, `context.Context` | `Go.context.background`, `Context` |
| `peer.ID` (`github.com/libp2p/go-libp2p/core/peer`) | `Libp2pCorePeerId` |

Every name is unique in the import. A package constant is a getter (`Go.multicodec.raw`),
so it is not a Dart `const`.

| Document | What it has |
|---|---|
| [`API.md`](API.md) | every exposed symbol, and what was left out and why (generated) |
| [`CHANGELOG.md`](CHANGELOG.md) | what changed in each version |
| [`TODO.md`](TODO.md) | measurements, findings and what is pending |
| [`WIRE.md`](WIRE.md) | the binary protocol between the app and the host |

## Quick start

```dart
import 'dart:convert';

import 'package:p2p_ffi/p2p_ffi.dart';

await P2pService.start(onStop: (stop) => print('${stop.reason}: ${stop.report}'));
KuboPluginLoader('')..initialize()..inject(); // once per service
final options = Go.kubo.core.coreiface.options;
Go.kubo.repo.fsrepo.init(repo, Go.kubo.config.initWithIdentity(
    Go.kubo.config.createIdentity(null, [options.key.type('ed25519')])));
final ctx = Go.context.background();
final n = await Go.kubo.core.newNode(
    ctx, KuboCoreNodeBuildCfg(repo: Go.kubo.repo.fsrepo.open(repo)));
final api = Go.kubo.core.coreapi.newCoreApi(n);
final p = await api.unixfs().add(ctx, Go.boxo.files.newBytesFile(utf8.encode('hi')),
    [options.unixfs.pin(true, '')]);
print(utf8.decode(Go.io.readAll(Go.boxo.files.toFile(await api.unixfs().get(ctx, p)))));
await n.close();
await P2pService.stop();
```

## How Go becomes Dart

- `context.Context` is the first parameter, as in Go (`Go.context.background`,
  `withCancel`, `withTimeout`, `withDeadline`; call `cancel()`).
- A function with a `context` is asynchronous (`Future`); a channel is a `Stream`;
  `(T, error)` is `T`, and the error is thrown as `GolangException`.
- `if err != nil` disappears: Go errors are exceptions. Every exported error sentinel and
  error type of an exposed package has its class, named after its package
  (`on IoFsErrNotExist`, `on IoFsPathError catch (e) { e.path }`); `io.EOF`,
  `io.ErrUnexpectedEOF`, `context.Canceled`, `context.DeadlineExceeded` and IPLD's not
  found keep `GolangEofException`, `GolangUnexpectedEofException`,
  `GolangCanceledException`, `GolangDeadlineExceededException`, `GolangNotFoundException`.
  Any `GolangException`, the text-only ones too, carries `errTexts` (the chain's texts,
  from the outside in; `errText` is the original cause), `errno` (the `syscall.Errno` of
  the chain, if any) and `causes`; `e.isA<T>()` and `e.find<T>()` are Go's `errors.Is`
  and `errors.As`.
- Functional options are a list (`[options.unixfs.cidVersion(1), options.unixfs.pin(true, '')]`);
  option structs take named parameters (`BoxoMfsFlags(write: true)`).
- Struct fields are getters and setters (`node.filesRoot`); `any` is `Object?`.
- A type assertion is a cast that returns null when it does not match
  (`Go.boxo.mfs.lookup(root, '/a').asBoxoMfsFile()`).
- `Read`/`ReadAt`/`CtxReadFull` take a size and return the bytes read.
- A Go function that takes a function takes a Dart function (a callback; returning `false`
  or throwing stops Go). A function Go keeps, like a stream handler, is called on the event
  loop for as long as Go holds it; an interface root (`mdns.Notifee`) is implemented in
  Dart with one function per method
  (`Libp2pP2pDiscoveryMdnsNotifee(handlePeerFound: (pi) {...})`).
- `time.Duration` is a `Duration`.
- Where Go reflects on an `any`, the generator fixes the type: a pubsub validator is a Dart
  function, an event type goes by example as its class's `$type`
  (`Libp2pCoreEventEvtPeerConnectednessChanged.$type`), and a Go constructor as a token
  (`Go.libp2p.transport(Go.libp2p.p2p.transport.tcp.newTcpTransportFunc)`).
- CID, path, peer ID and multiaddr are values (their text form); objects with state stay in
  Go, behind a handle.

The kubo RPC commands (`ipfs files ...`, `ipfs pin ls`, `ipfs cat`...) are also available,
running against the app's node: one function per command in `Go.kubo.core.commands`, each
returning a `Stream`; their result types are named after their Go packages
(`await Go.kubo.core.commands.filesStat(n, ctx, '/a').single`).

## Examples

| Path | What it covers |
|---|---|
| [`example/en_us/`](example/en_us/README.md) | the course for Dart developers new to IPFS, one lesson per question (21 lessons: the bridge, CIDs, blocks and CAR; the kubo node; the network, DHT and bitswap; deadlines, handles and callbacks); also in [Português (Brasil)](example/pt_br/README.md) and [Español](example/es/README.md) |
| [`example/android_app/`](example/android_app) | the Flutter validation app (packaging, background, integration tests) |

## Points of attention

### Storage and GC

- **The GC never runs on its own.** `Datastore.StorageMax`, `StorageGCWatermark` and
  `GCPeriod` only act through `PeriodicGC`, which kubo starts only in the daemon. Start it
  yourself with a context you cancel on close:

  ```dart
  final (gcCtx, stopGc) = context.withCancel(ctx);
  unawaited(corerepo.periodicGc(gcCtx, node));
  ```
- **The GC removes everything that is not pinned**, not the oldest blocks. The CoreAPI does
  not pin by default: pass `options.unixfs.pin(true, name)` on `add` (the CLI does that).
- **`cat`/`get` keep every block they fetch** in the repo (the block service caches them).
  To read without storing, use a block service over the null datastore and the node's
  exchange:

  ```dart
  final dag = merkledag.newDagService(blockservice.new$(
      blockstore.Blockstore(datastore.NullDatastore()), node.exchange));
  final file = files.toFile(await unixfile.newUnixfsFile(ctx, dag, await dag.get(ctx, cid)));
  await for (final chunk in io_stream.readerStream(file)) sink.add(chunk);
  ```

  Nothing is kept, so the node does not serve those blocks, and blocks already in the repo
  are fetched again.
- **A pin lock holds the GC off.** `node.gcLocker.pinLock(ctx)` keeps the GC waiting until
  `unlock`, for put → pin sequences that must not race it. `node.blockstore.deleteBlock`
  removes single blocks without a full GC.

### Config

- **Most config only applies when the node starts.** Change it before `newNode`
  (`repo.setConfigKey`); the config passed to `init` only matters for a new repo. Peering
  (`node.peering.addPeer`) applies at once but is not saved.
- **The resource manager's limits are fixed at run time**: set `Swarm.ResourceMgr` and
  restart. `node.resourceManager.viewSystem` only reads the usage.
- **Bitswap fetches over libp2p and over HTTP** (trustless gateways) by default. Over HTTP the
  server sees the CIDs, the device IP and the User-Agent; limit it with
  `HTTPRetrieval.Allowlist`/`Denylist` or turn it off with `HTTPRetrieval.Enabled`. With both
  `Bitswap.Libp2pEnabled` and `HTTPRetrieval.Enabled` off, the node does not start.
  `Bitswap.ServerEnabled = false` downloads without serving anyone.

### The service and handles

- **The service does not come back on its own.** After a crash (or a stop in the Android
  background) pending calls fail with `P2pServiceException` and `onStop` gets the reason
  and Go's report. `P2pService.restart()` starts a new process: inject the plugins again
  and rebuild node and CoreAPI; handles from the old service are no longer valid.
- **A panic inside a kubo goroutine** (outside a call) stops the host. Pass
  `P2pService.start(crashLog: path)` to get Go's report; the host only appends to it.
- **Release handles in loops.** The Dart `Finalizer` frees Go objects late, while each
  handle may pin megabytes in the host. Use `.release()`, `.use()` or `withGoScope()`
  (lesson 20 of the course). The node and the repo still need `close()`.
- **Synchronous calls block the isolate** until the host answers (`Go.io.copy` of a large file,
  for example); calls with a `context` are `Future`s.
- **A command `Stream` only runs when listened to**: `.single`, `.first`, `toList()` or
  `drain()`. Cancelling the subscription of `io_stream.readerStream` or of a command does not stop
  Go; cancel the context instead.
- **Objects a callback receives are valid only during the invocation** (that is why their
  default `batchSize` is 1). Calling into Go from a callback is allowed; if it waits on a lock
  the Go function holds, the call throws `GolangDeadlockException` instead of hanging.
- **`uint64` values travel in an `int`**: the same 64 bits, so values above `2^63` read as
  negative.

### Network

- **`routing().provide` only queues the announcement**: a lookup right after may need a retry.
- **`Unprotect` returns whether other tags still protect the peer**, not whether it was
  protected; peering protects its own peers too.
- **libp2p without kubo** (`Go.libp2p.new$([...])`): a host has only what its options give it.
  Without `Go.libp2p.identity(key)` the peer ID changes at each start (keep
  `Go.libp2p.core.crypto.marshalPrivateKey`); there is no DHT, pubsub or mDNS until you create them on the
  host, and the default listen addresses are on every interface (Windows asks for the
  firewall; `listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])` stays local).
- **`newStream` negotiates the protocol lazily**: a peer without the handler fails on the
  first read, not on `newStream`. `io_stream.readerStream` on a stream closes only its read
  side, so it can still answer.
- **A stream handler runs on the Dart event loop**, one call per incoming stream; it is never
  waited for by Go, so close the stream when done.
- **mDNS listens on `0.0.0.0:5353`** even for a loopback host.
- **A pubsub validator runs per message and Go waits for it**: keep it fast, and do not let
  a synchronous call wait on a publish while it runs. Validation is parallel, so messages
  may arrive out of order; an exception rejects the message.
- **Do not wait synchronously on what a retained callback holds.** Pubsub's methods that
  go through its event loop are `Future`s for that reason (the loop runs the subscription
  filter and waits for Dart).
- **A subscription keeps 32 messages by default** (`Go.libp2pPubsub.withBufferSize`): Dart pulls them
  one at a time with `next()`, so a burst beyond that is dropped. On a phone, 39 of a burst
  of 200 arrived with the default and 200 of 200 with `withBufferSize(256)`.
- **A function given to an option runs per message or per peer** (`withMessageFilter`,
  `withMessageIdFn`, `withPeerFilter`, the DHT's `queryFilter`...): Go waits for Dart each
  time (tens of µs on Windows, ms on an Android emulator).
- **The event bus channel must be drained** (`sub.out()` listened to, or `sub.close()`):
  libp2p's publishers block on a full subscription.
- **On linux, QUIC asks for bigger UDP buffers** (a warning, not an error):
  `sudo sysctl -w net.core.rmem_max=7500000 net.core.wmem_max=7500000`.

### CAR files

- go-car's `has` matches multihashes unless `useWholeCids(true)`.
- Wrapping a CARv2 again is accepted and produces a broken file.
- UnixFS selectors need the dag-pb prototype chooser
  (`Go.car.v2.withTraversalPrototypeChooser(Go.codecDagpb.addSupportToChooser(Go.boxo.fetcher.impl.blockservice.defaultPrototypeChooser))`),
  or the traversal stops at the directory.
- go-car's `AttachIndex` always fails (upstream bug).

### Android

- **Background:** the host is a child process of the app; on Android 12+ the phantom
  process killer kills it, and the app with it, if it uses CPU in the background. Choose
  `P2pService.background`: `P2pBackground.stop` (default; restart on return) or
  `P2pBackground.foregroundService` (a foreground service with a notification; ask for
  `POST_NOTIFICATIONS` with `P2pFfiFlutter.requestNotificationPermission()`). The
  [`p2p_ffi_flutter`](flutter) plugin registers itself.
- **DNS:** Go cannot find the system resolver on Android; configure `DNS.Resolvers`
  (DNS over HTTPS).
- **Packaging:** the host must be extracted from the APK
  (`packaging.jniLibs.useLegacyPackaging = true`); mDNS needs a `WifiManager.MulticastLock`.
- **Gradle flags:** set `android.builtInKotlin=true` in the app's `gradle.properties`
  (Flutter's migrator writes `false` only when the key is missing) to drop the Kotlin
  plugin deprecations; keep `android.newDsl=false`, because Flutter's Gradle plugin does
  not build with the new DSL yet.
- **NAT:** relay connections last up to 2 minutes and carry neither pubsub nor bitswap.
  Between two devices behind carrier NAT the direct connection comes over IPv6 or when one
  side is reachable; `hasIpv6()` tells whether the network delivers global IPv6.

## Build

- `dart run tool/build.dart [windows|linux|android]`: runs the generator and builds the host
  and the `p2p_shm` into `native/` (not in git). Needs Go (`GOTOOLCHAIN=auto` downloads the
  pinned one) and a C compiler for the `p2p_shm`: mingw-w64 on Windows, gcc on linux, the NDK
  for Android.
- **To expose more of Go:** a line `package.*` in `go/gen/roots.txt` takes every exported
  function, variable and method of the package; a symbol the generator cannot bridge is
  skipped (API.md lists it with the reason), and `go/gen/ignore_roots.txt` drops, with the
  reason, what must not cross. The other lines of `roots.txt` are the special roots
  (`package.Function` of a package without `.*`, a struct field, a method inherited by
  embedding). Then build.
- `go run ./gen -check` (in `go/`) fails when the generated files are out of date.
- **Upstream patches:** the build patches two kubo/boxo bugs and stops if the patched code
  moves in a new version; `go/upstream_test.go` fails once upstream fixes them, and then the
  patch and its line here go:
  - [ipfs/boxo#1221](https://github.com/ipfs/boxo/issues/1221): appending to an MFS file
    whose node keeps its data inline (a small `add`) left the right size, but reading
    returned only the appended part;
  - [ipfs/kubo#11477](https://github.com/ipfs/kubo/issues/11477): with `Routing.Type` none,
    `close` left the `provider-keystore` datastore open, and reopening the repo in the same
    process hit the lock.
- Tests: `dart test` (needs the build). Android: `flutter test integration_test -d <device>` in
  `example/android_app/`. Linux through WSL works with the linux `dart` and Go installed inside
  WSL (the Windows `dart` leaks into the WSL `PATH`).
