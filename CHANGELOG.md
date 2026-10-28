# Changelog

Newest first. Measurements, findings and the reasoning behind each change are in
[`TODO.md`](TODO.md); the full API, with what was left out and why, in [`API.md`](API.md).

## 0.26.0

The examples became a course, one lesson per question, in English, Brazilian Portuguese
and Spanish.

- **The course** ([`example/README.md`](example/README.md)): 21 lessons in `example/en_us/`,
  `example/pt_br/` and `example/es/`, in four parts: content without a node (the bridge,
  CIDs, files as blocks, CAR), the kubo node (repo, node, pins and GC, MFS, IPNS and keys,
  the `ipfs` commands), the network (identity, connections, the DHT, what fetching a CID
  needs, the public network, pubsub) and the bridge (deadlines and errors, handles,
  callbacks). Each lesson says what it needs underneath and runs the common mistakes on
  purpose; output goes to `dart:developer`'s log and the terminal.
- **Removed:** the old numbered examples, `example/car/`, `example/memory/` and `DOCS.md`;
  the course covers them.
- **Bitswap by hand:** `bitswap.New`, `Bitswap.Close`/`Stat` and
  `bsnet.NewFromIpfsHost`, so an exchange can be built over a libp2p host (lesson 16).
- **`repo.Repo.close()`**, for a repo opened without a node; **`datastore.MapDatastore`**
  and **`sync.mutexWrap`**, for an in-memory blockstore.
- **Generator:** an interface that embeds several others extends, in Dart, one that some
  function takes as a parameter: `routing.ContentRouting` now extends `ContentDiscovery`
  (so an `IpfsDht` goes where `bitswap.New` wants a provider finder).

## 0.25.0

Package functions and value type methods, to build and read values without a node.

- **Package functions** (66): `cid.decode`, `parse`, `cast`, `cidFromBytes`, `newCidV0`,
  `newCidV1`, `prefixFromBytes`, `extractEncoding`, `Prefix.bytes`; `peer.decode`,
  `idFromBytes`, `fromCid`, `toCid`, `idFromP2pAddr`, `splitAddr`, `addrInfosToIds`;
  `multiaddr.newMultiaddr`, `newMultiaddrBytes`, `join`, `contains`, `unique`;
  `path.newPath`, `newPathFromSegments`, `join`, `fromCid`, `newImmutablePath`,
  `segmentsToString`, `stringToSegments`; `ipns.nameFromString`, `nameFromPeer`,
  `nameFromCid`, `nameFromRoutingKey`; the `crypto.unmarshal*` of each key type,
  `keyEqual`, `configEncodeKey`/`configDecodeKey`, `Key.raw`/`type`/`equals`;
  `peerstore.addrInfos`; `merkledag.decodeProtobuf`, `v0CidPrefix`, `v1CidPrefix`,
  `prefixForCidVersion`, the links of a `ProtoNode`; `format.makeLink`, `getLinks`, `copy`;
  `config.pathRoot`, `fsrepo.bestKnownPath`, `lockedByOtherProcess`, `apiAddr`.
- **Methods of the value types** (30; the generator takes a value type as a receiver):
  `Cid.version`, `type`, `hash`, `bytes`, `byteLen`, `prefix`, `equals`, `defined`,
  `stringOfBase`; `Id.validate`, `marshal`, `extractPublicKey`, `matchesPrivateKey`,
  `matchesPublicKey`, `shortString`; `Multiaddr.bytes`, `equal`, `compare`, `encapsulate`,
  `decapsulate`, `valueForProtocol`; `Path.namespace`, `mutable`, `segments`,
  `ImmutablePath.rootCid`; `Name.peer`, `cid`, `asPath`, `routingKey`, `equal`. Each one is
  a call to the host (synchronous), like any other function.

## 0.24.0

Options take structs and keep functions.

- **Structs in options:** `pubsub.withGossipSubParams`, `withPeerGater`, `withPeerScore`,
  `relay.withLimit`, `relay.withResources`, with their defaults
  (`pubsub.defaultGossipSubParams`, `relay.defaultResources`, `relay.defaultLimit`).
  `PeerScoreParams` has function fields (`AppSpecificScore`) that do not cross: they arrive
  nil, and pubsub refuses it.
- **Functions in options** (retained callbacks): `pubsub.withMessageFilter`,
  `withGossipSubProtocols`, `withAppSpecificRpcInspector`, `dht.onRequestHook`,
  `quicreuse.verifySourceAddress`.
- **Breaking: the pubsub methods that go through its event loop are asynchronous**
  (`Future`): `PubSub.join`, `getTopics`, `listPeers`, `blacklistPeer`, `addDirectPeer`,
  `removeDirectPeer`, `registerTopicValidator`, `unregisterTopicValidator`,
  `Topic.subscribe`, `listPeers`, `eventHandler`, `close`, `Subscription.cancel`,
  `TopicEventHandler.cancel`. The loop runs a subscription filter or a message ID
  function and waits for Dart; a synchronous call waiting on the same loop deadlocked the
  isolate (found repeating the filter test).
- **Breaking:** six libp2p options that took an opaque handle of a Go function type (which
  only Go could create) take a Dart function: `pubsub.withMessageIdFn`,
  `withTopicMessageIdFn`, `withPeerFilter`, `dht.queryFilter`, `routingTableFilter`,
  `relay.withReservationAddressFilter`.

## 0.23.0

Where Go reflects on an `any`, the generator fixes the type.

- **Pubsub validators:** `ps.registerTopicValidator(topic, (ctx, from, msg) => ...)`
  returns `pubsub.validationAccept`/`Reject`/`Ignore` (the `ValidatorEx` the `any` takes;
  table `anyAs`); an exception rejects. `unregisterTopicValidator`; `withValidatorTimeout`,
  `withValidatorConcurrency`, `withValidatorInline`.
- **The event bus:** `h.eventBus().subscribe(event.EvtPeerConnectednessChanged.$type)` (or
  a list of types); `sub.out()` delivers the events as their classes. The ten `event.Evt*`
  types of go-libp2p are listed.
- **A stack of one's own:** `libp2p.transport(tcp.newTcpTransportFunc)`,
  `security(noise.id, noise.newFunc)`, `muxer(yamux.id, yamux.defaultTransport)`,
  `quicReuse(quicreuse.newConnManagerFunc)`; the tokens of QUIC, WebSocket, WebTransport,
  WebRTC and TLS too.
- **Runtime:** a retained callback returns a basic value (in the `CallbackAck`) and
  receives a `context.Context`; it runs in the zone it was given in (an exception goes
  there); `GoToken`; dynamic values with tags 8 (a typed value) and 9 (a token).
- **Fix (generator):** an option type that another option of its package takes
  (`pubsub.WithDefaultValidator(..., opts ...ValidatorOpt)`) was scanned half-way and came
  out as an opaque handle, without constructors; the parameters are now classified after
  the package's scan.
- **Generator:** a trailing variadic that does not cross is left out (Go gets none); a
  concrete handle that implements an interface only an option takes extends it, as the last
  choice (`yamux.Transport` is a `network.Multiplexer`).

## 0.22.0

libp2p on its own, without kubo.

- **libp2p hosts:** `libp2p.new$` with its options (`listenAddrStrings`, `identity`,
  `natPortMap`, `enableRelay`, `enableHolePunching`, `enableAutoRelayWithStaticRelays`,
  `connectionManager`, `noListenAddrs`, `defaultTransports`...); identity keys in
  `crypto` (`generateKeyPair`, `marshalPrivateKey`/`unmarshalPrivateKey`, `sign`/`verify`,
  `peer.idFromPrivateKey`); the host, its network, connections and peerstore; `ping.ping`.
- **Streams:** `host.newStream`, `Stream.read`/`write`/`closeWrite`/`reset`/deadlines;
  `io_stream.readerStream` on a stream closes only its read side (`CloseRead`).
- **Pubsub on a host of one's own:** `pubsub.newGossipSub`, topics, `Subscription.next`,
  topic peer events.
- **DHT and discovery:** `dht.new$` with its options (`mode`, `protocolPrefix`,
  `bootstrapPeers`...), `provide`, `findProviders(Async)`, `findPeer`, values, the routing
  table; `routing.RoutingDiscovery` (`advertise`, `findPeers`).
- **Retained callbacks** (WIRE.md): a function Go keeps past the call is called by Go for as
  long as it holds it (`host.setStreamHandler`, `setStreamHandlerMatch`), and Dart drops it
  when Go's garbage collector frees it. A root that is an interface type is implemented in
  Dart, one function per method: `network.Notifiee(connected: ..., disconnected: ...)`,
  `mdns.Notifee(handlePeerFound: ...)` with `mdns.newMdnsService`.
- **Generator:** functional options built in another package (libp2p's build a
  `config.Option`) and package variables that are options; an internal package's type seen
  through an exported alias (`dht.Option`); a named slice (`peer.IDSlice`) is a `List`.
- **Breaking: `time.Duration` is a Dart `Duration`** everywhere (it was an `int` of
  nanoseconds outside constants): `options.name.ttl(...)`, `validTime`,
  `gateway.withGetBlockTimeout`, `mfs.withFetchTimeout`, `ConnectionInfo.latency`,
  `node.BuildCfg.shutdownTimeout`...
- **Fix:** the host's standard log never blocks a call (mDNS's `Close` hung while the app
  waited on it synchronously and the stderr pipe was full).
- **Fix:** a Go string that is not UTF-8 (pubsub's message ID) decodes with U+FFFD instead of
  failing the response.

## 0.21.0

The package is about peer-to-peer networking from Go, not only IPFS.

- **Breaking: the package is `p2p_ffi`** (was `ipfs_ffi`): `package:ipfs_ffi/...` →
  `package:p2p_ffi/...`, `ipfs_ffi.dart` → `p2p_ffi.dart`. The Flutter plugin is
  `p2p_ffi_flutter` (`P2pFfiFlutter`, `P2pNotification`, `P2pNotificationImportance`;
  Kotlin `P2pFfiFlutterPlugin`, `P2pForegroundService` in `dev.extramobs.p2p_ffi_flutter`,
  method channel `p2p_ffi_flutter`). Reinstall an app that used the old plugin.
- **Breaking: native names.** The host is `p2p_host` (`p2p_host.exe`, `libp2p_host.so`) and
  the channel library `p2p_shm` (`p2p_shm.dll`, `libp2p_shm.so`).
- **Breaking: runtime names.** `IpfsService` → `P2pService`; `IpfsBackground`, `IpfsStop`,
  `IpfsStopReason`, `IpfsStopHandler`, `IpfsBusy`, `IpfsPlatform` → `P2p*`;
  `ipfsShmLibraryPath` → `p2pShmLibraryPath`.
- **Breaking: exceptions.** `P2pException` is the interface every exception implements;
  `GolangException` (was `IpfsException`) is the error that comes from Go, with the sentinels
  `GolangEofException`, `GolangUnexpectedEofException`, `GolangCanceledException`,
  `GolangDeadlineExceededException`, `GolangNotFoundException`, `GolangDeadlockException`;
  the service going away is `P2pServiceException`. They all `implements GolangException`, so
  `on GolangException` still catches the service drop.
- **Go constants in Dart:** every exported constant of a library's Go package is generated
  (`options.ed25519Key`, `cid.raw`, the multicodec table, the kubo config defaults...);
  `time.Duration` constants are `Duration`s.
- **Breaking: the library paths follow the Go packages.** Each Go package is one library
  under `package:p2p_ffi/go/`, at its path in its module: `boxo/mfs.dart`
  → `go/boxo/mfs.dart`, `multiformats/cid.dart` → `go/cid.dart`,
  `car/v2/index.dart` → `go/car/v2/index.dart`, `ipld/prime/...` → `go/ipld_prime/...`.
  The module files (`kubo.dart`, `boxo.dart`, `go.dart`...) are gone: import each package
  with its own prefix. `service.dart` is gone too: everything it had comes from `p2p_ffi.dart`.
- **Breaking: one class per Go type.** The kubo commands' result types moved from
  `kubo/core/commands.dart` to the library of their Go package (`go/kubo/core/commands/pin.dart`,
  `go/libp2p_kad_dht/provider/stats.dart`...), and the ones the API already had are the same
  class now: `swarmPeeringLs` gives `peer.AddrInfo` (its `id` is nullable) and the
  `filesLs` entries are `mfs.NodeListing`. The names that carried a package prefix to avoid
  clashes in the single file use Go's name in their own library: `CommandsAddEvent` →
  `commands.AddEvent`, `CommandsBlockStat` → `commands.BlockStat`, `NameStringList` →
  `name.StringList`, `PinStat` → `pin.Stat`, `CorerepoStat` → `corerepo.Stat`, `MetricsStats` →
  `metrics.Stats`.
- The generator refuses a public library that re-exports another, and formats new files with
  the package's language version.
- The Flutter plugin is written in Kotlin (was Java); its API is the same,
  `P2pForegroundService.setNotificationFactory` included. It compiles with AGP's
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
