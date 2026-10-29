# p2p_ffi

Peer-to-peer networking from Go (kubo v0.43.1, boxo, go-libp2p) used from Dart without HTTP.
The Go code runs in the `p2p_host` executable, in another process; the app talks to it through shared memory (the `p2p_shm`,
in C) with a binary protocol (`WIRE.md`). The Dart API is Go's own, generated from
`go/gen/roots.txt`, all of it behind one import, `lib/p2p_ffi.dart`: a package's functions,
constants and variables hang from the constant `go`, along the package's path after the host
of its URL (`github.com/ipfs/boxo/mfs` → `go.ipfs.boxo.mfs.newRoot`, `github.com/ipfs/go-cid`
→ `go.ipfs.cid.decode`), and its types are top-level classes named after that path without
the author (`BoxoMfsRoot`, `cid.Cid` → `Cid`). The code of each package is one library under `lib/go/`, at the same
path (`lib/go/ipfs/boxo/mfs.dart`). Targets: VM/AOT on Windows, linux and Android (not JS/Wasm).

`README.md` is the usage guide; `example/README.md` opens the course (one lesson per
question) in `example/en_us/`, `example/pt_br/` and `example/es/`; `API.md`
(generated) lists every exposed symbol and the adaptation rules; `TODO.md` keeps what was
done in each version and what is pending.

## Layout

| Path | What it is |
|---|---|
| `lib/` | the Dart package: the generated code (`lib/go/`, one library per Go package; `lib/src/go.dart`, the namespace tree (`go.ipfs.boxo`, `go.ipfs.cid`...) that exports them) and the runtime in `lib/src/` (`runtime.dart` and its parts, `service.dart`, `shm.dart`), exported only by `lib/p2p_ffi.dart` |
| `go/` | the `p2p_host` (`host*.go`, `wire.go`, `callback.go`, `retained.go`, `deadlock.go`, `logpump.go`, the hand ports `manual_*.go`) and the generator (`go/gen`, with `roots.txt`; the Dart paths in `go/gen/namespaces.go`) |
| `shm/` | the `p2p_shm` in C (rings, the bell, the thread that wakes Dart) |
| `tool/` | `build.dart` (generates and builds per platform, with the upstream patches) and the benchmarks (`bench*.dart`) |
| `test/` | the Dart suite (needs the build) |
| `example/` | the course in `example/en_us/`, `example/pt_br/` and `example/es/` (in each: the lessons `NN_<topic>.dart`, the roadmap `README.md`, the shared helpers `lesson.dart`); `example/README.md` picks the language; `example/android_app/` is the Flutter validation app |
| `flutter/` | the companion plugin `p2p_ffi_flutter` (Android background) |

## Commands

```bash
dart run tool/build.dart [windows|linux|android]   # runs the generator and builds into native/ (not in git)
cd go && go vet ./... && go test ./... && go run ./gen -check   # the host and the generator
dart analyze lib test tool example/en_us example/pt_br example/es
dart test                                          # the whole suite (needs the platform build)
```

- Go 1.26.5 (`GOTOOLCHAIN=auto` downloads it). A C compiler only for the `p2p_shm`: mingw-w64
  on Windows, gcc on linux, the NDK for Android.
- To expose more of Go: a line `package.*` in `go/gen/roots.txt` (every exported symbol;
  what the generator cannot bridge is skipped, with the reason in API.md) and the build;
  `go/gen/ignore_roots.txt` drops what must not cross (patterns, with the reason). The
  library path comes from the package's module (`go list -m all`), no table to edit.
- linux through WSL: WSL and Windows overwrite each other's `.dart_tool/package_config.json`;
  run `dart pub get` on the side in use before analyzing or testing.
- Android: `dart run tool/build.dart android`, then in `example/android_app/`
  `flutter test integration_test/ipfs_test.dart -d <device>`. The rest (emulator, real
  device, wireless debugging) is in `TODO.md`.

## Conventions

- **Namespaces (owner's decisions, 2026-10-28, option a, and 2026-10-29):** one import,
  `package:p2p_ffi/p2p_ffi.dart`. One top-level constant, `go`, then each segment of the
  package's path after the host of its URL a `.`, the author first and repeated when the
  repository has its name (`go.ipfs.boxo`, `go.ipfs.cid`, `go.libp2p.libp2p.core.peer`,
  `go.ipld.ipldPrime.traversal.selector.builder`, `golang.org/x/crypto` → `go.x.crypto`, a
  host of its own without an author, the standard library beside the authors: `go.context`),
  so two modules with the same name do not meet; lowerCamelCase as Dart names constants and
  getters. A package's functions, constants and variables are members
  of its namespace class (`go.ipfs.boxo.mfs` is a `GoIpfsBoxoMfs`), added by its library as an
  extension (`GoIpfsBoxoMfsApi`); Dart has no nested types, so a type is a top-level class named
  after its package's path without the author, minus the words the Go name already starts with
  (`BoxoMfsRoot`, `Libp2pCorePeerId`, `cid.Cid` → `Cid`). Every name is unique: the
  generator refuses two equal names, a member that hides a sub-namespace, and an `export`
  in a public library outside `lib/p2p_ffi.dart`. A hand-written library of a Go package
  adds its members the same way (`extension GoContextApi on GoContext`) and gets the
  generated part of that package as `<name>.g.dart`.

- **`dart format` before every commit** for every hand-written `.dart` (generated code comes
  out formatted): `dart format --output=none --set-exit-if-changed <files>`.
- **English only for names and documentation:** file names, identifiers, comments, example
  output and docs are written in English (the owner's rule since 2026-10-16). Older docs and
  tests still in Portuguese stay until the owner decides on translating them. The one
  exception is the course's translations (below).
- **The lessons, in three languages:** each lesson exists in `example/en_us/` (English),
  `example/pt_br/` (Brazilian Portuguese) and `example/es/` (Spanish) (the owner's
  decision, 2026-10-28), with
  the same file name, the same code and the same identifiers; only comments and output are
  translated (`lesson.dart` and `README.md` too). A change to a lesson goes to all three in
  the same commit, and all three are run before it. Each lesson answers one question: its
  header has the question, the answer, what it needs (the earlier lessons and the layers
  underneath) and the next question; the common mistakes run on purpose through `mistake()`
  and `silentlyWrong()`, which stop the lesson if the behavior changes. Lessons write with
  `say()` (`dart:developer`'s log plus the terminal, which `dart run` needs), not `print`.
- **Expose what exists in Go,** generated, never redone by hand in Dart. Hand ports only for
  the body of kubo commands (`ipfs dag export/import/put/get`). A performance knob of a call
  becomes an optional argument of it (e.g. `batchSize`), not a global setting.
- **No new dependency** (Go or Dart) without the owner's explicit approval.
- **No personal data in git** (IPs, device serial numbers, machine paths); the repository is
  public.
- **Delivery by stage:** commit what is ready before starting the next stage; at the end,
  the version in both `pubspec.yaml`, a "Done" entry in `TODO.md`, the tag
  `p2p_ffi-vX.Y.Z`, a direct push to `main` (remote `github`), then stop for the owner's
  review.
- **Go behavior checked against Go itself:** when a result is surprising, reproduce it with
  a `go run` (oracle) before concluding the bridge is wrong.

## Earlier attempts (to consult for other approaches)

The repository already tried other ways to get IPFS into Dart. Look at them before
reinventing something, or when a different approach makes sense:

- **branch `transpilador`** (tag `transpilador-final`): the Go→Dart transpiler by AST (`g2d`,
  with `goast`, `dartast` and the stdlib shims in `golib_dart`). It reached 192 of the 1112
  packages of kubo's graph. It has its own `AGENTS.md`, the decisions D1–D12 (reflection,
  suspending I/O, networking, `goto`...), the backlog in `TODO/` and the docs in `docs/`.
- **branch `archive`:** the hand port `dart IPFS`, with Bitswap and DHT interoperating with
  kubo (including multiaddr DNS).
- **branches `claude/*`:** interrupted transpiler work that was never merged.
