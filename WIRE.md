# The service protocol

`p2p_ffi` runs kubo **only** in a separate process, the `p2p_host` (this package's Go
built as an executable). An unhandled kubo panic stops that process, never the app: the
app gets `P2pServiceException` and decides whether to restart the service. The app does
not load Go; it loads only the `p2p_shm` (C), its side of the channel.

This document is the contract between the two sides. The generator (`go/gen`) emits the
host's Go and the app's Dart from it; what is hand-written follows the same rules.

## Channel

- A shared memory region with two SPSC rings (layout in `go/shmring/ring.go`): ring 0 =
  requests (app → host), ring 1 = responses and events (host → app). Linux/Android: a
  `memfd` passed with `SCM_RIGHTS` over the Unix socket; Windows: `CreateFileMapping`
  with a random name + two one-way named pipes.
- The socket/pipe is only the handshake, the bell (waking the side that sleeps) and crash
  detection (it closes when the process dies). Waiting: spin a little, then sleep on the
  bell.
- Each message goes in one or more `[u32 continues][piece]` frames; one that does not fit
  in a frame is split and reassembled (one producer at a time on each ring).

## Messages

Everything is little-endian.

- **Request**: `u32 id`, `u32 function`, `u8 mode`, arguments. Mode: `0` synchronous (the
  app blocks waiting), `1` asynchronous (`Future`), `2` stream; bit `0x80` (`modeWatch`)
  asks for deadlock watching (see "Callback").
- **Response/event**: `u32 id`, `u8 kind`, data. Kind: `0` value, `1` item (of a stream or
  of a sink), `2` end, `3` error. Kind `4`: a callback batch (see "Callback"), or one
  invocation of a retained callback (see "Retained callback"), whose end is a kind `2`
  with its id.
- **Error data** (kind `3`): `u8 code`, `str message` (`err.Error()`), `i64 errno` (the
  `syscall.Errno` of the chain, `errors.As`; `0` none), `u32 n` + n × `str` (the text of
  each link of the chain, from the outside in, through `Unwrap() error` and
  `Unwrap() []error`; at most 32), `u32 m` + m × (`u32 class`, `u32 link`, the class's
  fields): the links with a generated class (`errClass` in `zz_generated.go`, ids in the
  table hash; a link equal to several sentinels, like `os.ErrNotExist` and
  `fs.ErrNotExist`, comes once per class). Code of the fixed sentinel the error wraps
  (`errors.Is` in the host): `0` none, `1` `io.EOF` (`GolangEofException`), `2`
  `io.ErrUnexpectedEOF` (`GolangUnexpectedEofException`), `3` `context.Canceled`
  (`GolangCanceledException`), `4` `context.DeadlineExceeded`
  (`GolangDeadlineExceededException`), `5` not found (`ipld.ErrNotFound`, the `ErrNotFound`
  of go-car's storage; `GolangNotFoundException`), `6` deadlock with a callback (only the
  host produces it; `GolangDeadlockException`), `7` a panic of the call that the host
  recovered (`GolangPanicException`; after the links, `str` the Go stack of the panic).
  Dart throws the fixed sentinel's class,
  or else the class of the first link with one, or else `GolangException`; all of them
  carry the message, the errno, the texts and the links (`causes`). The host's own
  messages (unknown function, table mismatch) use the same layout with one text and no
  link.
- A call answers with a `value` or an `error`; a stream with `item`s and then `end` or
  `error`. A call's sinks (below) get `item`s and `end`/`error` with the sink's id,
  **before** the call's response.
- The `id` belongs to the app (the isolate's counter). Requests without a response use id 0.

## Functions

| id | function | arguments → response |
|---|---|---|
| 0 | Noop | — → empty value |
| 1 | Sleep (test) | `u32 ms` → empty value after ms |
| 2 | Echo (test) | bytes → the same bytes |
| 3 | Free | `u32 n`, n × `i64` handles → no response (id 0) |
| 4 | Hello | `u64` table hash → empty value, or an error if the host was generated from another table |
| 5 | CallbackAck | `u32` call id, `u8` verdict (`0` go on, `1` the Dart function returned false, `2` it threw); for a retained callback that returns a value, the value after a verdict `0` → no response (id 0) |
| 16 | context.Background | — → `i64` ctx |
| 17 | context.WithCancel | `i64` parent → `i64` ctx, `i64` cancel |
| 18 | context.WithTimeout | `i64` parent, `i64` ns → `i64` ctx, `i64` cancel |
| 19 | context.WithDeadline | `i64` parent, `i64` Unix ns → `i64` ctx, `i64` cancel |
| 20 | context.CancelFunc (call) | `i64` cancel → empty |
| 21 | context.Context.Err | `i64` ctx → `kError` (`u8` present + string) |
| 24 | test: PanicInGoroutine | — → empty; the host goes down right after |
| 25 | test: PanicInChanFunc | stream mode: `item` `i64` 1, then `error` with the panic |
| 26 | test: PanicInSink | `u32` sink → empty; the sink gets `item` `i64` 1 and then `error` with the panic |
| 27 | test: CallbackBench | `u32` batch, `i64` n, `i64` bytes per item; callback (`i64` index, `kBytes`) → `i64` items produced |
| 28 | test: BellStats | — → `i64` bells rung by the host, `i64` host wake-ups; resets both |
| 29 | test: NewLocker | — → `i64` handle of an object with a mutex |
| 30 | test: Locker.Iterate | `i64` locker, `u32` batch, `i64` n; holds the mutex and calls the callback (`i64` index) n times → empty |
| 31 | test: Locker.Touch | `i64` locker → empty, after taking and releasing the mutex |
| 32 | dag put | `i64` CoreAPI, `i64` ctx, `kBytes` data, string input-codec, string store-codec, string hash, bool pin, bool allow-big-block → `u8` present + string CID |
| 33 | dag get | `i64` CoreAPI, `i64` ctx, string path, string output-codec → `kBytes` |
| 34 | dag export | `i64` IpfsNode, `i64` ctx, string path, bool local-only, string file (`''` = returns the bytes) → `kBytes` (empty when it writes the file) |
| 35 | dag import | `i64` IpfsNode, `i64` ctx, `kSlice` of string files, `kBytes` CAR (`-1` = use the files), bool pin-roots, bool allow-big-block → `i32 n` roots × (string CID, string pin error), `i64` blocks, `i64` bytes |
| 36 | Command (the RPC commands) | stream mode: `i64` IpfsNode, `i64` ctx, string path (`"files stat"`), `kSlice` of string args, `kSlice` of `files.Node` handles (the `FileArg`s), `i32 n` options × (string name, `kAny` value) → `item`s (see "Commands") |
| 40 | config.Profiles | — → `i32 n` × string (names in order) |
| 41 | config.Profile.Transform | string name, string config JSON → string transformed config JSON |
| 42 | io.Reader.Stream | stream mode: `i64` handle of an `io.Reader` → one `kBytes` `item` per piece (up to 256 KiB), until EOF; closes the reader if it is an `io.Closer` |
| ≥ 64 | the generated ones | id = 64 + position in the list of exposed functions in key order (`assignIDs` in `go/gen/main.go`) |

The table hash (FNV-1a 64 of `"id key\n"` per generated function, combined with the hash of
the commands' schema and their DTOs) goes in the `Hello` right after connecting: app and
host must come from the same generator.

## Value encoding

Arguments in order (a method's receiver first; package variables have no arguments),
results in order without the final `error` (which becomes an error response). Named types
over basic types (kubo's enums) go as the basic type. By model kind (`go/gen/model.go`):

| kind | bytes |
|---|---|
| bool | `u8` (0/1) |
| integers (every size and sign) | `i64`; a `uint64` goes as the same 64 bits (in Dart, from 2^63 up, negative) |
| float | `f64` |
| string | `u32 n` + UTF-8 |
| `kBytes` (`[]byte`) | `i32 n` + bytes; `-1` = nil |
| `kValue` (CID, path, peer ID, multiaddr, ipns.Name) | `u8 present` + string (Go's text form) |
| `kValue` `time.Time` | `u8 present` + `i64` Unix nanoseconds |
| `kValue` `config.Config` | `u8 present` + string with kubo's own JSON (the format of the `config` file, which is the data itself) |
| `kHandle`, `kCtx` | `i64` handle; `0` = nil |
| `kDTO` | `u8 present` + the fields that cross, in `tinfo.fields` order |
| `kSnap` | `u8 present` + each getter in `tinfo.gets` order; a getter with an error = the value followed by a `kError`. As a parameter (`ReadWrite.Put(ctx, Block)`), the same format coming from Dart; the host builds a struct that returns the values |
| `kError` (an error inside a value) | `u8 present` + string |
| `kSlice` | `i32 n` + elements; `-1` = nil |
| `kMap` | `i32 n` + pairs: key (string; if `tinfo.mkey` is a value type, its string, **without** a presence byte; if it is an integer, `multicodec.Code`, the `i64`) + value |
| `kOpts` (functional options, variadic) | `i32 n` + each option: `u32` index of the constructor in `tinfo.ctors` + its parameters; a parameter that is itself an option (`options.Name.ResolveOption(namesys.ResolveWithDepth(1))`) goes as a `kOpts` of one |
| `kAny` (`any`/`interface{}`, a dynamic value) | `u8` tag + value: `0` null, `1` bool, `2` `i64`, `3` `f64`, `4` string, `5` `kBytes`, `6` list (`i32 n` + items), `7` map (`i32 n` + pairs of string key + item), `8` a value of a type the generator lists (`go/gen/tokens.go`: `u32` token + the type's encoding; host → app, the app builds the class), `9` a token (`u32`; app → host: `new(T)` of a listed type, or a listed Go function itself). In the host: pointers and interfaces are followed; `time.Time` and types with `MarshalText` (CID, peer ID, multiaddr) go as a string; structs as a map of the exported fields (the `json` name); maps with the keys in order. When reading, the host returns the `encoding/json` types (`int64` for integers) |
| output buffer (a `[]byte` Go fills: `Read`, `ReadAt`, `CtxReadFull`) | in the request, `i64` size (up to 64 MiB); in the response, `kBytes` with the bytes read. `io.EOF`/`io.ErrUnexpectedEOF` are not errors: the bytes read come back (empty at the end) |
| I/O interface parameter (`io.Reader`, `io.ReaderAt`, `io.ReadSeeker`...: only `Read ReadAt Seek Write WriteAt Close` methods) | `u8 0` + `kBytes` (read by a `bytes.Reader`; an error if it does not implement the interface), or `u8 1` + `i64` handle of an object that implements it |
| `kWriter` (`io.Writer`) | `i64` handle of an object that implements it (`os.File`, `bytes.Buffer`); `0` = `io.Discard` |
| DTO receiver (`car.Header.HasIndex`, `cid.Prefix.Sum`) | `kDTO` instead of the handle; what the method changes in the receiver does not come back |
| value type receiver (`cid.Cid.Version`, `peer.ID.ExtractPublicKey`) | `kValue` instead of the handle (the string, decoded by the type's `dec` in `wire.go`) |
| `kChanSend` inside an option (sink, e.g. `options.Unixfs.Events`) | `u32` sink id (registered by the app); the items go as `item` events with that id, and the sink ends with `end`/`error` before the call's response |
| `kChanSend` as a parameter of the function itself (e.g. `PinAPI.Ls`) | does not cross: the function is called in stream mode and each value Go puts in the channel is an `item` (like `kChanRecv`) |
| `kChanRecv` (`<-chan T` in the result) | the function is called in stream mode; each value of the channel is an `item` |

**Roots that are not functions** (`roots.txt`):
- a constant (`mfs.TFile`, `coreiface.DiffAdd`): only in Dart, as a `const`; it has no id;
- an exported field of a handle struct (`core.IpfsNode.FilesRoot`): a read function
  (receiver → value) and, if the type crosses as a parameter, a write one with the key
  `<line>=` (receiver, value → no response);
- a type assertion from an interface to a concrete handle that implements it (generated on
  its own for the types used, key `cast <interface> <concrete>`): receiver → new `i64`
  handle, or `0` if the object is not of that type (`BoxoMfsFsNode.asBoxoMfsDirectory()` in Dart).

**Handles**: the host keeps the objects in a table (`i64` from 1); the app frees them with
`Free` (in batches, through the `Finalizer`). A handle is only valid during the life of the
service it was born in: after a restart, using it gives `P2pServiceException`. The same
object by reference (pointer, map, channel) always has the same handle, with a count: each
time the host returns it counts one, and each `Free` takes one off; it leaves the table on
the last one.

## Callback

A function parameter (`func(...)` returning nothing, `bool` or `error`) is an on-demand
callback: the call is asynchronous, and in its place goes a `u32` batch size (`0` = the
host's default, 1024; the generated code sends `1` when the callback receives handles).

- The host passes the Go function a callback that, on each invocation, writes the
  arguments (in each type's format) into a batch. The batch closes after `batch`
  invocations or 128 KiB and goes as a kind `4` event with the call's id: `u32 n` + the n
  sets of arguments. Once the batch is closed, the invocation that closed it waits for the
  `CallbackAck` (function 5) and returns the verdict to Go: `false` (`bool` callback) or an
  internal error (`error` callback) when Dart stopped; before that, the batch's
  invocations return `true`/`nil`.
- The app calls the Dart function with each set, in order, one at a time (awaiting the
  `Future`s); after a `false` or an exception, it skips the rest. It acknowledges each
  batch with the accumulated verdict. The call's response is only delivered after the
  batches; if the Dart function threw, the call throws that exception, whatever Go's
  response.
- When the Go function returns, what is left in the batch goes without waiting; an
  acknowledgement that arrives after the end of the call is ignored.
- Deadlock: during the call, the handles it took are in use in the app. A request that
  takes a handle in use goes with `modeWatch`; the host runs it in a goroutine with the id
  in the pprof labels (the synchronous one too, with the loop waiting). If it stays parked
  on a mutex (`SemacquireMutex`/`SemacquireRWMutex` in the goroutine profile) for 1 s while
  some callback waits for a `CallbackAck`, the host answers `error` code `6` with the stack,
  and the goroutine's late response is discarded.

## Retained callback

A function Go keeps past the call (a handler: the generator's `retainedFuncs` table,
`host.Host.SetStreamHandler`), and each method of a Dart implementation of an interface (a
root that is an interface type, `mdns.Notifee`), is a retained callback. In its place goes
a `u32` id the app takes from its own counter, the same as a call's (`0` = nil: a method the
Dart implementation leaves out). The call itself stays synchronous or asynchronous as it
is.

- Each invocation goes as a kind `4` event with that id and one set of arguments (`u32 1`
  + the arguments), from whatever goroutine Go calls it on. The app runs the Dart function
  on its event loop, never inside a synchronous call.
- A function that returns nothing does not wait. One that returns `bool` or `error` waits
  for the `CallbackAck` (function 5) of that id, one invocation at a time: verdict `0` is
  `true`/`nil`, the others `false`/an internal error. One that returns a basic value
  (`pubsub.ValidatorEx`) gets it in the same `CallbackAck`, after verdict `0`; with another
  verdict Go returns the generator's `cbOnThrow` constant for that function type
  (`ValidationReject`), or the zero value. The app runs the function in the zone it was
  given in; a Dart exception goes to that zone and answers `2`.
- When Go's garbage collector frees the function (the handler removed, the host closed and
  dropped), the host sends `end` with the id, and the app drops its side. While Go holds
  it, the app keeps the Dart function; a stop of the service drops them all.
- A Dart implementation is a synchronous function of the generator (the factory of the
  interface's class): the ids of the methods, in the interface's method order, return the
  handle of a Go object that calls them.

## Commands (function 36)

The commands of kubo's tree (`core/commands.Root`, the RPC's `/api/v0`), generated into
`go.ipfs.kubo.core.commands` (`lib/go/ipfs/kubo/core/commands.dart`; each result type in the library of its Go package) by `go/gen/commands.go`. The host builds the go-ipfs-cmds
request (`NewRequest` + `FillDefaults`) and calls `Root.Call` like the kubo HTTP server
(without the CLI's `PreRun`), with the app's node in the environment (`ConstructNode`;
`ConfigRoot` = the key `fsrepo.Open` opened the repo with, so the config commands reopen
the same one).

- `PreRun` belongs to the CLI and does not run, with one exception: the `urlArgsEncoder` of
  the pubsub commands (`pubsub pub/sub/peers`), the client side of the contract (kubo's RPC
  client does the same); the host runs it, and Dart passes the raw topic.
- Options: only the ones passed (null in Dart = kubo's default); the host converts the
  `kAny` to the type the option declares (`int64` → `int`/`uint`..., list → `[]string`). An
  unknown name or a wrong type is an error.
- Each emitted value is an `item`: `u8` tag + value.
  - `0` typed: the value in the command's `Type` (pointers followed), encoded by the
    `go/cmdschema` schema (the same that generated the Dart DTO): bool `u8`; integers and
    `time.Duration` `i64`; float `f64`; string; `[]byte` `kBytes`; types with
    `MarshalText`/`String` and no exported fields (CID, peer ID, multiaddr) string;
    `time.Time` as in `kValue`; slice `i32 n` (`-1` = nil) + items; map `i32 n` (`-1` =
    nil) + pairs (string key, in order); struct: the fields of `cmdschema.Fields` in order
    (embedded ones flattened, `json:"-"` left out); pointer `u8` present + value; `any`
    `kAny`.
  - `1` dynamic: a value of another type (`files rm` emits a string; a command without
    `Type`), in `kAny`. First the host tries the declared type through JSON (what kubo's
    HTTP client does): a value of another type with the same JSON (`diag cmds` emits kubo's
    `ReqLogEntry` and declares go-ipfs-cmds') goes as `0`.
  - `2` bytes: a piece (up to 256 KiB) of an emitted `io.Reader` (`cat`, `files read`);
    `Emit` only returns after reading the whole reader, because the command closes what it
    emitted when `Run` returns.
- The error of `Run` (or a panic of the command) becomes the stream's `error`.
- In Dart every command is a `Stream` (the caller picks `.single`, `.first` or `toList()`):
  `Stream<T>` reads `0` items; `Stream<Uint8List>` reads `2` items; `Stream<Object?>` (a
  command without `Type`) accepts `1` and `2`.

## Notes (what the table above did not pin down; the host does this)

- `kDTO` without a pointer: the host always writes presence `1`; when reading, presence `0`
  gives the struct's zero value. Pointer (`*DTO`, `*config.Config`): presence `0` = nil;
  otherwise the type's own format (which starts with its own `1`): there is no extra byte.
- `kSnap`: a getter with an error that failed writes the type's zero value and then the
  error.
- `kMap`: the host writes `n` (nil = 0, never `-1`); when reading, `-1` = nil.
- `kOpts`: the index is the position in `tinfo.ctors` **including** the constructors that do
  not cross (`okOptCtor`); such an index, or one out of the list, is an error of the call.
- Bytes left over after the last argument are an error (`short arguments` for a short
  read), like missing arguments.
- Mode: a stream requested in mode `0`/`1`, or a call requested in mode `2`, is an error.
- `end` (of a stream and of a sink) comes without data.
- The same object by reference returned twice is the same handle, counted twice: it needs
  two `Free`s. Values (a struct by value, a slice) are a new handle each time; a struct by
  value (`LinkSystem`) is kept through the pointer.
- `dag export` writing to a file returns `i32 0` (empty bytes, not nil).

## Notes on the app side (Dart)

- Every id (calls and sinks) comes from the same channel counter (`ShmChannel.newId`); sinks
  are registered when the request is sent.
- Modes of the hand-written ones: `context` (16–21), Hello, profiles (40–41) and hook 24 are
  synchronous (`0`); `dag` (32–35) and hook 26 asynchronous (`1`); 25 and 42 stream (`2`).
  `Free` goes with mode `0` and id `0`.
- The Hello's `u64` is written as an `i64` (the same 8 bytes).
- A function result: presence `0` (or handle `0`) where Dart expects an object becomes
  `GolangException` ("Go returned nil"); a nil `kBytes` becomes an empty `Uint8List` and a nil
  `kSlice`/`kMap` become empty. In a DTO field and a snapshot getter, nil is `null`; a getter
  with an error gives `null` (the zero value read before the error is discarded).
- `time.Time` comes back as a `DateTime` in UTC (microseconds: the rest of the ns is lost).
- An `io.Reader` inside a DTO (not as a parameter) goes as a plain handle.
- If the request does not even leave (service stopped, handle from a previous service), the
  asynchronous call fails through the `Future`/`Stream` and its sinks close with the same
  error.
