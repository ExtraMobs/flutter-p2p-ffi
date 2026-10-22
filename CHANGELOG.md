# Changelog

Newest first. Measurements, findings and the reasoning behind each change are in
[`TODO.md`](TODO.md); the full API, with what was left out and why, in [`API.md`](API.md).

## Unreleased

- The `ipfs_ffi_flutter` plugin is written in Kotlin (was Java); its API is the same,
  `IpfsForegroundService.setNotificationFactory` included. It compiles with AGP's
  built-in Kotlin (`android.builtInKotlin=true`) and also with the Kotlin plugin that
  Flutter applies when that is off.
- Fix: stopping the foreground service right after starting it (before its
  `startForeground`) made Android kill the app
  (`ForegroundServiceDidNotStartInTimeException`); such a stop now waits and the service
  stops itself once in the foreground.
- Gradle: both plugins configure `LibraryExtension` instead of the deprecated `android {}`
  accessor, and the jniLibs directory goes through `directories`; the validation app
  sets `android.builtInKotlin=true`. Only `android.newDsl=false` is still deprecated:
  Flutter's Gradle plugin does not build with the new DSL yet.
- Docs in English: `WIRE.md`, `API.md` (from the generator) and the examples, whose
  files 09–13 are renamed (`09_commands_and_streams.dart`...).

## 0.20.0

Low-level resource management of the running node.

- **Automatic GC:** `corerepo.periodicGc` and `corerepo.conditionalGc`.
  `Datastore.StorageMax`/`StorageGCWatermark`/`GCPeriod` only act through `PeriodicGC`,
  which only the kubo daemon starts; a library node never collected on its own.
- **`go.readerStream`:** any `io.Reader` handle as a `Stream<Uint8List>` (256 KiB pieces).
- **Reading without storing:** `IpfsNode.exchange`, `blockstore.Blockstore(...)` and the new
  `datastore` namespace (`NullDatastore`): a block service that fetches over bitswap without
  caching in the repo.
- **Blockstore:** `deleteBlock`, `getSize`, `allKeysChan`; `IpfsNode.gcLocker` with
  `gcLock`/`pinLock`/`gcRequested` and `Unlocker.unlock`; `IpfsNode.baseBlocks`.
- **Connections:** `IpfsNode.peerHost.connManager()` with `protect`/`unprotect`/
  `isProtected`/`tagPeer`/`untagPeer`/`trimOpenConns`.
- **Resource manager (read-only):** `IpfsNode.resourceManager.viewSystem`/`viewTransient`
  and `ResourceScope.stat`.
- Generator: `go-datastore.NullDatastore` is a handle.

## 0.19.0

- Deterministic handle release: `GoHandle.release()`, `.use()`, `GoScope`/`withGoScope()`;
  using a released handle throws.
- Memory benchmark (`tool/zz_gc.dart`) and the guide in [`example/memory/`](example/memory).

## 0.18.0

- Everyday CAR operations as runnable examples, right way and mistakes
  ([`example/car/`](example/car), indexed in [`DOCS.md`](DOCS.md)).
- New API for node-less paths: `blockservice.new$`, `offline.exchange`,
  `merkledag.newDagService`, the UnixFS importer, chunker, directory and file reader.
- The package moved to the repository root; the transpiler lives in the `transpilador` branch.
- **Breaking:** plural acronyms stay one word (`useWholeCiDs` → `useWholeCids`).

## 0.17.0

- Callbacks: a Go function that takes a function takes a Dart function (`batchSize`).
- Go sentinel errors as subclasses: `IpfsEof`, `IpfsUnexpectedEof`, `IpfsCanceled`,
  `IpfsDeadlineExceeded`, `IpfsNotFound`.
- Deadlock detection (`IpfsDeadlockException`); objects in use: `isBusy`, `IpfsService.busy`.
- CAR slices from the node: the boxo gateway (`BlocksBackend.getCar`), IPLD selectors over the
  node's blockstore (`bsadapter`), the UnixFS selectors and the selector builder.

## 0.16.0

- go-car v2 in the `car` namespace: reading, inspection, v1/v2 conversion, index, blockstore,
  storage and selective traversal; `LinkSystem` and selectors of go-ipld-prime; multicodec
  codes; `cid.Prefix` (a block's CID without a node).
- **Breaking:** `io.Writer` parameters exist now, so `createIdentity(opts)` became
  `createIdentity(null, opts)`.

## 0.15.0

- Every RPC command returns a `Stream`; a smoke test runs all of them.
- Two upstream bugs patched at build time
  ([ipfs/boxo#1221](https://github.com/ipfs/boxo/issues/1221),
  [ipfs/kubo#11477](https://github.com/ipfs/kubo/issues/11477)).
- Android: the host goes with cgo on every ABI (DNS and network addresses on real devices);
  the foreground service survives a host crash; app-owned notification
  (`IpfsNotification`, `requestNotificationPermission`).

## 0.14.0

- The kubo RPC commands (`/api/v0`) run against the app's node, without daemon or HTTP
  (`kubo/core/commands.dart`, one function per command, one DTO per result).

## 0.13.0

- The rest of the CoreAPI (`withOptions`, `routing().get/put`, `object()`).
- Low level: the whole of `boxo/mfs`, `node.repo` config access, `node.peering`.
- Generator: constants, struct fields, interface casts, option constructors, output
  buffers (`Read`/`CtxReadFull`) and `any`.

## 0.12.0

- `dag export/import` back in the `kubo` namespace (`dagExport`, `dagImport`...); `car` is
  reserved for go-car.

## 0.11.0

- The API in namespaces, one per Go module (`kubo`, `boxo`, `ipld`, `multiformats`,
  `libp2p`, `go`), each with an all-in-one library.

## 0.10.0

- Android background: `IpfsService.background` (`stop` or `foregroundService`), the
  `ipfs_ffi_flutter` companion plugin, `IpfsStop`/`onStop` with a reason (was
  `IpfsCrash`/`onCrash`).

## 0.9.0

- Kubo runs in a separate process (`ipfs_host`) over shared memory (`ipfs_shm`); a Go panic
  stops only the service, and the app decides whether to restart it.

## 0.8.0

- Validated on a real Android device (Wi-Fi and mobile data); `anet` for network
  interfaces; panics recovered in the bridge's goroutines; less JSON on the wire.

## 0.7.0

- Android, validated on the emulator.

## 0.6.0

- CAR files (`dag export/import`) and pubsub.

## 0.5.0

- Direct exports for simple signatures (no JSON); crash report (`crashLog`).

## 0.4.0

- `add` progress (`options.unixfs.events` + `progress`).

## 0.3.0

- IPNS, keys, known addresses, Dag and DAG-CBOR/JSON.

## 0.2.1

- Validated on linux through WSL.

## 0.2.0

- Minimal IPFS node without HTTP, through the generated kubo API.
