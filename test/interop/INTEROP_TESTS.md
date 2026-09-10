# Interoperability tests

This directory contains VM tests that prove wire-level interoperability with
an independently installed IPFS implementation. The reusable local process
helper is `lib/local_kubo_harness.dart`. Its P0 consumers cover both
directions: downloading from a known Kubo Bitswap provider
(`local_kubo_bitswap_test.dart`), DHT provider discovery followed by Bitswap
(`local_kubo_dht_bitswap_test.dart`), Kubo downloading a block served by the
Dart node over a direct connection (`local_kubo_serving_test.dart`), and Kubo
finding that Dart node through the DHT before downloading
(`local_kubo_dht_serving_test.dart`). The single P1 consumer is the large
UnixFS proof (`local_kubo_large_unixfs_test.dart`).

## Invariants

- Tests use direct P2P connections (TCP/Noise/yamux/Bitswap; the node has no
  QUIC transport). HTTP gateway reads do not count as proof.
- Every Kubo instance gets a newly-created repository. The harness uses
  `<workspace>/.tmp-validation/kubo-*` when the repository root is available,
  otherwise `Directory.systemTemp`.
- The harness never reads, modifies, or deletes the user's IPFS Desktop/Kubo
  repository. `dispose` stops the child process and deletes only its own
  temporary directory, and tests call it from `finally`.
- API, gateway, and swarm listeners bind only to `127.0.0.1` on dynamically
  allocated ports. The gateway port is configured for Kubo compatibility but
  must not be used by a P2P proof.

## Selecting Kubo

`LocalKuboHarness.findExecutable` checks, in order:

1. the `IPFS_EXECUTABLE` compile-time define (`-DIPFS_EXECUTABLE=...`);
2. the `IPFS_EXECUTABLE` process environment variable;
3. `ipfs.exe`/`ipfs` (Windows) or `ipfs` (Unix) on `PATH`.

If no executable is found, the local test calls `markTestSkipped` with a
clear message. This keeps the normal suite usable on machines without Kubo.

## Lifecycle

`LocalKuboHarness.start()` performs the complete lifecycle:

1. create a private temporary repository;
2. run `ipfs init` with `IPFS_PATH` set to that repository;
3. configure localhost API, gateway, and TCP swarm addresses using free ports;
4. start `ipfs daemon` and drain/capture its stdout and stderr;
5. poll `/api/v0/id` until the API is ready and expose `client`, `peerId`,
   `swarmAddress`, and the selected ports.

Call `await harness.dispose()` (or `close()`) in `finally`. Shutdown first
sends the normal process signal, then uses a bounded forceful fallback, and
only removes the harness-owned repository afterward. Read `stdoutLog` and
`stderrLog` when diagnosing daemon startup or readiness failures.

## Running and extending

From the repository root:

```text
dart test --preset interop test/interop/test/local_kubo_bitswap_test.dart
dart test --preset interop test/interop/test/local_kubo_dht_bitswap_test.dart
dart test --preset interop test/interop/test/local_kubo_serving_test.dart
dart test --preset interop test/interop/test/local_kubo_dht_serving_test.dart
dart test --preset interop
```

The `p0`, `p1` and `helia` tags are skipped by default (see `dart_test.yaml`),
so only `--preset interop` actually executes these tests; a plain `dart test`
reports them as skipped.

The large UnixFS proof accepts `KUBO_LARGE_FIXTURE_SIZES` as a comma-separated
subset of `50,100,200,500` (MiB), or `all`. It generates exact-size
deterministic text files under `.tmp-validation`, downloads every DAG block by
Bitswap, checks library statistics and recursive CIDs, imports the Kubo CAR in
Dart, imports the Dart CAR in Kubo, reconstructs the file byte-for-byte, and
removes every generated file and repository:

```powershell
$env:KUBO_LARGE_FIXTURE_SIZES = '50,100,200,500'
dart test --preset interop -j 1 test/interop/test/local_kubo_large_unixfs_test.dart
```

To select an installation explicitly in PowerShell:

```powershell
$env:IPFS_EXECUTABLE = 'C:\path\to\ipfs.exe'
dart test --preset interop test/interop/test/local_kubo_bitswap_test.dart
```

New protocol tests should reuse the harness and a separate Dart node. Keep
fixtures deterministic, connect by the exposed
`swarmAddress`, validate bytes against the CID, and assert persistence in the
target blockstore or other durable store. Add a focused test tag (`p0`, `p1`,
or a protocol-specific tag) and retain a clear skip when its external
implementation is unavailable.

A proof must state the implementation/version, peer identity or address,
protocol path, exact fixture/CID, validated bytes, persistence result, and
successful cleanup. A mocked transport or gateway response is a unit test,
not an interoperability proof.

The DHT proof retains repository isolation but deliberately leaves Kubo's
default public bootstrappers enabled: `routing provide` requires connected
peers. This changes only the newly created `IPFS_PATH`; it never reads the
user's Kubo/IPFS Desktop repository.
