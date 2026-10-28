# Pendências do ipfs_ffi

## Done (unreleased): typed Go errors

The owner asked for real typed errors (a Dart class thrown per Go error) and, for the
errors that are only text, the errno and the error texts in the `GolangException`
classes; for the texts, the whole chain.

- Collection, like the constants: the exported `error` variables and the exported types
  implementing `error` (by value or pointer) of each package with a library; 228 classes.
  Left out (API.md): generic types, names another class of the library has, and the seven
  with a runtime class (`io.EOF`... keep `GolangEofException`...).
- A sentinel is matched per link with `==` (guarded: a non-comparable dynamic type
  panics), against all sentinels: `os.ErrNotExist` and `fs.ErrNotExist` are one value,
  so a link gets both classes (a `switch` would give only the first, and
  `on os.ErrNotExist` would never match). A type, by type switch (`*T`, and `T` when the
  method is on the value); its fields that cross as values go along (`PathError.op`,
  `path`); an `error` field is the next link.
- The thrown class: the fixed sentinel's when there is one (compatibility), else the
  outermost link with a class, else `GolangException`. Each link in `causes` is built
  with its own text; the thrown one with the whole error.
- errno: the raw `syscall.Errno` (Win32 on Windows, POSIX on linux/Android; "file not
  found" is 2 on both).
- Python on Windows writes CRLF: generator files touched by it went through `gofmt -w`.
- Checked on Windows: `test/errors_test.dart` (4: a sentinel with two names, `PathError`
  with fields and errno, a typed error without fields, text only), the whole suite,
  go vet, go test (`TestErrDataChain`), gen -check, the 63 lessons.

## Done: the course, in three languages (0.26.0)

The owner asked for better examples: a course for Dart developers who do not know IPFS,
one lesson per question, saying what each step needs underneath (what boxo needs to
fetch a CID, for one), in English, Brazilian Portuguese and Spanish, and with the old
examples removed.

- 21 lessons per language (`example/en_us/`, `example/pt_br/`, `example/es/`), the same
  code and identifiers, comments and output translated. Each ends with the next
  question; the common mistakes run on purpose through `mistake()`/`silentlyWrong()`,
  which stop the lesson if the behavior changes. Output through `say()`
  (`dart:developer`'s log, which `dart run` does not print, plus the terminal).
- Roots: `go-datastore.NewMapDatastore`, `sync.MutexWrap` (an in-memory blockstore),
  `repo.Repo.Close`, `bitswap.New`, `Bitswap.Close`/`Stat`, `bsnet.NewFromIpfsHost`.
  `io.Closer.Close` was tried first and reverted: the generator gives each type one Dart
  superclass, and with `io.Closer` exposed it chose `Closer` for `MapDatastore`,
  `IpfsNode`, `IpfsDht`... (breaking code that passed them as their real interfaces).
- Generator (`linkInterfaces`): an interface that embeds several takes, as its Dart
  superclass, one that some function receives, not just the first embedded:
  `routing.ContentRouting` extends `ContentDiscovery` (not `ContentProviding`), so an
  `IpfsDht` is accepted by `bitswap.New`. The only class that changed.
- Findings that became lesson content: a blockstore keys by multihash, so `AllKeysChan`
  returns raw CIDv1s and a CAR written from it cannot find its dag-pb root (lesson 05);
  `fsrepo.Init` on an initialized folder returns nil and changes nothing (07); libp2p
  hosts may listen on the same TCP port (port reuse, 13, 17); a canceled context reaches
  kubo's `unixfs get` as "could not resolve name", not `context.Canceled` (19); after
  `P2pService.restart()` the old `context.background()` is a stale handle too (19); on
  Windows Go's monotonic clock reads a loopback ping as 0 µs (14).
- Pending: in lesson 10's sequence, a second `mfs.File.open(write)` while a writer is
  open (in Go it waits for the lock) ended with the p2p_host gone (exit code 143, empty
  crash log). An isolated repro (`open` twice with a Dart `.timeout`) does not crash.
  The lesson no longer does it; to look into.
- Checked on Windows: the 63 lessons run; dart analyze, dart test (113), go vet, go test,
  gen -check. The public-network lesson fetched a CID published by the IPFS gateway
  checker (the same CID was checked through a local IPFS Desktop first).

## Done: package functions and value type methods (0.25.0)

The owner asked for the package functions that were missing (`cid.Parse` and others).

- A census with the generator itself (a temporary test over `resolve`/`check`), over the
  packages of `roots.txt`: 868 exported functions, 108 exposed, 509 more it accepted; 2363
  methods, 310 exposed, 1892 more. Most of it is noise (`bytes`/`os`/`io`, the protobuf
  getters of `pubsub/pb`, the `coreapi` implementation behind `coreiface`, `datastore`
  internals), and the ~130 functions that return an option are already the option
  constructors. 66 curated roots: building and converting CIDs, peer IDs, multiaddrs,
  paths and IPNS names; the keys of each type; dag-pb links; the repo's paths and lock.
- The real gap was the methods of the value types (`Cid`, `peer.ID`, `Multiaddr`, `Path`,
  `ipns.Name`): the generator refused a receiver that is not a handle or a DTO (79 of the
  refusals). Now the receiver of a value type with a Dart class crosses as its string
  (the `dec` of `wire.go`), and the method lives in the class: 30 roots. Go's `String()` is
  the class's `value`, so it is not listed.
- Left out: `Multiaddr.Protocols` (each `Protocol` carries a `Transcoder` handle to
  release), `cid.MustParse` and `multiaddr.StringCast`/`Cast` (they panic; `parse` and
  `newMultiaddr` answer with an error), `cid.Set` (Dart's `Set<Cid>`), `Cid.KeyString`
  (binary in a string), IPNS records (`ipns.NewRecord`, `Validate`).
- `multiaddr.join`/`encapsulate` take `Multiaddrer`, a snapshot class:
  `Multiaddrer(multiaddr: a)`.
- Checked: dart test (`test/package_funcs_test.dart`, 8 tests; the whole suite, 113),
  go vet, go test, gen -check, on Windows; linux (WSL) 113/113; the Android integration
  tests (`ipfs_test`, `libp2p_test`, `network_test`) on the emulator (Android 17, x86_64)
  and on a real phone (Android 16, HyperOS, arm64). On the phone the first `network_test`
  failed with "the app went to the background": the screen turned off after 60 s and
  stopped the service. With `adb shell svc power stayon usb` it passed 5/5 (restore with
  `svc power stayon false`). DNSLink took 58 s there, close to the timeout.

## Done: the pending checks on a real phone (2026-10-23)

Android 16 (HyperOS), arm64, by USB. HyperOS asks to confirm every install by USB: an
unanswered prompt fails `flutter test` with `INSTALL_FAILED_USER_RESTRICTED` (the first
`device_session` run failed every step for that).

- **Integration 4/4** after the 0.21 renames (`libp2p_host.so`, `p2p_shm`), the Kotlin plugin
  and the foreground-service fix: local checks, Go panic → restart, both background modes.
  Bridge: sync Noop 1.5 µs, async 788 µs, `block.stat` 1.5 ms.
- **libp2p without kubo** (`integration_test/libp2p_test.dart`, new): TCP + Noise + yamux
  from function tokens, the event bus, a stream handler. A message through a Dart validator
  and a subscription filter, one at a time: 6.6–6.9 ms. A burst of 200: the validator ran 200
  times but 39 arrived; the subscription's queue (32 by default) dropped the rest, since
  Dart pulls with `next()`. With `withBufferSize(256)`, 200 of 200 (README).
- **On-demand callback batch** (pending since 0.17, profile): 16-byte items rise up to
  2048 per batch (861k/s; 1024: 705k/s) and 4096 gets slower to the first item (6 ms);
  1 KiB items level off at 128–256 (~86 MB/s), 64 KiB at 2–4 (~130 MB/s). The default
  (1024 items, up to 128 KiB) holds.
- **Network 5/5** (mobile data behind the carrier's CGNAT, the screen kept on with
  `svc power stayon usb`: the first run lost reachability when the app went to the
  background, which stops the service by default): 19 peers right away, DNSLink resolved in
  211 ms, after 2 min online 69 peers (50 QUIC, 17 TCP, 2 WebRTC), 0 inbound, 9 relay
  addresses announced.

## Done: structs and functions in options (0.24.0)

The owner asked for the two general gaps of the option constructors.

- `okOptCtor` takes a DTO, as a function's parameter does; `ctorParams` makes a function
  parameter a retained callback (an option keeps what it gets). An option-shaped function
  type (`namesys.ResolveOption`) stays an option: the first try turned it into a callback.
- Six opaque handles of Go function types became Dart functions (listed in `CHANGELOG.md`).
- **Found repeating the tests: a deadlock with the subscription filter.** Pubsub runs the
  filter inside its event loop and waits for Dart; `sub.cancel()` (synchronous then) waited
  on the same loop, so the isolate could not run the filter: 5 min, then the host was
  stopped. The deadlock watcher only sees mutexes, not channels. The pubsub methods that go
  through the loop are `forceAsync` now (the isolate keeps running while they wait). The
  same risk stays for a synchronous call into anything a Dart callback holds by a channel;
  by a mutex, the watcher answers `GolangDeadlockException` only for handles in use by an
  on-demand callback, not by a retained one.
- The validator test waited for the exception only after two accepted messages; the
  exception may come later (validation is parallel): it now waits for it.
- Still out: options whose function returns something composite (`dht.AddressFilter`,
  `BootstrapPeersFunc`, `WithProtocolMatchFn`, `quicreuse.ConnContext`,
  `OverrideSourceIPSelector`, `WithCustomMessageSender`) and the ones in 0.23's list.
- Checked: dart test (12 libp2p tests: a struct option, an invalid one refused, a relay
  service with its limits, a subscription filter), go test, gen -check.

## Done: types Go reflects on (0.23.0)

The owner asked for the three stages: pubsub validators, the event bus, transport and
security constructors. All general pieces of the generator (tables like `chanElem`), no
hand adapter.

- **`anyAs`:** an `any` parameter that takes one documented type crosses as it. The
  validator is a retained callback that returns a value; `CallbackAck` carries it.
  `ValidationAccept` is 0, so the zero value on a Dart exception would accept a message:
  `cbOnThrow` makes it `ValidationReject`.
- **Tokens (`go/gen/tokens.go`):** listed types and functions, numbered in key order and
  folded into the table hash. Go → Dart, a listed type in an `any` goes as tag 8 and Dart
  builds the class from `lib/src/any_types.dart` (generated, imported by the runtime); Dart
  → Go, tag 9 becomes `new(T)` or the function. `Subscribe([A.$type, B.$type])` is Go's
  `[]any{new(A), new(B)}`.
- **Found: option constructors classified half-way.** The scan of a package's options
  classified each constructor's parameters as it went; `WithDefaultValidator` takes
  `...ValidatorOpt`, so `ValidatorOpt` was classified (and cached) before its own
  constructors (`WithValidator*`) were scanned, and became an opaque handle. The parameters
  are now classified when the option type is asked for (`ctorParams`); nothing else in the
  API changed.
- **Retained callbacks run in their zone** (the zone of the call that gave them): the test
  catches the validator's exception with `runZonedGuarded`.
- **Found:** pubsub validates in parallel, so under load (the whole suite) two accepted
  messages arrived in the other order; the test compares without order.
- **`yamux.Transport`** is `type Transport yamux.Config` (a struct of exported fields), so
  it was a DTO: now in `handleTypes`, and it extends `network.Multiplexer`. Marking the
  interfaces of option parameters for `linkConcrete` first moved `IpfsDht` to
  `ValueStore` and `RoutingDiscovery` to `Discovery`; they are now the last choice.
- Not exposed yet: `event.WildcardSubscription` (a pointer to an unexported type), the
  options of a transport (`tcp.WithConnectionTimeout`... are Go values in `opts ...any`),
  `eventbus.BufSize` (`SubscriptionOpt` is an unnamed func).
- Checked: go test, gen -check, dart test 103/103 (twice in a row; 3 new: validator with
  exception, event bus, TCP+Noise+yamux stack refusing QUIC), examples 14 and 15.

## Done: libp2p without kubo (0.22.0)

The owner asked for libp2p usable on its own, in five stages: host and identity, streams,
pubsub, DHT and discovery, and the retained callbacks (approved as a general piece of the
generator and of WIRE.md, not one hand adapter per handler). The list is in `CHANGELOG.md`.

- **Retained callback:** the Dart id goes in the request; each invocation is a one-item
  `callback` event; `ask` (bool/error) waits for a `CallbackAck`, `call` does not; a
  `runtime.AddCleanup` on the Go side sends `end` when the function is collected (checked in
  `go/retained_test.go`, forcing GCs). The verdict map holds the channel, not the callback,
  so the cleanup can run.
- **Interface roots:** the generator's struct over one function per method; the Dart factory
  takes them by name, a method left out is a no-op. `StopNotify` gets the same object back
  because it is a handle.
- **Found on the way:** mDNS's `Close` hung the app: zeroconf warns with `log.Printf`, the app
  drains the host's stderr on its event loop, which does not run during a synchronous call,
  and `Close` waits for the goroutine blocked on the full pipe (seen in a goroutine dump).
  The standard log now goes through a queue (`go/logpump.go`); go-log still writes to stderr
  directly (error level by default).
- **Go itself measures `ping` RTT as 0 s on Windows loopback** (a go test with two hosts);
  the test only checks it is not negative.
- **A TCP dial between two hosts that both just bootstrapped the DHT can fail with "dial
  backoff"** on Windows loopback (simultaneous dial); example 15 does not depend on that
  connection.
- **Not exposed:** pubsub validators (`RegisterTopicValidator` takes `any`, the Go side picks
  the function type by reflection), the event bus (`Subscribe` takes a pointer to the event
  type), `Topic.Relay` (returns a Go func), `util.Advertise` (Dart's `RoutingDiscovery` is a
  `ContentRouting`, not an `Advertiser`; loop `advertise` with its TTL instead).
- Checked: go test, gen -check, dart test 100/100 (7 new with two hosts: identity, ping,
  echo stream, match function, Notifiee, gossipsub, private DHT and rendezvous), examples 14
  and 15, `go vet` for android/arm64. Not run: the Android integration test (nothing
  Android-specific changed).

## Done: p2p_ffi, Go constants, paths by Go package (0.21.0)

The owner turned the package towards peer-to-peer networking (kubo, boxo, go-libp2p), not
only IPFS, and asked for the layout to follow Go. The full list of breaking changes is in
`CHANGELOG.md`.

- **Names:** the package `p2p_ffi`, the plugin `p2p_ffi_flutter`, the host `p2p_host` and
  `p2p_shm`; `P2pService` and the other `P2p*`; Go's errors as `Golang<error>Exception`,
  all implementing `GolangException` (the service drop, `P2pServiceException`, too), under
  the `P2pException` interface.
- **Layout:** one library per Go package under `lib/go/`, at its path in its module (from
  `go list -m all`; a nested module keeps the outer one's path); no module files; the
  generator refuses a public library that re-exports another; the commands' result types in
  the library of their Go package, sharing the main generator's class when it exists; the
  hand-written `dag` library gets its package's generated part (`dag.g.dart`).
- **Constants:** every exported Go constant of a library's package is generated (about
  1,100; 605 from go-multicodec); `time.Duration` → `Duration`. A clash with another
  member's Dart name is omitted with the reason (`RecursionLimit_None` vs the function
  `RecursionLimitNone`).
- **Plugin in Kotlin**, with a fix found on the emulator: a stop right after
  `startForegroundService` made Android kill the app; the stop now waits for
  `startForeground`.
- **Generator fixes:** new files formatted with the pubspec's language version; members
  named like a lowercase Dart type (`cmds.Int`) escaped (`int$`).
- Checked: go test, gen -check, dart test 93/93, the 37 self-contained examples, the
  Android integration test 4/4 on the emulator (Android 17), flutter analyze of the plugin
  and the Android app.

## Done: low-level resources: GC, storage without caching, connections (0.20.0)

The owner asked for kubo's low-level resource management, in this order.

- **Finding:** `Datastore.StorageMax`/`StorageGCWatermark`/`GCPeriod` only act through
  `corerepo.PeriodicGC`, which only the daemon starts (`cmd/ipfs/kubo/daemon.go`,
  `--enable-gc`); a node from `core.NewNode` never collects on its own.
- **New API** (roots, one commit per stage):
  1. `corerepo.PeriodicGC`, `corerepo.ConditionalGC`;
  2. `go.readerStream` (`lib/go/io_stream.dart`, hand-written, function 42 of WIRE.md):
     any `io.Reader` handle as a `Stream<Uint8List>` in 256 KiB pieces; the commands'
     `emitReader` and it share `readChunks`;
  3. `IpfsNode.Exchange`, `blockstore.NewBlockstore`, go-datastore's `NewNullDatastore`
     (new `datastore` namespace; the module was already an indirect dependency): reading
     over bitswap without growing the repo (`blockservice.getBlock` caches what it fetches);
  4. `Blockstore.DeleteBlock`/`GetSize`/`AllKeysChan`, `IpfsNode.GCLocker` with
     `GCLock`/`PinLock`/`GCRequested` and `Unlocker.Unlock`;
  5. `IpfsNode.PeerHost`, `host.Host.ConnManager` and the `ConnManager`'s
     `Protect`/`Unprotect`/`IsProtected`/`TagPeer`/`UntagPeer`/`TrimOpenConns`;
  6. `IpfsNode.ResourceManager` with `ViewSystem`/`ViewTransient` and `ResourceScope.Stat`;
  7. `IpfsNode.BaseBlocks` with its `Blockstore` methods as roots on the type.
- **Generator:** `go-datastore.NullDatastore` is a handle (`handleTypes`): it has no fields,
  only the methods of a datastore.
- **Limits, confirmed against Go:** the resource manager interface cannot change limits at
  run time (`Swarm.ResourceMgr`, then restart); `Unprotect` returns whether other tags still
  protect the peer (peering protects its peers too); `node.BaseBlocks` is defined from
  `blockstore.Blockstore`, which go/types does not keep, hence the roots on the type.

## Done: deterministic handle release, memory benchmark and examples (0.19.0)

Each `GoHandle` in Dart is ~48 bytes (two `int`s: `$h` and `$e`), while the Go value it pins
in `ipfs_host`'s `handles.m` can hold megabytes (`go.Buffer`, `ipld.Block`, `car.BlockReader`,
`ipld.Node`). In loops or batch operations, Dart's heap barely grows so `Finalizer` does not
run in time, and synchronous loops never yield to the event loop to flush `_toFree`.

- **Deterministic release (`lib/src/runtime.dart`, `lib/src/runtime/codec.dart`):**
  - `_finalizer.attach(this, ($e, $h), detach: this)` so manual release detaches the
    `Finalizer` and prevents double-free when the Dart GC runs later;
  - `GoHandle.release()` and `GoHandle.isReleased`: detaches the finalizer, marks the handle
    released, and immediately flushes `_fnFree` (`fn == 3`) to `ipfs_host` (idempotent);
  - `GoHandleUse.use((h) => ...)`: lexical helper for a single handle (sync or `Future`),
    always calling `release()` in `finally`;
  - `GoScope` (`scope.manage(h)`, `scope.close()`) and `withGoScope((scope) => ...)`: tracks
    multiple handles in a block or loop iteration and flushes all of them in a single `_fnFree`
    batch in reverse registration order (LIFO) on exit;
  - Use-after-release guard in `$W.h`: passing a released handle throws
    `IpfsException('handle already released: cannot use a released handle')` before touching
    shared memory;
  - `$callSync` and `_start` now flush any pending `_toFree` entries queued by background
    `Finalizer` callbacks even during purely synchronous loops.
- **Benchmark (`tool/zz_gc.dart`):** 3 rounds of 100 × 20 MB `go.Buffer`s + 5 s idle + Round 4
  after Dart GC pressure (`--mode=finalizer|release|scope|all`). `finalizer` climbs to
  ~6,114 MB RSS in `ipfs_host`, while `release` and `scope` stay flat at ~142–143 MB.
- **Guide and runnable examples (`example/memory/`):**
  - `README.md`: how `GoHandle` works across the bridge, `close()` vs. `release()`, decision
    table (`Finalizer`, `.use()`, `.release()`, `withGoScope()`), and cautions;
  - `01_how_handles_work.dart`: handle IDs, Go pointer deduplication (`refs` counter in
    `handles.byKey`), and `close()` vs. `release()`;
  - `02_single_handle_use.dart`: `.use()` (sync, async, and on exception) and `.release()`;
  - `03_batch_loops_with_scope.dart`: `withGoScope()` in CAR/IPLD loops and escaping a winning
    handle outside an inner scope;
  - `04_pitfalls_and_mistakes.dart`: use-after-release, returning a scope-managed handle,
    forgetting `.close()` before `.release()`, and releasing one alias of a deduplicated Go
    pointer.

## Done: everyday CAR operations as examples; the package at the repository root (0.18.0)

The owner asked to document in code every everyday operation with CAR files (kubo for the
general functions, boxo / go-car / go-ipld-prime for the low level), with one file for the
right way and one for the mistakes, indexed in a `DOCS.md`. Also: the package moves to the
repository root and the unused folders are archived. Names and documentation are English
from now on (owner's rule).

- **Repository:** the content of `ipfs_ffi/` is at the root. The transpiler (g2d,
  golib_dart, tools, tests, TODO/, docs/, its AGENTS.md) left `main` and lives whole in the
  branch `transpilador` and the tag `transpilador-final`. The Go module is
  `github.com/ExtraMobs/transpiled_ipfs/go`. A new `AGENTS.md` for the package points at
  the earlier attempts (`transpilador`, `archive`, `claude/*`).
- **Examples:**
  - `example/car/`: 14 operations × 2 files (`NN_operation.dart` and
    `NN_operation_mistakes.dart`), plus `sample.dart`. `DOCS.md` at the root indexes them.
  - The mistakes run for real: `mustFail` stops the example if the error stops happening;
    `silentlyWrong` shows a wrong result next to the right one.
  - Each failure mode was confirmed by running it first.
- **New API** (roots), for the node-less paths:
  - `blockservice.New`, `offline.Exchange`, `merkledag.NewDAGService`;
  - `unixfs/importer.BuildDagFromReader`, `chunker.NewSizeSplitter`/`FromString`;
  - `unixfs/io.NewDirectory`/`AddChild`/`GetNode`, `unixfs/file.NewUnixfsFile`;
  - `format.NodeGetter.Get`, `format.DAGService.Add`;
  - `blockstore.Blockstore.Put`/`Has`/`Get`.
- **Generator:**
  - `resultAs`: a function that returns an unexported type is seen through an exported
    interface (`NewDAGService` → `DAGService`);
  - plural acronyms stay one word (`UseWholeCIDs` → `useWholeCids`). This renames the 0.16
    `useWholeCiDs`/`storeIdentityCiDs`, which **breaks** code that used them.
- **Host:** go-car's `index.ErrNotFound` maps to `IpfsNotFound`.
- **Findings, confirmed against Go:**
  - `Directory`-based creation without a node gives the same root as `ipfs add` with the same
    parameters;
  - the `BlockReader` and `dag import` check hashes; `Inspect(false)` does not;
  - go-car's `has` matches multihashes unless `useWholeCids(true)`;
  - wrapping a CARv2 again is accepted and produces a broken file;
  - the UnixFS selector needs the dag-pb prototype chooser.
- **Upstream bug:** go-car v2.17.0's `AttachIndex` always fails (it opens with `O_APPEND`,
  then writes with `WriteAt`, which Go refuses), and no go-car test covers it. ⏳ Report it
  upstream if the owner wants (the AI-transparency rule for third-party issues applies).

## Feito: callbacks sob demanda, erros do Go e o recorte pelo nó (0.17.0)

Decisões do dono: callback de verdade no Go, com os argumentos levados ao Dart sob demanda;
o Go produz N à frente, com N padrão medido (chamadas de sistema e Android) e passado como
argumento opcional da chamada (`batchSize`); "semáforo" dos objetos em uso para o app
colorir (sem Riverpod na lib); o recorte pelo gateway do boxo e o que for preciso do
ipld-prime; o `bsadapter` aprovado.

- Sentinelas: o evento de erro leva o código do `errors.Is`; `IpfsEof`,
  `IpfsUnexpectedEof`, `IpfsCanceled`, `IpfsDeadlineExceeded`, `IpfsNotFound`.
- Callback (`go/callback.go`, `lib/src/runtime/callback.dart`): o Go chama, o Dart responde
  por lote; `false` ou exceção param o Go, e a exceção Dart original é a da chamada. O Go
  espera a confirmação de cada lote (fica no máximo `batchSize - 1` à frente; com 1 é a
  semântica do Go). Callback que recebe objetos Go tem lote padrão 1: o `exploreFields` do
  construtor de seletores dava `panic: misuse` com 1024, porque o `fields` só vale durante a
  invocação.
- Impasse (`go/deadlock.go`): o app marca o pedido que leva um objeto em uso (`modeWatch`);
  o host o roda vigiado (labels do pprof) e, parado num mutex por 1 s enquanto um callback
  espera o Dart, responde `IpfsDeadlockException`; a função Go volta e solta a trava. O
  laço de despacho roda síncronas em linha, por isso a vigia é do host: um vigia no Dart
  não veria nada com o laço preso. Para a vigia valer por qualquer objeto Dart do mesmo
  objeto Go (um cast), o host dá o mesmo handle ao mesmo objeto, com contagem.
- `isBusy` e `IpfsService.busy` (`IpfsBusy`); Riverpod fica com o app.
- Recorte: `gateway.BlocksBackend.getCar` (escopo, ordem, duplicatas, faixa de bytes; rede:
  testado entre dois nós online, B sem os blocos baixa o CAR de A por bitswap e as fatias
  reconstroem o arquivo e a faixa pedida),
  `bsadapter` sobre o `node.blockstore` (seletor qualquer, blocos locais), go-unixfsnode
  (seletor por nome de arquivo) com o escolhedor dag-pb do gateway, e o construtor de
  seletores. Achado com oráculo Go: sem `withTraversalPrototypeChooser(dagpb...)`, o go-car
  decodifica dag-pb como dado genérico e o seletor UnixFS para na pasta (1 bloco); com ele,
  os mesmos 4 blocos do `entity` do gateway.
- Gerador: callback (`kFunc`), ponteiro para básico (`int?`), raiz que é só um tipo struct
  (construtor vazio), cast para a interface que embute a de origem, `linkConcrete` também
  para interfaces usadas como parâmetro (a com métodos expostos ganha), construtores de
  opção omitidos de propósito (`omitCtors`: o Prometheus), func sem nome idêntica a um tipo
  nomeado de um pacote importado, receptor de E/S por handle simples.

Lote padrão (`dart run tool/bench_callback.dart`; função 27 do host, sem kubo no meio;
itens/s, com 1 / 64 / 1024 / 4096 itens por lote, mediana de 3):

| item | Windows | linux (WSL) | emulador Android (x86_64) |
|---|---|---|---|
| 16 B | 39 mil / 1,56 M / 3,6 M / 4,6 M | 4,6 mil / 383 mil / 791 mil / 1,9 M | 408 / 19,6 mil / 262 mil / 553 mil |
| 64 B | 42 mil / 1,27 M / 2,7 M / 2,4 M | 9,6 mil / 482 mil / 1,52 M / 1,45 M | 361 / 25,7 mil / 212 mil / 311 mil |
| 1 KiB | 39 mil / 378 mil / 228 mil / 273 mil | 9,7 mil / 178 mil / 199 mil / 212 mil | 365 / 14 mil / 51 mil / 61 mil |
| 64 KiB | 602 MB/s com 1; 290–330 MB/s com 16 ou mais | 260 MB/s com 1; 338 com 2; ~190 com mais | 20 MB/s com 1; 54–70 MB/s com 8 ou mais |

O que decide é o tamanho do lote em bytes: acima de ~128 KiB a vazão cai pela metade no
Windows e no linux, e a espera pelo primeiro item sobe para milissegundos. Sininhos
(chamadas de sistema) por item: no linux, 0,5 com lote 1 e menos de 0,005 com 64 ou mais;
no Windows, perto de zero sempre (os dois lados giram antes de dormir). No emulador cada ida
e volta custa milissegundos (já visto na 0.9.0), e o lote maior sempre ajuda. Padrão: 1024
itens, até 128 KiB. ⏳ Confirmar no aparelho real (`integration_test/callback_bench_test.dart`
do app): não estava conectado nesta rodada.

## Feito: o go-car no namespace car (0.16.0)

Pedido do dono: mais recursos de arquivos CAR, em baixo nível; escolhidos os quatro grupos
(leitura, blockstore CAR, conversões, travessia seletiva) e o que mais faltasse (índice,
cabeçalho, leitura por stream). Tudo gerado do `go-car/v2` v2.17.0 pelo `roots.txt`, nada à
mão: `package:ipfs_ffi/car.dart` (`car/v2.dart`, `car/v2/blockstore.dart`,
`car/v2/index.dart`, `car/v2/storage.dart`), mais o `LinkSystem` e os seletores do
`go-ipld-prime` (namespace `ipld`, em `ipld/prime/...`), os códigos do `go-multicodec`
(`multiformats/multicodec.dart`), o `cid.Prefix` (o CID de um bloco novo, sem nó) e
`os.Open`/`os.OpenFile`/`bytes.Buffer` no `go`.

Seis regras novas no gerador (API.md, "Adaptações"):

- Interface de E/S em parâmetro (`io.ReaderAt`, `io.ReadSeeker`, `car.SectionReader`...)
  vale como o `io.Reader`: `Object`, com bytes ou qualquer handle (`decIO[T]` no host).
- **`io.Writer` em parâmetro passa a existir** (`GoHandle?`, null = `io.Discard`): `os.File`
  ou `bytes.Buffer`. Quebra a assinatura do `createIdentity`, que vira
  `createIdentity(null, opts)`; os chamadores (exemplos, testes, app, README) já foram.
- Mapa com chave inteira (`Stats.CodecCounts`, `map[multicodec.Code]uint64`) vira
  `Map<int, int>`.
- Instantâneo em parâmetro (`ReadWrite.put(ctx, Block(cid: c, rawData: d))`): o Dart monta a
  classe e o host a recebe numa struct que devolve os valores.
- Método de DTO (`Header.hasIndex`, `withDataSize`, `Prefix.sum`): o receptor vai por valor.
- Struct de campos exportados que é objeto (`linking.LinkSystem`) é handle (`handleTypes`); o
  handle de struct devolvida por valor guarda o ponteiro, para valer como `T` e `*T`.

Corrigido no caminho: `NewX` que devolve um DTO virava factory, que a classe DTO não
emite, e a função sumia sem aviso (agora é função do pacote: `car.newHeader`); o
`linkConcrete` contava os casts como métodos da interface (o `ProtoNode` passava a estender
o `datamodel.Node` do ipld-prime).

Fora, com o motivo: `Has`/`Get`/`Put` do `car/v2/storage` (a chave é o CID binário,
`KeyString`, que uma `String` do Dart não leva pelo fio; para escrever, o
`blockstore.ReadWrite`); `index.GetAll`/`ForEach` (recebem uma função do Go); a travessia
seletiva a partir do nó (nenhuma biblioteca dá um `LinkSystem` sobre o blockstore do kubo;
o caminho coberto é CAR → seletor → CAR; o nó segue com o `dagExport` do DAG inteiro). O
fim do `BlockReader.next()` é o `io.EOF` do Go: `IpfsException` com `message == 'EOF'`.

Validado: `test/car_test.dart` (leitura e estatísticas, bloco a bloco por bytes e por
arquivo, wrap/extract/troca de raízes/cabeçalho, índice gerado, serializado e lido de volta,
ReadWrite → ReadOnly, travessia `MatchPoint`/`ExploreAllRecursively`/JSON), `TestDecIO` no
Go e o exemplo 12; desktop 67/67 no Windows e no linux (WSL).

Vazão (`dart run tool/bench_car.dart`, 64 MiB por rodada, sem nó; MB/s, e µs por bloco
entre parênteses; Windows nativo | linux no WSL):

| operação | blocos de 256 KiB | blocos de 4 KiB |
|---|---|---|
| `Prefix.sum` (CID; Dart → Go) | 603 \| 268 | 324 (12) \| 190 (21) |
| `ReadWrite.put`, um por chamada (Dart → Go) | 372 \| 196 | 41 (95) \| 18 (213) |
| `ReadWrite.putMany`, 64 por chamada | 366 \| 122 | 125 (31) \| 97 (40) |
| `BlockReader.next` (Go → Dart) | 413 \| 195 | 155 (25) \| 67 (58) |
| `ReadOnly.get` por CID (Go → Dart) | 470 \| 203 | 64 (62) \| 25 (155) |
| `io.ReadAll` do arquivo, uma chamada (Go → Dart) | 694 \| 132 | 636 \| 131 |
| `Reader.inspect(true)` (só no Go, piso do go-car) | 1017 \| 861 | 536 \| 640 |
| `File.readAsBytesSync` (Dart puro, piso do disco) | 2004 \| 1003 | 2266 \| 1114 |

Com blocos grandes, a ponte entrega de 1/3 a 2/3 do go-car sozinho. Com blocos pequenos
manda o custo por chamada: as assíncronas (`put`, `get`, com `context`) custam 60–95 µs
no Windows contra 25 µs da síncrona (`next`), e o `putMany` em lote triplica a vazão do
`put`. O WSL fica de 2 a 5 vezes abaixo do Windows nativo (é uma VM).

## Feito: o que quebrava sem aviso e o aparelho real (0.15.0)

Decisões do dono: todo comando é `Stream` (quem usa decide); os bugs do upstream viram
issue, teste do upstream e patch nosso (o build para se o trecho mudar de lugar); a
notificação do serviço em primeiro plano é do app, o serviço segue com o plugin. Fora:
linux nativo (fica o WSL), arm64 no emulador x86, `ipfs commands`, chamadas do Go para
o Dart.

- Comandos: os 148 viram `Stream` (sai a leitura do fonte do kubo); fumaça de todos em
  `test/commands_smoke_test.dart` (a tabela `test/src/commands_smoke.dart` sai do
  gerador): 372 valores decodificados, 77 erros do próprio kubo num nó offline, e os de
  rede em dois nós. A fumaça achou e o host corrige: o `diag cmds` emite um tipo com o
  mesmo JSON do declarado (vai pelo JSON, como no cliente HTTP); os de pubsub esperam o
  tópico em multibase (o host roda o `urlArgsEncoder` do CLI).
- `ConfigRoot` sem reflexão: o host limpa o caminho do `fsrepo.Open` (`argPre`
  `repoPath`), e reabrir pelo `Path()` reaproveita o repo aberto (teste Go com caminho
  sujo).
- `uint64`: os mesmos 64 bits num `int` (como o `Uint64List`); a doc dos campos avisa e
  os testes cobrem `MaxUint64`.
- Upstream: [ipfs/boxo#1221](https://github.com/ipfs/boxo/issues/1221) (append no MFS
  com dados embutidos) e [ipfs/kubo#11477](https://github.com/ipfs/kubo/issues/11477)
  (Routing none deixa o keystore aberto), com a causa e a correção; `upstreamPatches` no
  `tool/build.dart` (todas as plataformas), `go/upstream_test.go` (o bug sem patch; com
  patch, os dois testes falham como devem) e as suítes do boxo (`unixfs/mod`, `mfs`,
  `trickle`) e do kubo (`core/node`) verdes com os patches. ⏳ PRs: o boxo exige um PR
  companheiro no kubo com CI verde, e o `ipld/unixfs` é "protocol-frozen" no AGENTS.md
  dele; esperar a triagem dos issues.
- Plugin: `requestNotificationPermission()` (o diálogo do Android 13+) e a notificação do
  app (`IpfsNotification`: título, texto, ícone, canal, importância, toque; o
  `updateNotification` com o serviço rodando; para controle total, um
  `NotificationFactory` nativo).

Aparelho real, Android 16 (HyperOS), arm64, Wi-Fi, ~1 h de sessão pela depuração sem fio
(`example/android_app/tool/device_session.dart`); o primeiro desde o 0.9.0:

- Integração 4/4 (verificações locais, queda do host com o app vivo, segundo plano nos
  dois modos). Canal (debug): Noop síncrono 4,7 µs, assíncrono 745 µs; `block.stat`
  1,5 ms. Release: Noop 1,5 µs, assíncrono 258 µs, `block.stat` 818 µs.
- **Achado: o host arm64 sem cgo** (até o 0.14) ficava sem DNS (o Go puro procura
  `/etc/resolv.conf`, cai em `[::1]:53`) e sem os endereços de rede (o anet lê o nível de
  API pelo cgo; sem ele volta ao netlink negado). O emulador x86_64 já tinha cgo (o Go
  não liga android/amd64 sozinho), por isso passava. Agora as duas ABIs vão com cgo.
  Depois: 153 peers em menos de 1 s, escuta QUIC/WebTransport/WebRTC, `/ipns/ipfs.tech`
  em 189 ms, 50 conexões (33 QUIC) e 7 endereços de relay com 2 min online.
- **Achado: queda em `foregroundService` no segundo plano**: o restart do `onStop` não
  conseguia recriar o serviço em primeiro plano (`ForegroundServiceStartNotAllowed`, o
  Android 12+ só o inicia com o app na frente) e o host ficava fora. Agora o serviço do
  Android fica de pé na queda e o restart o reaproveita (teste desktop com plataforma
  falsa). No aparelho: queda aos 2 min no segundo plano, host de volta na hora, app no
  mesmo processo por 6 min.
- `POST_NOTIFICATIONS`: diálogo, `granted=true`, notificação visível com o serviço em
  primeiro plano; a do app (título próprio, "online: N peers") atualiza com o serviço
  rodando. Modo `stop`: o host para em menos de 30 s no HOME, o app segue, e o relança na
  volta.
- Memória (PSS) com o nó online: release, app 168 MB + `ipfs_host` 196 MB ≈ 364 MB (APK
  arm64 de 27 MB); debug, 321 + 200 MB.
- "Custo da ponte" (investigado no aparelho, profile, `integration_test/bench_test.dart`):
  isolada, uma chamada gerada custa 2–4 µs na mediana (Noop 0,9–1,5 µs); `api.unixfs()`
  4,3 µs mesmo com o nó online (211 peers). A cauda é o acordar de thread: quando o Dart
  demora mais que a janela de giro do host entre chamadas (~20–50 µs), o host dorme no
  sininho e a chamada seguinte paga 100–450 µs (p99); um giro 10× maior encurta a cauda,
  mas não de forma consistente, e o padrão ficou. Os 80× da bateria eram a média, logo
  depois dos testes pesados (nós ainda fechando no host); a verificação agora compara
  medianas: `api.unixfs()` 3,6 µs × Noop 1,5 µs (profile, depois dos testes pesados).
- Dados móveis (LTE, só a rede da operadora, adb por USB): integração 4/4 (a queda do host
  e os dois modos de segundo plano), a bateria do app inteira verde e a rede: 131–132 peers
  em menos de 1 s, `/ipns/ipfs.tech` em 0,2–1,6 s. O nó anuncia o IPv4 da operadora (CGNAT
  `100.x`) e IPv6 globais (no 0.8.0 não anunciava os IPv6). Discando do PC (IPv6 do
  provedor): direta por IPv6/TCP em ~6 s (ping 166–206 ms); por IPv6/QUIC e pelo IPv4 só
  pelo relay, em 7–9 s (ping ~310 ms). Em 15/10 o QUIC por IPv6 entrou direto: a operadora
  tratou o UDP de entrada de outro jeito hoje. A reserva de relay variou: 11 endereços em
  2 min numa vez, e noutra só 90 s depois disso; a verificação de alcançabilidade espera
  agora até mais 2 min pelo relay ou por uma conexão de entrada.

Desktop 61/61 (Windows; linux 3x pelo WSL); emulador 4/4.

## Feito: os comandos do RPC (0.14.0)

Decisões do dono: um DTO para cada retorno; `Future`, e `Stream` só nos que emitem vários; os
portes à mão de `dag` ficam (o gerador não gera outro com o mesmo nome).

- `go/gen/commands.go` percorre `core/commands.Root` (148 comandos) e gera
  `lib/kubo/core/commands.dart`; a função 36 do host (`go/manual_commands.go`) chama
  `Root.Call` como o servidor HTTP do kubo, com o nó do app. Esquema dos DTOs e codificador
  do host saem do mesmo `go/cmdschema`; o hash do Hello cobre o esquema.
- `Future`/`Stream` sai do fonte do kubo: `cmds.EmitOnce` sem `.Emit(` é `Future`; os que
  emitem `io.Reader` são `Stream<Uint8List>` (tabela `cmdByteOut`); sem `Type`, `Object?`.
- Fora, com o motivo no `API.md`: `shutdown`, `mount`, `update`, `commands`, `config edit` e
  os quatro `dag` à mão.
- Corrigido no caminho: o `Emit` de um `io.Reader` tem de ler tudo antes de voltar (o
  `files read` fecha o fd quando o `Run` volta: `read failed: file closed`); no Windows o
  `fsrepo` só reaproveita o repo aberto pela mesma string do `Open` (`lock is already held
  by us` nos comandos de config), e o host passa essa chave como `ConfigRoot`.
- Raiz `chunker.sizeSplitterGen` (o produtor do `SplitterGen` do `mfs.withChunker`).
- O `go.mod` ganhou as dependências indiretas que o `core/commands` do kubo já trazia; o
  `ipfs_host` do Windows foi de 57,1 para 60,1 MB.

Desktop 52/52 (Windows, linux 3x); integração 4/4 no emulador, com `id` e `files` pela rota
dos comandos.

## Feito: CoreAPI completa e o baixo nível de MFS, config e peering (0.13.0)

Decisões do dono: tudo do kubo, na ordem CoreAPI → baixo nível → comandos; MFS e config nos
dois níveis; "não refaz nada na mão em Dart, sempre expõe o que existe na versão em Go".

- CoreAPI: `withOptions` (`options.api.offline/fetchBlocks`), `routing().get/put`,
  `object().addLink/rmLink/diff` (com `diffAdd/diffRemove/diffMod`), `Reader.size`.
- Peças novas no gerador, todas gerais:
  - G1: constantes como raiz;
  - G2: campos de struct como raiz, com leitura e escrita;
  - G3: casts de interface para cada tipo concreto exposto, como o `switch x.(type)`;
  - G4: construtores de opção que são funções do pacote, só no formato `func(*T)` ou
    `func(*T) error` (o `libp2p.RoutingOption` não é opção); uma opção dentro de outra
    vai como lista de uma;
  - G5: buffer de saída (`Read`, `ReadAt`, `CtxReadFull` devolvem os bytes lidos);
  - G6: valor dinâmico `any`/`interface{}` (codec com etiqueta, `Object?` no Dart).
- Baixo nível: o `boxo/mfs` inteiro de uso (`lookup`, `mkdir`, `mv`, `putNode`,
  `flushPath`, `Directory`, `File`, `FileDescriptor`); `node.filesRoot`, `node.repo`
  (`setConfigKey`/`getConfigKey`/`setConfig`/`backupConfig`), `node.peering`
  (`addPeer`/`removePeer`/`listPeers`), `config.parseBootstrapPeers`/`bootstrapPeerStrings`.
- Nome repetido entre libraries de um namespace (`files.File` e `mfs.File`): o arquivo do
  namespace esconde o da segunda (`export 'boxo/mfs.dart' hide File;`), com um comentário;
  as libraries por pacote mantêm os nomes do Go.
- Corrigido no caminho: o nome do pipe/socket do canal (hora + pid) colidia entre isolates
  do mesmo processo no Windows (`All pipe instances are busy`, intermitente nos testes); agora é
  aleatório (`Random.secure`). O `any` e o `interface{}` caíam na mesma chave do cache do
  gerador (o alias voltava vazio).
- Achado no boxo v0.43.0, reproduzido em Go puro: anexar no fim de um arquivo do MFS cujo nó
  guarda os dados embutidos deixa a leitura só com o trecho anexado (README).

Desktop 44/44 (Windows 4x, linux 3x); integração 4/4 no emulador.

## Feito: CAR no namespace kubo (0.12.0)

Decisão do dono: regra estrita, um namespace por módulo Go. O `export`/`import` de CAR é porte
dos comandos `ipfs dag export/import` do kubo (`go/manual_car.go`), não função do módulo
`github.com/ipld/go-car`: voltou para `kubo/core/commands/dag.dart`, ao lado do `dagPut`/`dagGet`,
como `dagExport`, `dagExportFile`, `dagImport`, `dagImportFiles` e `CarImportResult`
(`kubo.dagExport(...)` no namespace). O `car` ficou reservado ao `go-car` na tabela do
gerador (`go/gen/namespaces.go`) e só passa a existir quando uma raiz dele for exposta.
Validado: exemplo 07 de ponta a ponta (export de uma pasta, import noutro repo), desktop e
integração no emulador.

## Feito: namespaces (0.11.0)

Decisão do dono: a API em namespaces, um por módulo Go, com os dois jeitos de importar.
`lib/<namespace>.dart` exporta tudo do namespace (`import 'package:ipfs_ffi/kubo.dart' as
kubo;`) e as libraries por pacote Go continuam embaixo (`kubo/repo/fsrepo.dart`).
Namespaces: `kubo`, `boxo`, `car` (na 0.11.0 com o export/import de CAR; na 0.12.0 ele voltou
ao `kubo`, ver acima), `ipld` (`go-ipld-format`,
`go-block-format`), `multiformats` (`go-cid`, `go-multiaddr`), `libp2p` e `go` (`context`,
`io`, `os`, `runtime/debug` da biblioteca padrão). A tabela módulo → namespace fica em
`go/gen/namespaces.go`; módulo novo sem linha nela é erro do gerador. O gerador escreve os
arquivos de namespace (com as libraries escritas à mão da pasta) e remove os gerados que
sobram (`-check` acusa). Único conflito de nome: `dag put/get` portados à mão contra as
opções `put` do kubo; viraram `dagPut`/`dagGet`. Validado: o exemplo do README rodado,
desktop 39/39 (Windows e linux 3x), integração 4/4 no emulador.

## Feito: o segundo plano do Android (0.10.0)

Achado na 0.9.0: o `ipfs_host` é processo filho do app (mesmo usuário, contexto SELinux e
cgroup). No emulador, um minuto depois do HOME, o *phantom process killer* do Android 12+
o matou (`excessive cpu 181590 during 300024 ... limit=25`) e matou o app junto ("Caused by
child process"), sem `onCrash`. Decisões do dono: os dois caminhos, escolhidos por
`IpfsService.background` (lido a cada `start`/`restart`), padrão parar; ao parar, o pacote
só avisa (o tipo de parada no callback e na exceção) e subir de novo fica com o app; o
código Android num plugin companheiro, `flutter`.

- `IpfsStop`/`onStop` (eram `IpfsCrash`/`onCrash`) com `IpfsStopReason` (`crash`,
  `background`); `IpfsServiceException.reason`, também nas chamadas novas depois da
  parada; `IpfsService.appInBackground()`; gancho `IpfsService.platform`.
- Plugin `ipfs_ffi_flutter` (Java, sem dependências): registra-se sozinho
  (`dartPluginClass`), chama `appInBackground` no `onPause` e, no modo
  `foregroundService`, sobe com o host um serviço em primeiro plano `specialUse` com
  notificação (o Android 12+ não deixa iniciá-lo do segundo plano).
- App de exemplo: modo por `--dart-define=IPFS_BACKGROUND`; o `_onStop` trata queda e
  segundo plano; a volta ao primeiro plano relança.

Validado no emulador (Android 17), app em release, HOME por 7 min:
- `stop`: o serviço parou 5 s depois do HOME, o app seguiu no mesmo pid, nenhum kill; na
  volta o app relançou o host e o nó subiu.
- `foregroundService`: `IpfsForegroundService` com `isForeground=true` (tipo
  `specialUse`), app e host com os mesmos pids depois de 7 min, nenhum kill; na volta,
  nada a relançar.

Integração 4/4 no emulador; desktop 39/39 no Windows e no linux (3x). No aparelho real
(0.15.0): o serviço em primeiro plano segurou o host 6 min no segundo plano, com uma
queda e o reinício no meio.

Na mesma versão, decisão do dono: a lib publicada fica em inglês (comentários e
mensagens de `lib/`, o que o gerador escreve nela, o plugin e as mensagens do `ipfs_host`
e da `ipfs_shm`); testes e docs seguem em português.

## Feito: o kubo num processo separado (0.9.0)

Objetivo: um panic não tratado dentro do kubo/boxo não fecha o app; o app recebe
uma exceção e o relatório e decide se relança o serviço, com a mesma API gerada. Plano: o mesmo Go
compilado também como executável (`ipfs_host`), Unix socket / named pipe só como
"sininho", chamadas e respostas por memória compartilhada (dois anéis SPSC),
codificação binária gerada e uma biblioteca C pequena (`ipfs_shm`) no processo do
app para as atômicas (o `dart:ffi` não tem) e a espera "gira, depois dorme".

**P0, onde um panic do Go derruba o quê** (Go 1.26.5: `fatalpanic` termina em
`exit(2)`, que é `ExitProcess`/`exit_group`, ou em `crash()` = `SIGABRT`; o
processo inteiro, sem gancho), medido em `test/kubo_test.dart` (os testes do modo
dentro do processo saíram com ele no P2; o "outro processo" ficou):

| Onde roda o Go | Resultado |
|---|---|
| DLL / `.so` no processo do app (plugin) | o processo cai (teste "panic em goroutine do Go") |
| um Isolate de fundo (`test/crash_isolate.dart`) | o processo inteiro cai: código 2 no Windows, 134 (`SIGABRT`) no linux; o isolate principal não sobrevive |
| outro processo | só ele cai; quem o lançou segue e pode relançá-lo |

**P1, o transporte** (feito): `go/shmring` (os dois anéis; layout = contrato com o C),
`go/host*.go` (o `main()` do executável: memfd + Unix socket + `SCM_RIGHTS` no
linux/Android; `CreateFileMapping` + dois named pipes de um sentido no Windows),
`shm/ipfs_shm.c` (atômicas C11, espera "gira, depois dorme", thread que acorda o
Dart por `NativeCallable.listener`), `lib/src/shm.dart` (lança o host, `call`/
`callSync`) e o `tool/build.dart` gerando lib + host + ipfs_shm. Testes:
`go test -race ./shmring`, `test/shm_test.dart` (o host morto falha as pendentes com
`IpfsServiceException` na hora: o socket/pipe fecha, sem verificação periódica).
Medido com a função `Noop` (`tool/bench_shm.dart`, AOT):

| | Windows | linux (WSL) |
|---|---|---|
| ida e volta síncrona | 1,39–1,42 µs (~710 mil/s) | 2,49 µs (~400 mil/s) |
| 1 milhão em voo | 907–944 mil/s | 865 mil/s |
| só o Dart criando e completando 1 milhão de `Future`s | 940–980 mil/s | — |

O canal fica a ~96% do teto do próprio Dart para `Future`s: passar de 1 milhão por
segundo pediria uma API em lote (vários pedidos num `Future`), não um transporte
mais rápido.

**P2, o protocolo binário** (feito; contrato no `WIRE.md`): o Go do host
(`go/wire.go`, `go/gen/emit_go.go`, `manual_*.go`) e o Dart do app
(`lib/src/runtime.dart` + `runtime/codec.dart`, `go/gen/emit_dart.go`,
`lib/service.dart`: `IpfsService.start()`/`stop()`). O app não carrega mais Go; a API
gerada não mudou para quem usa (só pede o `start` antes). Handles com época (de um
serviço anterior: `IpfsServiceException`), soltos em lote pelo `Finalizer`. Testes:
`test/codec_test.dart` (o codec sem host) e `test/kubo_test.dart` inteiro sobre o host,
com o host derrubado por um panic numa goroutine e relançado (26/26 no Windows).
Medido com `dart run tool/bench.dart` (JIT, Windows):

| Chamada | µs |
|---|---|
| `Noop` síncrono (piso do canal) / assíncrono | 1,4 / 29 |
| `ctx.err()` / `withTimeout` + `cancel` | 2,8 / 9,1 |
| `node.cid()` / `node.rawData()` 1 KiB / `RawNode(1 KiB)` | 3,8 / 4,0 / 7,3 |
| `api.unixfs()` (handle novo a cada chamada) | 6,4 |
| `fsrepo.isInitialized` (consulta o disco) | 54 |
| `resolvePath` / `block.stat` / `unixfs.add` 1 KiB, assíncronos | 80 / 256 / 311 |

Linux validado depois da integração (37/37, 3 rodadas), com uma correção de ordem: a
chamada só completa depois que os ouvintes dos sinks dela receberam o fim.

**P3, queda** (feito): decisão do dono, a queda é tratada por quem usa o pacote, não
por um reinício automático. `IpfsService.start(onCrash: ...)` (padrão `null`) recebe um
`IpfsCrash`: código de saída, relatório do Go (só o trecho novo do `crashLog`, que o
host abre em modo de acréscimo, ou o stderr), caminho do `crashLog`, pid e tempo de
pé; o app decide limpar o log e chamar `IpfsService.restart()` (os parâmetros do último
`start`). Teste: o gancho 24 derruba o host; o processo de teste segue, o `onCrash`
recebe o panic, o serviço fica fora (`isRunning` falso, chamadas dão
`IpfsServiceException`) até o `restart()`; depois o pid muda, um handle antigo dá
`IpfsServiceException` e um nó novo (plugins injetados de novo: processo novo) faz
`add`/`get`. 38/38 no Windows e no linux (3x).

**P4, Android** (feito, emulador x86_64 Android 17; o aparelho fica para quando for
reconectado): `tool/build.dart android` gera `libipfs_host.so` (o host, executável) e
`libipfs_shm.so` por ABI; o Gradle do app extrai as libs (`useLegacyPackaging`), e o
host roda da `nativeLibraryDir` com memfd + Unix socket + `SCM_RIGHTS` sem ajuste. O
app trata a queda no `onCrash` (mostra o relatório, limpa o `crash.log`, `restart()`,
plugins e nó de novo). Teste de integração 2/2 (verificações locais; panic → só o host
cai, saída 2, `onCrash`, `restart`, verificações de novo). O app em release: todas as
verificações (rede pública, DNSLink, dois nós, CAR...) verdes; o crash automático
derrubou o host (saída 2), o app seguiu no mesmo pid, relançou o host e o nó subiu de
novo. Achado no caminho: com `spin: 0` a thread que acorda o Dart girava para sempre
sem entregar a resposta que chegasse entre o giro e o sono (corrigido em
`shm/ipfs_shm.c`; teste "spin 0" em `test/shm_test.dart`).

**P5, medição** (emulador, app em release/AOT; Noop = função 0, o piso do canal):

| `spin` | Noop síncrono | Noop assíncrono em sequência | 100 mil em voo |
|---|---|---|---|
| 0 | 10 ms | 8,2 ms | 3,4 µs/chamada |
| 2000 | 599 µs | 8,8 ms | 2,8 µs |
| 20000 (padrão) | 37 µs | 8,4 ms | 3,9 µs (~260 mil/s) |
| 200000 | 43 µs | 11 ms | 4,1 µs |

No emulador (Windows como hospedeiro) cada thread que dorme leva milissegundos para
acordar (a vCPU parada): o giro resolve o síncrono, mas o assíncrono em sequência
depende de acordar a isolate do Dart, onde não se gira. Com o nó online, as
verificações do app mediram `api.unixfs()` 91 µs, `ctx.err()` 100 µs, `block.stat`
assíncrono 1,6 ms. No aparelho real (0.15.0, release): Noop síncrono 1,5 µs, assíncrono
258 µs, `block.stat` 818 µs.
Memória com o nó online (emulador, `dumpsys meminfo`): app PSS 84 MB, `ipfs_host` PSS
137 MB.

## Feito: exports diretos para assinaturas simples (0.5.0)

Toda chamada passava pelo export único `IpfsCall` com JSON (~27 µs no Windows,
mesmo para um `bool`). Desde a 0.5.0 o gerador emite um `//export IpfsD<n>` com
tipos C para cada função **síncrona** só com número, `bool`, string e handle (26
das raízes: os getters da `CoreAPI`, `fsrepo.isInitialized/open`, `files.toFile`,
`os.stat`...); o resto continua no `IpfsCall`. A API Dart não mudou. Medido com
`dart run tool/bench.dart` (20 mil chamadas depois do aquecimento):

| Chamada | Windows antes | Windows depois | linux depois |
|---|---|---|---|
| `api.unixfs()` (handle → handle) | 24–26 µs | 4,2–4,4 µs | 1,5 µs |
| `fsrepo.isInitialized` (string → bool, consulta o disco) | 73–78 µs | 49–50 µs | 3,7 µs |
| `ctx.err()` (à mão, continua em JSON: controle) | 19 µs | 20 µs | 5,9 µs |

Desde a 0.8.0 também bytes, tipos-valor e o `context` (ver abaixo).

## Feito: relatório de crash (0.5.0)

Um panic numa goroutine interna do kubo (fora de uma chamada) não é recuperável no
processo: derruba o app. O `guard` cobre a chamada e todas as goroutines do próprio
ipfs_ffi (`try`/`goTry` em `go/runtime.go`: a do `IpfsCall` assíncrono, a das funções
do kubo com `chan<-` geradas e a do `chanSink` das opções), onde o panic vira
`IpfsException`; as do kubo e das dependências não têm como. `os.create(caminho)` +
`debug.setCrashOutput(f, debug.CrashOptions())` fazem o Go gravar o relatório
(`panic: ...` e o stack das goroutines) nesse arquivo; o app o lê no próximo início.

## Feito: o resto da comunicação por JSON (0.8.0, passos 1 e 2; o 3 não compensa)

1. **Exports diretos para bytes e tipos-valor** (gerador): bytes como ponteiro +
   tamanho (cópia nos dois lados), CID/path/peer ID/multiaddr/ipns.Name como string C
   (os mesmos `decX`/`encX` do JSON). 7 das 19 síncronas saíram do JSON (`newBytesFile`,
   `RawNode`, `nodeWithData`, `setData`, `data`, `cid`, `rawData`): 35 diretas, 12 no
   JSON. O `context.dart` virou exports diretos à mão (`go/manual_context.go`).
2. **As assíncronas medidas** (`dart run tool/bench.dart`; o `IpfsCall` síncrono roda a
   mesma entrada sem goroutine nem listener; `ipfs_ffi/test.Noop` é o piso):

| Chamada | Windows | aparelho (Xiaomi, arm64) |
|---|---|---|
| `node.cid()` direto × JSON | 6,2 × 24 µs | — |
| `node.rawData()` 1 KiB direto × JSON | 5,8 × 28 µs | — |
| `RawNode(1 KiB)` direto × JSON | 12 × 38 µs | — |
| `ctx.err()` (era JSON) | 2,8 µs (era 23,6) | 1,2 µs |
| `withTimeout` + `cancel` (eram 2 JSON) | 9,6 µs | 19,6 µs |
| `Noop` síncrono (custo fixo do JSON) | 21 µs | 40 µs |
| `Noop` assíncrono (+ goroutine e listener) | 83–89 µs | 435 µs |
| `block.stat` assíncrono × a mesma entrada síncrona | 266 × 240 µs | 1343 × 703 µs |
| `resolvePath` assíncrono × síncrono | 114 × 93 µs | — |
| `unixfs.add` 1 KiB assíncrono | 337 µs | — |

3. **Formato binário gerado: não feito.** O JSON é ~20 µs (Windows) / ~40 µs
   (aparelho) por chamada: 5–20 % de uma assíncrona no Windows e ~3 % no aparelho. O
   resto é o kubo e a volta pelo listener (`NativeCallable.listener` + event loop),
   que o formato não muda. Se o custo da ponte pesar, o alvo é o salto do listener
   (ex.: lote de resultados), não o JSON.

Seguem no JSON as 12 síncronas com structs, opções funcionais, `config.Config` ou
`io.Reader` (`Links`, `Stat`, `createIdentity`, `initWithIdentity`, `newCoreApi`,
`constructDefaultRouting`, `Repo.config`, `fsrepo.init`, `addrInfoFromString`,
`addrInfoToP2pAddrs`, `readAll`, `setCrashOutput`), as assíncronas e os streams.

## Marco final: Android (0.7.0 no emulador; 0.8.0 num aparelho real, dados móveis e Wi-Fi)

O mesmo nó mínimo num app Android, com a API Dart gerada sem mudança. Validado em
2026-10-11 no emulador `sdk_gphone16k_x86_64` (Android 17 / API 37, páginas de 16 KB),
com NDK 30.0.16248370 e o app Flutter de validação em `example/android_app`, e num aparelho
real: Xiaomi (Android 16, arm64-v8a), nos dados móveis (`ccmni*`, IPv4
100.x atrás do NAT da operadora + IPv6) e no Wi-Fi de casa (`wlan0`, 192.168.1.x).

| Etapa | O quê | Status |
|---|---|---|
| **A1. Build por ABI** | `dart run tool/build.dart android`: `GOOS=android`, clang do NDK (`--target=<arch>-linux-android24`), `-extldflags=-Wl,-z,max-page-size=16384`, `-checklinkname=0` (o `wlynxg/anet` usa linkname em `net.zoneCache`), e o `go-multiaddr/net` e o `zeroconf` trocados pelo anet (`-modfile` gerado, ver Netlink abaixo) → `native/android/<abi>/libipfs.so` | ✅ x86_64 79,4 MB, arm64-v8a 56,1 MB; `LOAD Align 0x4000`; exports conferidos |
| **A2. Carregar a lib** | `ipfsLibraryPath` = `libipfs.so` no Android; o Gradle do app empacota direto de `native/android` (`jniLibs.srcDirs`; só as ABIs do `--target-platform`, por `packaging.jniLibs.excludes`), `minSdk` 24, `INTERNET` no release | ✅ app abre a lib e sobe o nó |
| **A3. Nó no app** | `lib/checks.dart`: add/get, pins+GC, progresso, IPNS/chaves/dag, CAR, dois nós (bitswap, provide/findProviders, pubsub), ciclos, custo da ponte; rodam no `integration_test/ipfs_test.dart` e sozinhas ao abrir o app, que junta tudo num log com "copiar" (e no logcat; linhas longas saem cortadas lá, a caixa do app tem tudo) | ✅ 7/7 no emulador e no aparelho |
| **A4. Rede móvel** | roteamento do `Routing.Type` (perfis `randomports` + `lowpower`, com a lista padrão de endereços do kubo de volta: TCP + QUIC/WebTransport/WebRTC em UDP na porta sorteada); DNS por HTTPS no repo do app; anet (endereços locais e mDNS) e `MulticastLock` no app; verificações de rede no app (interfaces, peers entrada × saída, endereços, DNSLink + bloco da rede e, com 2 min online, transportes, conexões de entrada e na rede local, endereços de relay) | ✅ emulador: 94–245 peers, `/ipns/ipfs.tech` em 163 ms. Aparelho, 11/11: 8–23 peers medidos 2 s após subir; com 2 min online, 54–124 peers (metade ou mais por conexões QUIC de saída) e reserva em 2 relays. ⚠️ Até a correção de 2026-10-11 o app escutava só em TCP (o código que devolvia QUIC/UDP mexia num mapa que o `randomports` já tinha trocado); a verificação "endereços do nó" agora exige escuta em UDP; com o anet o nó anuncia o IP do Wi-Fi (192.168.1.x) ou o da operadora (100.x, IPv6 2804:…). Rede local: um nó no PC achou o celular por mDNS em 3 s e conectou direto nos dois sentidos. Dados móveis: o PC conectou pelo relay em ~2,6 s; com o UPnP do PC ligado, a conexão virou direta em ~7 s (inversão: o celular discou para o PC), com o UPnP desligado ficou no relay. Refeito em 2026-10-15 com escuta UDP: o celular (CGNAT 100.x da operadora) saindo sempre da porta QUIC de escuta 41079 apareceu como `181.77.x.x:61472` para um nó do PC e `:61475` para outro, ou seja, **NAT simétrico** (porta pública por destino); o PC sem UPnP ficou 90 s no relay sem virar direta. Com UPnP, a inversão virou direta em ~4 s. **IPv6** (PC com IPv6 nativo do provedor, sem UPnP; celular nos dados móveis): o PC discou direto no IPv6 do celular em 363 ms (QUIC) e 428 ms (TCP), ou seja, o firewall IPv6 da operadora deixa entrar; e pelo relay a conexão virou direta por IPv6 (`/ip6/2804:…/udp/41079/quic-v1`) em ~14 s. O libp2p do celular não anuncia esses IPv6 (o AutoNAT não os confirmou), mas eles chegam ao outro lado pelo relay. `/ipns/ipfs.tech` em 0,16–1,3 s |
| **A5. Ciclo de vida** | o app fecha o nó em `paused` e reabre em `resumed`; `debug.setCrashOutput` em `<dados do app>/crash.log`, mostrado no próximo início | ✅ background → volta reabre o nó (mesmo peer); 10 ciclos no teste (emulador e aparelho); crash de teste: na primeira abertura o app derruba o próprio processo (panic numa goroutine do Go) e, na seguinte, mostra o relatório do Go e o log da execução que caiu. ✅ emulador e aparelho |
| **A6. Custo** | APK, memória, ponte | ✅ APK release (arm64+x64) 167,9 MB; por aparelho ≈ 72 MB (arm64) / ≈ 97 MB (x86_64), quase tudo a `libipfs.so`; memória com o nó online há 60 s: PSS 192,6 MB, RSS 310 MB; ponte: `api.unixfs()` 5,7–8,1 µs, `fsrepo.isInitialized` 10,6–15 µs, `ctx.err()` (JSON) 14–27 µs. Aparelho (APK arm64 72,1 MB): PSS 286,6–298,2 MB, RSS 442–446 MB com o nó online há ~1 min depois das verificações; ponte 2,7 / 7,8 / 11,5 µs. ⏳ consumo de bateria e de dados ao longo do tempo |

Achados:
- Release: `flutter build apk --release --target-platform android-arm64` (72,1 MB, para
  aparelho) ou `android-arm64,android-x64` (sem isso o Flutter também põe as libs dele de
  armeabi-v7a, e o app instalaria num aparelho de 32 bits sem a `libipfs.so`). O Gradle do
  app só empacota a `libipfs.so` das ABIs pedidas.
- Ponteiros com tag: no arm64 do Android o alocador marca o byte mais alto do ponteiro
  (`0xB4…`), e o endereço do buffer de bytes, como `int` do Dart, chegava negativo ao Go
  (`json: cannot unmarshal number -5476376614457254512 into Go struct field cbuf.$p of type
  uintptr`): todo `add`/`get` falhava no aparelho, nunca no emulador. Os endereços cruzam
  agora como `int64` (`go/runtime.go`).
- DNS: o Android não tem `/etc/resolv.conf`, e o resolvedor do Go cai em `[::1]:53`
  (`lookup _dnslink.ipfs.tech. on [::1]:53: ... connection refused`). O app grava
  `DNS.Resolvers` `{".": "https://cloudflare-dns.com/dns-query"}` no repo novo. Quem usa a
  lib no Android precisa fazer o mesmo (ou a lib passa a configurar o resolvedor do Go).
- Netlink: desde o Android 11 o app não pode fazer `bind()` em socket netlink nem pedir
  `RTM_GETLINK`, e o `net.Interfaces`/`net.InterfaceAddrs` do Go falham (`route ip+net:
  netlinkrib: permission denied`; golang/go#40569): o libp2p cai no plano B de anunciar só
  127.0.0.1/::1 (`addrs_manager.go`) e o mDNS não acha interface. O `wlynxg/anet` (já no
  grafo pelo pion) refaz isso com `RTM_GETADDR` sem `bind()` e `ioctl`. No build do Android
  o `tool/build.dart` copia o `go-multiaddr` e o `zeroconf` do cache de módulos para
  `.dart_tool/patched_mod/android/` (junto com os patches do upstream), troca as chamadas pelo anet (o build para se o trecho mudar) e
  compila com um `-modfile` gerado com os `replace` (o Go recusa `-overlay` em arquivos do
  cache de módulos). O caminho dessas cópias fica no buildinfo da `.so`. Não coberto:
  UPnP/NAT-PMP (`go-netroute` usa netlink de rota) e outros ~10 pontos menores do grafo.
- Relay (circuit v2), medido com relay, nó privado e discador locais: a conexão dura até
  **2 min** ou 128 KiB (padrão do go-libp2p; o kubo sempre monta um limite, mesmo com a
  config) e **pubsub e bitswap não passam por ela** (conexão "limitada"): o relay só serve
  para montar uma conexão direta (inversão ou hole punching). O ConnMgr do discador não a
  derruba (sobreviveu ao corte de 226 para 27 peers); o `Peering` do kubo conecta pelo
  circuito, mas não refez a conexão em 130 s depois do limite. A queda em ~30 s vista com um
  relay público segue sem causa (o relay é de terceiros). Dois celulares atrás de NAT
  de operadora simétrico (o caso medido) não se falam direto por IPv4; por IPv6 sim, se os
  dois tiverem IPv6 (medido entre o celular e um PC com IPv6: direta em ~14 s a partir do
  relay; ⏳ dois celulares). Sem IPv6 em um dos lados, só um relay sem limite (fora do
  kubo: um relay do go-libp2p com `Limit: nil`) ou um peer alcançável (servidor, UPnP).
- APK arm64 no emulador x86_64 (tradução arm64→x86 do berberis) cai com SIGILL: o
  `golang.org/x/sys/cpu` não lê o `/proc/self/auxv` lá e cai no `mrs ID_AA64ISAR0_EL1`, que o
  kernel de um arm64 real emula e o tradutor não. No emulador use o build x86_64.
- Com `Routing.Type` none (`libp2p.nilRouterOption`) o kubo 0.43 não fecha o datastore do
  `provider-keystore` no `close` (o hook pula o provider Noop): reabrir o mesmo repo no mesmo
  processo falha com "resource temporarily unavailable". Com roteamento real não acontece.
- Quem baixa um bloco também passa a anunciá-lo (estratégia padrão do provide): numa busca
  por provedores, procure o peer esperado entre vários (`numProviders(5)`), não o primeiro.
- Limites que seguem: um nó por processo (plugins e métricas globais do kubo); iOS fora do
  escopo; a `.so` grande (cortar plugins/transportes não usados é o próximo passo se pesar).
