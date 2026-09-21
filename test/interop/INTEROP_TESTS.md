# Interoperability tests

VM tests that prove wire-level interoperability against a separately installed
Kubo daemon. Every test drives `lib/local_kubo_harness.dart`, which owns an
isolated Kubo process, and a fresh Dart node.

There is no Helia harness in this repository. `helia/` holds only
`package.json`/`package-lock.json`, the scripts they reference are not
committed, and no test carries the `helia` tag.

## Tests

All under `test/interop/test/`. Each file's doc comment states what it proves.

| Test | Tag |
| --- | --- |
| `local_kubo_bitswap_test.dart` | `p0` |
| `local_kubo_dht_bitswap_test.dart` | `p0` |
| `local_kubo_serving_test.dart` | `p0` |
| `local_kubo_dht_serving_test.dart` | `p0` |
| `local_kubo_network_participation_test.dart` | `p0` |
| `local_kubo_tls_handshake_test.dart` | `p0` |
| `local_kubo_quic_test.dart` | `p0` |
| `local_kubo_webtransport_quic_test.dart` | `p0` |
| `local_kubo_transport_matrix_test.dart` | `p0` |
| `local_kubo_large_unixfs_test.dart` | `p1` |

`local_kubo_transport_matrix_test.dart` (Marco G.7) is **expected to fail**
today: it iterates Kubo's effective `Addresses.Swarm` and requires a block over
every one of them, and `/webrtc-direct` has no DTLS port yet. Making it pass
means porting DTLS, not weakening the assertion.

## Invariants

- Proof means a direct P2P connection (transport → security → muxer → Bitswap)
  with the bytes validated against the CID. An HTTP gateway read, a mocked
  transport or a `canDial()` predicate is not a proof.
- Every Kubo instance gets a newly-created repository under
  `<workspace>/.tmp-validation/kubo-*`, or `Directory.systemTemp` when the
  repository root is unavailable. The harness never reads, modifies or deletes
  the user's IPFS Desktop/Kubo repository.
- `dispose` stops the child process and deletes only the harness-owned
  directory; tests call it from `finally`.
- API, gateway and swarm listeners bind to `127.0.0.1` on dynamically allocated
  ports.
- The DHT proofs keep repository isolation but leave Kubo's default public
  bootstrappers enabled, because `routing provide` requires connected peers.

## Selecting Kubo

`LocalKuboHarness.findExecutable` checks, in order, the `IPFS_EXECUTABLE`
compile-time define (`-DIPFS_EXECUTABLE=...`), the `IPFS_EXECUTABLE`
environment variable, then `ipfs` on `PATH`. With no executable found the test
calls `markTestSkipped`, so the normal suite stays usable without Kubo.

## Lifecycle

`LocalKuboHarness.start()` creates the private temporary repository, runs
`ipfs init` with `IPFS_PATH` pointing at it, configures localhost API, gateway
and swarm addresses on free ports, starts `ipfs daemon` while draining its
output, and polls `/api/v0/id` until ready, exposing `client`, `peerId`,
`swarmAddress` and the selected ports. Read `stdoutLog`/`stderrLog` when
diagnosing startup failures.

## Running

The `p0`, `p1` and `helia` tags are skipped by default (`dart_test.yaml`), so a
plain `dart test` reports these as skipped. From the repository root:

```text
dart test --preset interop
dart test --preset interop test/interop/test/local_kubo_bitswap_test.dart
```

`local_kubo_large_unixfs_test.dart` accepts `KUBO_LARGE_FIXTURE_SIZES` as a
comma-separated subset of `50,100,200,500` (MiB) or `all`. It generates
exact-size deterministic files under `.tmp-validation`, downloads every DAG
block by Bitswap, cross-imports CARs in both directions, reconstructs the file
byte-for-byte and removes everything it created:

```powershell
$env:KUBO_LARGE_FIXTURE_SIZES = '50,100,200,500'
dart test --preset interop -j 1 test/interop/test/local_kubo_large_unixfs_test.dart
```

## Adding a test

Reuse the harness and a separate Dart node, keep fixtures deterministic,
connect by the exposed `swarmAddress`, validate bytes against the CID and
assert persistence in the target blockstore. Tag it `p0`, `p1` or with a
protocol-specific tag, and keep a clear skip when the external implementation
is unavailable. State in the test what it proves: implementation and version,
peer identity or address, protocol path, fixture/CID, and cleanup.
