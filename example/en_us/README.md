# Learning p2p_ffi, one question at a time

**English** · [Português](../pt_br/README.md) · [Español](../es/README.md)

A course for Dart developers who have never used IPFS. Each lesson is one
runnable file that answers one question, says what it needs (the earlier
lessons and, technically, which pieces have to exist underneath), runs the
common mistakes on purpose to show the real error, and ends with the next
question it raises. Read them in order, or jump to the question you have.

```bash
dart run tool/build.dart windows   # or linux; once, builds the p2p_host
dart run example/en_us/01_dart_and_go.dart
```

The lessons write with `say()` (in [`lesson.dart`](lesson.dart)): each line goes
to `dart:developer`'s log, named after the lesson file (filterable in DevTools
and in the IDE's debug console), and to the terminal.

## The stack, from the bottom up

Every lesson adds one layer; each layer needs the ones below it.

```
 your app (Dart)
   │  P2pService: the p2p_host process, over shared memory ............ 01
   ▼
 CID: the name of some bytes, computed from them ....................... 02
 datastore → blockstore: where blocks are kept ......................... 03
 exchange: where to get a block that is not here (offline / bitswap) ... 04, 16
 blockservice = blockstore + exchange
 DAGService: blocks as nodes with links; chunker + importer: files ..... 03-04
 CAR: a DAG in one file ................................................ 05-06
 repo + node (kubo): the stack ready, on disk .......................... 07-12
 libp2p host: identity, addresses, connections ......................... 13-14
 routing (DHT): who has a CID, where is a peer ......................... 15
 bitswap over the host + routing: fetching a CID from others ........... 16
```

## The questions

### Part A · content, without a node

| # | Question | Lesson |
|---|---|---|
| 01 | How does Dart talk to Go? Where does the Go code run? | [`01_dart_and_go.dart`](01_dart_and_go.dart) |
| 02 | What is a CID, and why can I trust what comes back for it? | [`02_what_is_a_cid.dart`](02_what_is_a_cid.dart) |
| 03 | How does a file become blocks? Why does the same file get another CID elsewhere? | [`03_file_to_blocks.dart`](03_file_to_blocks.dart) |
| 04 | How do I read it back? What if a block is missing? | [`04_blocks_to_file.dart`](04_blocks_to_file.dart) |
| 05 | How do I carry blocks without a network? (CAR files) | [`05_car_files.dart`](05_car_files.dart) |
| 06 | CARv1 or v2, the index, roots, a subset, a merge? | [`06_car_more.dart`](06_car_more.dart) |

### Part B · the kubo node, on disk (coming next)

| # | Question |
|---|---|
| 07 | What is a repo, and why `init`? |
| 08 | What does the node build for me? |
| 09 | Why do my blocks disappear? (pins and GC) |
| 10 | How do I work with folders that change? (MFS) |
| 11 | How do I give a fixed name to something that changes? (keys and IPNS) |
| 12 | How do I use the `ipfs` commands I already know? |

### Part C · the network (coming)

| # | Question |
|---|---|
| 13 | Who am I on the network? (keys, peer ID, multiaddr, transports) |
| 14 | How do two peers talk? (connect, ping, a protocol of my own, mDNS) |
| 15 | How do I find who has some content? (DHT) |
| 16 | What does boxo need to download a CID? |
| 17 | How do I join the public IPFS network? |
| 18 | How do I send messages in real time? (pubsub) |

### Part D · using the bridge well (coming)

| # | Question |
|---|---|
| 19 | How do I set a deadline and cancel? What errors can come? |
| 20 | When do I need to release memory? (handles) |
| 21 | How does Go call my Dart code? (callbacks) |

## Quick answers

- **"My CID is different from the one another tool gave."** The CID depends on
  how the file was cut and wrapped (chunk size, CIDv0 or v1, raw leaves): lesson
  03, step 4.
- **"Two CIDs look different but name the same thing."** Different text bases,
  or v0 vs v1: compare with `equals()`, lesson 02.
- **"`block was not found locally (offline)`."** The block is not in the
  blockstore and the exchange cannot fetch it: lesson 04.
- **"My CAR has the blocks but not the root."** It was written from
  `allKeysChan()`, which loses the codec: lesson 05, common mistakes.
- **"Nothing shows in the terminal with `dev.log`."** `dart run` does not print
  `dart:developer`'s log; the lessons also print (see `say()` above).
