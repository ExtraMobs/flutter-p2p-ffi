# Everyday CAR operations

Runnable examples in [`example/car/`](example/car), one per everyday operation with CAR
files. Each operation has two files:

- `NN_operation.dart`: **the right way**.
  - *Kubo (high level)* section: the node-level function, when kubo has one (the same thing
    as the `ipfs` CLI command).
  - *Low level* section: the go-car / boxo / go-ipld-prime pieces kubo uses inside, often
    without a node at all.
  - Every Go call is shown next to it as a `Go:` comment, so the Go documentation applies as
    is.
- `NN_operation_mistakes.dart`: **what not to do**. Each mistake is actually made, and the
  example prints what was done, the error Go returned, why it is wrong and what to do
  instead. Two helpers in [`sample.dart`](example/car/sample.dart) mark them:
  - `mustFail`: the mistake fails. If it ever stops failing, the example stops too, because
    the documented behavior changed.
  - `silentlyWrong`: nothing fails, but the result is wrong; it prints the wrong result next
    to the right one. These are the dangerous ones.

Every example starts from [`sample.dart`](example/car/sample.dart):
- the service, a temporary repo and an offline node;
- a sample folder: `hello.txt`, `data.bin` (600 000 bytes in three 256 KiB chunks) and
  `sub/note.md`;
- the CARv1 of that folder.

## Running

```bash
dart run tool/build.dart windows      # or linux; builds native/ (the ipfs_host and the ipfs_shm)
dart run example/car/01_inspect.dart
dart run example/car/01_inspect_mistakes.dart
```

## Which example do I need?

| I want to... | Example |
|---|---|
| see what a CAR holds without importing it | [01 inspect](#01-inspect) |
| make sure a CAR I received is not corrupted | [02 verify](#02-verify) |
| go through the blocks one by one | [03 list blocks](#03-list-blocks) |
| get one block out of a CAR by CID | [04 read a block](#04-read-a-block) |
| write my own data as a CAR | [05 create from scratch](#05-create-from-scratch) |
| turn a folder into a CAR | [06 create from files](#06-create-from-files) |
| turn a CAR back into files | [07 extract files](#07-extract-files) |
| put a CAR's content into my node | [08 import into a node](#08-import-into-a-node) |
| save what my node has as a CAR | [09 export from a node](#09-export-from-a-node) |
| convert between CARv1 and CARv2 | [10 convert v1/v2](#10-convert-v1v2) |
| find blocks fast in a large CAR | [11 index](#11-index) |
| change the root of a CAR | [12 replace roots](#12-replace-roots) |
| send one file, or a byte range, out of a large DAG | [13 select a subset](#13-select-a-subset) |
| put several CARs into one | [14 merge](#14-merge) |

## The operations

### 01 inspect

[`01_inspect.dart`](example/car/01_inspect.dart) ·
[`01_inspect_mistakes.dart`](example/car/01_inspect_mistakes.dart)

- **What it shows:** the version, the roots, the number of blocks by codec and hash, the
  block sizes, whether the roots are in the CAR, and the CARv2 header.
- **Kubo:** none (kubo only reads a CAR by importing it).
- **Low level:** `car.openReader`, `inspect(false)`, `car.readVersion`.
- **Mistakes:**
  - opening a file that is not a CAR;
  - on Windows, overwriting a CAR while its `Reader` is open (the file is mapped).

### 02 verify

[`02_verify.dart`](example/car/02_verify.dart) ·
[`02_verify_mistakes.dart`](example/car/02_verify_mistakes.dart)

- **What it shows:** that every block matches its CID.
- **Kubo:** `dagImportFiles` checks while importing and rejects a corrupted CAR.
- **Low level:** `inspect(true)`; the `BlockReader` checks too.
- **Mistake (silent):** trusting `inspect(false)`: it counts the blocks of a corrupted CAR
  without complaint.

### 03 list blocks

[`03_list_blocks.dart`](example/car/03_list_blocks.dart) ·
[`03_list_blocks_mistakes.dart`](example/car/03_list_blocks_mistakes.dart)

- **What it shows:** reading a CAR block by block from a file or from bytes, only the
  metadata (`skipNext`), or only the CIDs.
- **Kubo:** none.
- **Low level:** `car.BlockReader` (`next`, `skipNext`, the end is `IpfsEof`) and
  `openReadOnly(...).allKeysChan` (a `Stream`).
- **Mistake (silent):** treating any `IpfsException` as the end: a truncated CAR
  (`IpfsUnexpectedEof`) then looks complete with fewer blocks.

### 04 read a block

[`04_read_block.dart`](example/car/04_read_block.dart) ·
[`04_read_block_mistakes.dart`](example/car/04_read_block_mistakes.dart)

- **What it shows:** `has`, `getSize` and `get` of one block by CID, through the index.
- **Kubo:** `dagImportFiles` + `api.block().get`.
- **Low level:** `car.openReadOnly`.
- **Mistakes:**
  - `get` of a CID that is not in the CAR (`IpfsNotFound`);
  - (silent) using the default `has` to know whether the CAR holds *exactly* a CID: the
    index matches multihashes, so a CIDv0 of the same content "exists" in a CAR that only
    has the CIDv1 (`car.useWholeCids(true)` fixes it).

### 05 create from scratch

[`05_create_from_scratch.dart`](example/car/05_create_from_scratch.dart) ·
[`05_create_from_scratch_mistakes.dart`](example/car/05_create_from_scratch_mistakes.dart)

- **What it shows:** writing your own blocks into a new CAR, with each CID computed from the
  bytes.
- **Kubo:** `dagPut` of linked IPLD objects + `dagExportFile`.
- **Low level:** `mf.newPrefixV1(...).sum(bytes)`, `car.openReadWrite`, `put`/`putMany`,
  `finalize`.
- **Mistakes:**
  - (silent) a `Block` whose CID does not match its bytes: `put` accepts it, and only a
    later `inspect(true)` finds it;
  - forgetting `finalize` (the file has no valid header);
  - using the `ReadWrite` after `finalize`.

### 06 create from files

[`06_create_from_files.dart`](example/car/06_create_from_files.dart) ·
[`06_create_from_files_mistakes.dart`](example/car/06_create_from_files_mistakes.dart)

- **What it shows:** a folder on disk as a UnixFS DAG in a CAR (what the `ipfs-car` tool
  does).
- **Kubo:** `api.unixfs().add` + `dagExportFile`.
- **Low level, without a node:**
  - the CAR's own `ReadWrite` becomes an offline block service and DAG service
    (`blockservice.new$`, `boxo.exchange`, `boxo.newDagService`);
  - `boxo.buildDagFromReader` with `boxo.newSizeSplitter` chunks each file, and a
    `boxo.Directory` ties them together;
  - the root is only known at the end, so the CAR opens with a placeholder root of the same
    size, replaced after `finalize`.
- **Both ways give the same root** with the same parameters (CIDv0, 256 KiB chunks).
- **Mistake:** a placeholder root of another size (CIDv1 vs CIDv0): `replaceRootsInFile`
  refuses it.

### 07 extract files

[`07_extract_files.dart`](example/car/07_extract_files.dart) ·
[`07_extract_files_mistakes.dart`](example/car/07_extract_files_mistakes.dart)

- **What it shows:** the files and folders of a CAR written back to disk, byte for byte.
- **Kubo:** `dagImportFiles` + `api.unixfs().get` + `boxo.writeTo`.
- **Low level, without a node:** `car.openReadOnly` → offline block service →
  `boxo.newDagService` → `boxo.newUnixfsFile` → `boxo.writeTo`.
- **Mistake:** extracting a partial CAR (`IpfsNotFound` for the first missing block).

### 08 import into a node

[`08_import_into_node.dart`](example/car/08_import_into_node.dart) ·
[`08_import_into_node_mistakes.dart`](example/car/08_import_into_node_mistakes.dart)

- **What it shows:** every block of a CAR stored in the node, and its root pinned.
- **Kubo:** `dagImportFiles(pinRoots: true)` (`ipfs dag import --pin-roots`).
- **Low level:** `car.BlockReader` → `node.blockstore.put` (boxo), then
  `api.pin().add`.
- **Mistakes:**
  - a block above 2 MiB without `allowBigBlock`;
  - (silent) assuming `pinRoots` pinned everything: a root with missing blocks is not
    pinned, and the reason only comes in `roots[i].pinErrorMsg`.

### 09 export from a node

[`09_export_from_node.dart`](example/car/09_export_from_node.dart) ·
[`09_export_from_node_mistakes.dart`](example/car/09_export_from_node_mistakes.dart)

- **What it shows:** a whole DAG of the node written as a CAR, three ways with the same
  blocks.
- **Kubo:** `dagExportFile` (`ipfs dag export`).
- **Low level:**
  - boxo's gateway backend: `boxo.BlocksBackend(node.blocks).getCar` with
    `dagScopeAll`, copied to a file with `go.copy`; it fetches from the network if needed;
  - a selector over the node's blockstore (`ipld.Adapter` + `car.traverseToFile`), local
    blocks only.
- **Mistakes:**
  - exporting a DAG the offline node does not fully have;
  - (silent) `localOnly` to "make it work": the CAR comes out partial without a word.

### 10 convert v1/v2

[`10_convert_v1_v2.dart`](example/car/10_convert_v1_v2.dart) ·
[`10_convert_v1_v2_mistakes.dart`](example/car/10_convert_v1_v2_mistakes.dart)

- **What it shows:** CARv1 → CARv2 (with an index) and back, byte for byte, and the same
  in memory (bytes → `go.Buffer`).
- **Kubo:** none.
- **Low level:** `car.wrapV1File`, `car.extractV1File`, `car.wrapV1`.
- **Mistakes:**
  - extracting the v1 of a v1;
  - wrapping a v2 again: accepted, but the file is broken, and the error only shows up when
    reading it.

### 11 index

[`11_index.dart`](example/car/11_index.dart) ·
[`11_index_mistakes.dart`](example/car/11_index_mistakes.dart)

- **What it shows:**
  - building the index of a CARv1 and looking up where a block is;
  - saving it as a `.idx` file and loading it back;
  - going through every entry with a callback (`forEach`);
  - the index a CARv2 already carries.
- **Kubo:** none.
- **Low level:** `car.generateIndexFromFile`, `car.getFirst`, `car.writeTo`/`car.readFrom`,
  `asIterableIndex()!.forEach`.
- **Mistakes:**
  - looking up a CID that is not indexed (`IpfsNotFound`);
  - (silent) reading a CAR with another CAR's index: its blocks look absent.
- **Known upstream bug:** `car.attachIndex` always fails in go-car v2.17.0. It opens the file
  with `O_APPEND` and writes with `WriteAt`, which Go refuses. Use `wrapV1File` instead.

### 12 replace roots

[`12_replace_roots.dart`](example/car/12_replace_roots.dart) ·
[`12_replace_roots_mistakes.dart`](example/car/12_replace_roots_mistakes.dart)

- **What it shows:** changing the roots in the header in place, here to a sub-folder the CAR
  already contains.
- **Kubo:** none.
- **Low level:** `car.replaceRootsInFile`.
- **Mistakes:**
  - a root of another size;
  - (silent) a root that is not in the CAR: go-car accepts it, and `rootsPresent` turns
    false.

### 13 select a subset

[`13_select_subset.dart`](example/car/13_select_subset.dart) ·
[`13_select_subset_mistakes.dart`](example/car/13_select_subset_mistakes.dart)

- **What it shows:**
  - one file with the proof of its path (`dagScopeEntity`);
  - the first 100 bytes of a file (`DagByteRange`);
  - a single block (`dagScopeBlock`);
  - a file selected by name from a CAR on disk.
- **Kubo:** none (`dagExport` is always the whole DAG).
- **Low level:**
  - boxo's gateway backend (`getCar`), from the node and fetching from the network if
    needed;
  - an IPLD selector with the UnixFS layer (`ipld.addUnixFsReificationToLinkSystem`,
    `ipld.unixFsPathSelector`) and the dag-pb prototype chooser
    (`car.withTraversalPrototypeChooser(ipld.addSupportToChooser(boxo.defaultPrototypeChooser))`).
- **Mistakes:**
  - (silent) the UnixFS selector without the dag-pb chooser: the walk stops at the root;
  - `exploreFields(batchSize: 1024)`: `panic: misuse`, because the callback's object is only
    valid during the call;
  - `getCar` of an `/ipns/` path (the gateway backend wants `/ipfs/`).

### 14 merge

[`14_merge.dart`](example/car/14_merge.dart) ·
[`14_merge_mistakes.dart`](example/car/14_merge_mistakes.dart)

- **What it shows:** one CAR with the blocks and the roots of two (duplicates stored once).
- **Kubo:** `dagImportFiles` of both into a node (kubo exports one root per CAR).
- **Low level:** `car.openReadWrite` with all the roots, fed by the `BlockReader` of each
  CAR.
- **Mistake:** using one of the source CARs as the destination (a CARv1 cannot be resumed).
