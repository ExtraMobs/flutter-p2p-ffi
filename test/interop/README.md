# Interop Test Infrastructure

The interop proofs that actually run today are Kubo-only: the five VM tests
under `test/interop/test/`, driven by `lib/local_kubo_harness.dart`. See
[INTEROP_TESTS.md](INTEROP_TESTS.md) for that isolated local-process harness,
its lifecycle invariants, and instructions for adding protocol tests.

> **Status:** the Helia (JavaScript IPFS) harness described below is **not
> present in this repository**. `helia/` contains only `package.json` and
> `package-lock.json`; the scripts they point at (`helia/server.js` and
> `../generate_swarm_key.js`) are not committed, and no test carries the
> `helia` tag today. The steps below document the intended setup, not
> something that runs as written.

## Setup (planned Helia harness)

### 1. Install Node.js dependencies

```bash
cd test/interop/helia
npm install
```

### 2. Generate Swarm Key

The swarm key is used for private network isolation during interop testing. **Do not commit the generated swarm.key file** - it is gitignored for security.

```bash
npm run generate-swarm-key
```

This will generate a new random 95-byte swarm key at `test/interop/swarm.key` using `@libp2p/pnet`'s `generateKey()` function.

### 3. Start Helia Server

```bash
npm start
```

The server will:
- Load the swarm key if available (private network mode)
- Fall back to public network if no swarm key is found
- Listen on port 5001 (HTTP API) and 4001 (libp2p)
- Provide endpoints for Bitswap, CAR, and basic IPFS operations

## Security Note

The swarm key is a pre-shared key (PSK) used to encrypt libp2p connections. Each test environment should generate its own unique key to prevent cross-contamination between test runs. The generated key is never committed to the repository.

## Environment Variables

- `PORT`: HTTP API port (default: 5001)
- `LIBP2P_PORT`: libp2p listen port (default: 4001)
- `BOOTSTRAP_PEERS`: Comma-separated list of bootstrap peers (optional)
