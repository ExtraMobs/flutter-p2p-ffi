# ipfs_ffi

Kubo (IPFS in Go, v0.43.1) used from Dart without HTTP. Kubo runs in the `ipfs_host`
executable, in another process; the app talks to it through shared memory (the `ipfs_shm`,
in C) with a binary protocol (`WIRE.md`). The Dart API is Go's own, generated from
`go/gen/roots.txt` and organized in namespaces by Go module (`kubo`, `boxo`, `car`, `ipld`,
`multiformats`, `libp2p`, `go`). Targets: VM/AOT on Windows, linux and Android (not JS/Wasm).

`README.md` is the usage guide; `DOCS.md` indexes the CAR examples by operation; `API.md`
(generated) lists every exposed symbol and the adaptation rules; `TODO.md` keeps what was
done in each version and what is pending.

## Layout

| Path | What it is |
|---|---|
| `lib/` | the Dart package: the generated code (one library per Go package, in the namespaces) and the runtime in `lib/src/` (`runtime.dart` and its parts, `shm.dart`) |
| `go/` | the `ipfs_host` (`host*.go`, `wire.go`, `callback.go`, `deadlock.go`, the hand ports `manual_*.go`) and the generator (`go/gen`, with `roots.txt` and the namespace table) |
| `shm/` | the `ipfs_shm` in C (rings, the bell, the thread that wakes Dart) |
| `tool/` | `build.dart` (generates and builds per platform, with the upstream patches) and the benchmarks (`bench*.dart`) |
| `test/` | the Dart suite (needs the build) |
| `example/` | numbered examples; `example/car/` has the CAR operations (see `DOCS.md`); `example/memory/` has the handle memory management guide and examples; `example/android_app/` is the Flutter validation app |
| `flutter/` | the companion plugin `ipfs_ffi_flutter` (Android background) |

## Commands

```bash
dart run tool/build.dart [windows|linux|android]   # runs the generator and builds into native/ (not in git)
cd go && go vet ./... && go test ./... && go run ./gen -check   # the host and the generator
dart analyze lib test tool example/*.dart example/car/*.dart example/memory/*.dart
dart test                                          # the whole suite (needs the platform build)
```

- Go 1.26.5 (`GOTOOLCHAIN=auto` downloads it). A C compiler only for the `ipfs_shm`: mingw-w64
  on Windows, gcc on linux, the NDK for Android.
- To expose more of Go: one line in `go/gen/roots.txt` and the build. A new module needs a
  line in `go/gen/namespaces.go`.
- linux through WSL: WSL and Windows overwrite each other's `.dart_tool/package_config.json`;
  run `dart pub get` on the side in use before analyzing or testing.
- Android: `dart run tool/build.dart android`, then in `example/android_app/`
  `flutter test integration_test/ipfs_test.dart -d <device>`. The rest (emulator, real
  device, wireless debugging) is in `TODO.md`.

## Conventions

- **`dart format` before every commit** for every hand-written `.dart` (generated code comes
  out formatted): `dart format --output=none --set-exit-if-changed <files>`.
- **English only for names and documentation:** file names, identifiers, comments, example
  output and docs are written in English (the owner's rule since 2026-10-16). Older docs and
  tests still in Portuguese stay until the owner decides on translating them.
- **Expose what exists in Go,** generated, never redone by hand in Dart. Hand ports only for
  the body of kubo commands (`ipfs dag export/import/put/get`). A performance knob of a call
  becomes an optional argument of it (e.g. `batchSize`), not a global setting.
- **No new dependency** (Go or Dart) without the owner's explicit approval.
- **No personal data in git** (IPs, device serial numbers, machine paths); the repository is
  public.
- **Delivery by stage:** commit what is ready before starting the next stage; at the end,
  the version in both `pubspec.yaml`, a "Done" entry in `TODO.md`, the tag
  `ipfs_ffi-vX.Y.Z`, a direct push to `main` (remote `github`), then stop for the owner's
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
