# Memory & Handle Lifecycle (`example/memory/`)

In `ipfs_ffi`, Kubo and its Go libraries (`boxo`, `go-car`, `go-ipld-prime`, `go`) run in a separate process (`ipfs_host`), communicating with Dart over shared memory (`ipfs_shm`).

Values that cross by value — primitives, `Uint8List`, `String`, `Cid`, `Path`, `PeerId`, `Multiaddr`, `Config` and generated DTO structs (`BlockStat`, `Stats`, `Link`, ...) — live entirely in Dart once decoded and need no special lifecycle care.

Objects that stay in Go — `IpfsNode`, `CoreApi`, `car.Reader`, `car.BlockReader`, `bytes.Buffer`, `os.File`, `mfs.Directory`, `ipld_format.Node`, etc. — are represented in Dart as subclasses of [`GoHandle`](../../lib/src/runtime.dart).

---

## 1. How `GoHandle` Works Under the Hood

1. **In Go (`go/wire.go`):** When a Go function returns a pointer, interface, map, slice or channel handle, `ipfs_host` stores the Go value in its global handle table (`handles.m[id] = &hentry{v: v, refs: 1}`). As long as `id` is in `handles.m`, the Go garbage collector sees `v` as a live root and **cannot free it**.
2. **In Dart (`lib/src/runtime.dart`):** Dart wraps that 64-bit integer ID (`$h`) and the service epoch (`$e`) inside a [`GoHandle`](../../lib/src/runtime.dart) instance and attaches it to a Dart [`Finalizer`](https://api.dart.dev/stable/dart-core/Finalizer-class.html).
3. **The Asymmetric GC Problem ("Floating Garbage"):**
   - To the Dart VM, every `GoHandle` is just two `int` fields (~48 bytes on the Dart heap), whether the underlying Go object holds 64 bytes or a **64 MiB buffer**.
   - Allocating hundreds of `GoHandle`s in a loop adds only a few kilobytes to the Dart heap, so the Dart GC feels **no memory pressure** and does not run.
   - Because the Dart `Finalizer` only runs when the Dart GC collects the wrapper object, `ipfs_host` keeps all of those multi-megabyte Go objects alive in `handles.m`, causing Go's RSS memory to grow to gigabytes (or triggering the Android Low Memory Killer).

---

## 2. `close()` vs `release()`

Many Go types have a `Close()` method (`io.Closer`, `car.Reader.Close()`, `os.File.Close()`, `IpfsNode.Close()`). It is important not to confuse the two:

| Operation | What it does in Go | Does it free the entry in `handles.m`? |
|---|---|---|
| `r.close()` | Calls Go's `Close()` method (flushes buffers, unmaps files, closes OS file descriptors or network sockets). | **No.** The Go struct itself remains in `handles.m` until the handle is released. |
| `r.release()` | Detaches the Dart `Finalizer`, marks `r.isReleased = true`, and immediately sends `Free` (`_fnFree`) to remove the handle from `handles.m`. | **Yes.** Go's GC can now collect the Go struct and its memory buffers. (Does **not** call `Close()`!) |

**Rule of thumb:** If a handle has `.close()`, call `r.close()` to release OS resources (files/sockets), and use `.use(...)` / `withGoScope(...)` / `.release()` to immediately free the handle entry in `ipfs_host`.

---

## 3. When to Use Each Mechanism

| Mechanism | When to use it | Example |
|---|---|---|
| **Automatic `Finalizer`** (do nothing) | Long-lived singletons (`IpfsNode`, `CoreApi`, `Context`) or occasional one-off calls with small objects. | `final api = coreapi.newCoreApi(node);` |
| **`handle.use((h) => ...)`** | Single handle that holds a large buffer, file, or CAR reader for one block of work (sync or `async`). | `bytes.Buffer(bytes).use((buf) => ...)` |
| **`withGoScope((s) => ...)`** | Loops or multi-step pipelines that create **2 or more handles** per iteration. Releases all registered handles in reverse order in a **single shared-memory batch**. | `withGoScope((s) { final f = s.manage(...); final br = s.manage(...); })` |
| **`handle.release()`** | When lifetime cannot be expressed as a lexical block (e.g., a handle stored in a state field and replaced later). | `oldHandle?.release();` |

---

## 4. Cautions to Keep in Mind

1. **No use-after-free:** Once `release()` is called (directly or when `.use()` / `withGoScope()` exits), `handle.isReleased` becomes `true`. Passing that handle to any Go call throws an immediate `GolangException('handle already released: cannot use a released handle')` on the Dart side.
2. **Do not let a `s.manage(...)` handle escape `withGoScope`:** Return a Dart value (`Uint8List`, `String`, `Cid`, DTO, `int`) from `withGoScope`, not a handle registered in `s`.
3. **Always `await` async work inside `.use()` or `withGoScope()`:** Both `.use()` and `withGoScope()` automatically detect when the callback returns a `Future` and wait for it to complete before releasing. However, if you start an async Go call inside a synchronous block *without* returning or `await`ing its `Future`, the scope will close while the call is still running.
4. **Pointer deduplication (`refs` count):** If Go returns the exact same pointer twice (for example, calling `node.blockstore()` twice), `ipfs_host` returns the same handle ID (`$h`) and increments `refs` in `handles.m`. Each Dart `GoHandle` wrapper decrements `refs` once when released; the Go object leaves `handles.m` when the last wrapper is released.

---

## 5. Runnable Examples in This Folder

Run any example from the repository root (after `dart run tool/build.dart`):

| File | Topic |
|---|---|
| [`01_how_handles_work.dart`](01_how_handles_work.dart) | Anatomy of `GoHandle`, pointer deduplication (`refs`), `close()` vs `release()`, and live `ipfs_host` memory comparison (`Finalizer` vs deterministic release). |
| [`02_single_handle_use.dart`](02_single_handle_use.dart) | Using `.use()` and `.release()` for single handles across synchronous calls, exceptions, and `async`/`await` `Future`s. |
| [`03_batch_loops_with_scope.dart`](03_batch_loops_with_scope.dart) | Using `withGoScope` and `GoScope` to keep memory flat when iterating over files, buffers, and CAR blocks in a loop. |
| [`04_pitfalls_and_mistakes.dart`](04_pitfalls_and_mistakes.dart) | Intentional mistakes (use-after-free, escaping scoped handles, unawaited futures, forgetting `close()`) and how to fix each one. |
