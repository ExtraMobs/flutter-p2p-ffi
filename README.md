# ipfs_ffi

Kubo (IPFS in Go, the version pinned in [`go/go.mod`](go/go.mod)) used from Dart without
HTTP. Kubo runs in the `ipfs_host` executable, in another process, and the app talks to it
through shared memory (the `ipfs_shm`, in C; binary protocol in [`WIRE.md`](WIRE.md)). A Go
panic stops only the service, never the app. Targets: VM/AOT on Windows, linux and Android
(not JS/Wasm).

The Dart API is Go's own, generated: the same functions, types and argument order as in
pkg.go.dev, so the Go documentation applies. It is organized in namespaces, one per Go
module: `kubo`, `boxo`, `ipld`, `multiformats`, `libp2p`, `car`, `datastore` and `go` (the
standard library pieces the API uses). Import a whole namespace
(`package:ipfs_ffi/kubo.dart`) or one Go package at a time
(`package:ipfs_ffi/kubo/repo/fsrepo.dart`).

| Document | What it has |
|---|---|
| [`API.md`](API.md) | every exposed symbol, and what was left out and why (generated) |
| [`DOCS.md`](DOCS.md) | the CAR examples, indexed by operation |
| [`CHANGELOG.md`](CHANGELOG.md) | what changed in each version |
| [`TODO.md`](TODO.md) | measurements, findings and what is pending |
| [`WIRE.md`](WIRE.md) | the binary protocol between the app and the host |

## Quick start

```dart
import 'dart:convert';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/kubo.dart' as kubo;

await IpfsService.start(onStop: (stop) => print('${stop.reason}: ${stop.report}'));
kubo.PluginLoader('')..initialize()..inject(); // once per service
kubo.init(repo, kubo.initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')])));
final ctx = go.background();
final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repo)));
final api = kubo.newCoreApi(n);
final p = await api.unixfs().add(ctx, boxo.newBytesFile(utf8.encode('hi')),
    [kubo.unixfs.pin(true, '')]);
print(utf8.decode(go.readAll(boxo.toFile(await api.unixfs().get(ctx, p)))));
await n.close();
await IpfsService.stop();
```

## How Go becomes Dart

- `context.Context` is the first parameter, as in Go (`background`, `withCancel`,
  `withTimeout`, `withDeadline`; call `cancel()`).
- A function with a `context` is asynchronous (`Future`); a channel is a `Stream`;
  `(T, error)` is `T`, and the error is thrown as `IpfsException`.
- `if err != nil` disappears: Go errors are exceptions. Known Go sentinels are subclasses:
  `IpfsEof`, `IpfsUnexpectedEof`, `IpfsCanceled`, `IpfsDeadlineExceeded`, `IpfsNotFound`.
- Functional options are a list (`[options.unixfs.cidVersion(1), options.unixfs.pin(true, '')]`);
  option structs take named parameters (`mfs.Flags(write: true)`).
- Struct fields are getters and setters (`node.filesRoot`); constants are `const`;
  `any` is `Object?`.
- A type assertion is a cast that returns null when it does not match
  (`mfs.lookup(root, '/a').asFile()`).
- `Read`/`ReadAt`/`CtxReadFull` take a size and return the bytes read.
- A Go function that takes a function takes a Dart function (a callback; returning `false`
  or throwing stops Go).
- CID, path, peer ID and multiaddr are values (their text form); objects with state stay in
  Go, behind a handle.

The kubo RPC commands (`ipfs files ...`, `ipfs pin ls`, `ipfs cat`...) are also available,
running against the app's node: one function per command in
`package:ipfs_ffi/kubo/core/commands.dart`, each returning a `Stream`
(`await kubo.filesStat(n, ctx, '/a').single`).

## Examples

| Path | What it covers |
|---|---|
| `example/01_init_repo.dart` … `example/08_chat.dart` | in the order kubo builds a node: init, add/get, pins and GC, online node, two nodes, IPNS and Dag, CAR, pubsub chat |
| `example/09_comandos_e_streams.dart` | the RPC commands and Dart `Stream`s step by step |
| `example/10_mfs_baixo_nivel.dart`, `example/12_car_baixo_nivel.dart` | boxo MFS and go-car at the low level, with the equivalent Go |
| `example/11_contexto_e_erros.dart` | deadlines, cancellation, errors, service crash and restart |
| `example/13_recorte_e_callbacks.dart` | CAR slices from the node, selectors, callbacks |
| [`example/car/`](example/car) | everyday CAR operations, the right way and the mistakes ([`DOCS.md`](DOCS.md)) |
| [`example/memory/`](example/memory) | how handles work and how to release them |
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
  await for (final chunk in go.readerStream(file)) sink.add(chunk);
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
  background) pending calls fail with `IpfsServiceException` and `onStop` gets the reason
  and Go's report. `IpfsService.restart()` starts a new process: inject the plugins again
  and rebuild node and CoreAPI; handles from the old service are no longer valid.
- **A panic inside a kubo goroutine** (outside a call) stops the host. Pass
  `IpfsService.start(crashLog: path)` to get Go's report; the host only appends to it.
- **Release handles in loops.** The Dart `Finalizer` frees Go objects late, while each
  handle may pin megabytes in the host. Use `.release()`, `.use()` or `withGoScope()`
  ([`example/memory/`](example/memory)). The node and the repo still need `close()`.
- **Synchronous calls block the isolate** until the host answers (`go.copy` of a large file,
  for example); calls with a `context` are `Future`s.
- **A command `Stream` only runs when listened to**: `.single`, `.first`, `toList()` or
  `drain()`. Cancelling the subscription of `go.readerStream` or of a command does not stop
  Go; cancel the context instead.
- **Objects a callback receives are valid only during the invocation** (that is why their
  default `batchSize` is 1). Calling into Go from a callback is allowed; if it waits on a lock
  the Go function holds, the call throws `IpfsDeadlockException` instead of hanging.
- **`uint64` values travel in an `int`**: the same 64 bits, so values above `2^63` read as
  negative.

### Network

- **`routing().provide` only queues the announcement**: a lookup right after may need a retry.
- **`Unprotect` returns whether other tags still protect the peer**, not whether it was
  protected; peering protects its own peers too.
- **On linux, QUIC asks for bigger UDP buffers** (a warning, not an error):
  `sudo sysctl -w net.core.rmem_max=7500000 net.core.wmem_max=7500000`.

### CAR files

- go-car's `has` matches multihashes unless `useWholeCids(true)`.
- Wrapping a CARv2 again is accepted and produces a broken file.
- UnixFS selectors need the dag-pb prototype chooser
  (`car.withTraversalPrototypeChooser(ipld.addSupportToChooser(boxo.defaultPrototypeChooser))`),
  or the traversal stops at the directory.
- go-car's `AttachIndex` always fails (upstream bug).

### Android

- **Background:** the host is a child process of the app; on Android 12+ the phantom
  process killer kills it, and the app with it, if it uses CPU in the background. Choose
  `IpfsService.background`: `IpfsBackground.stop` (default; restart on return) or
  `IpfsBackground.foregroundService` (a foreground service with a notification; ask for
  `POST_NOTIFICATIONS` with `IpfsFfiFlutter.requestNotificationPermission()`). The
  [`ipfs_ffi_flutter`](flutter) plugin registers itself.
- **DNS:** Go cannot find the system resolver on Android; configure `DNS.Resolvers`
  (DNS over HTTPS).
- **Packaging:** the host must be extracted from the APK
  (`packaging.jniLibs.useLegacyPackaging = true`); mDNS needs a `WifiManager.MulticastLock`.
- **NAT:** relay connections last up to 2 minutes and carry neither pubsub nor bitswap.
  Between two devices behind carrier NAT the direct connection comes over IPv6 or when one
  side is reachable; `hasIpv6()` tells whether the network delivers global IPv6.

## Build

- `dart run tool/build.dart [windows|linux|android]`: runs the generator and builds the host
  and the `ipfs_shm` into `native/` (not in git). Needs Go (`GOTOOLCHAIN=auto` downloads the
  pinned one) and a C compiler for the `ipfs_shm`: mingw-w64 on Windows, gcc on linux, the NDK
  for Android.
- **To expose more of Go:** add the symbol to `go/gen/roots.txt` (`package.Function` or
  `package.Type.Method`) and build. A new Go module also needs a line in
  `go/gen/namespaces.go`.
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
