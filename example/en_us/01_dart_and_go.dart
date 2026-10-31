// Lesson 01 · How does Dart talk to Go?
//
// Question: p2p_ffi gives "Go's API in Dart". Where does the Go code run, and
// what happens when I call one of its functions?
//
// Answer: Go runs in another process, the p2p_host (built by
// `dart run tool/build.dart`). P2pService.start() launches it and connects
// to it through shared memory. Each Go function is a Dart function that sends
// a message to that process and waits for the answer. What comes back is one
// of three things:
//   - a value (a CID, a string, bytes, a struct of data): copied into Dart,
//     it lives on without Go;
//   - a handle (a datastore, a node, an open file): the object stays in Go,
//     Dart holds a number that points to it;
//   - an error: Go's `error` is thrown as a GolangException, or as the
//     subclass of that Go error when it has one (`CidErrInvalidCid` for
//     `cid.ErrInvalidCid`...).
// Names: a Go package's functions, constants and variables hang from a constant
// per module, along the package's path (`cid.Decode` → `go.ipfs.cid.decode`,
// go-datastore's `sync.MutexWrap` → `go.ipfs.datastore.sync.mutexWrap`); its types
// are classes named after that path (`cid.Cid` → `Cid`, `blockstore.Blockstore`
// → `BoxoBlockstore`). One import brings them all:
// `package:p2p_ffi/p2p_ffi.dart`.
// A Go function that takes a `context.Context` may block (disk, network), so
// in Dart it returns a Future; the others answer right away.
//
// Needs: only the build. No repo, no network.
//
//   dart run example/en_us/01_dart_and_go.dart
//
// Next question: "What is that CID I just saw?" → lesson 02.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  // 1. Before the service starts there is no Go to call.
  await mistake('calling Go before P2pService.start()',
      why: 'the Go code lives in the p2p_host process, which is not running',
      instead: 'await P2pService.start() once, at the start of the program',
      action: () => go.ipfs.cid.decode('bafkqaaa'));

  await P2pService.start();
  say('this Dart process: pid $pid; the Go process (p2p_host): '
      'pid ${P2pService.hostPid}');

  // 2. A function without a context answers right away, and its result is a
  //    value. Go:  c, err := cid.Decode("bafkqaaa")
  final c = go.ipfs.cid.decode('bafkqaaa');
  say('\na value: ${c.runtimeType} "$c" (just its text, kept in Dart)');
  // A method of a value is still Go: the text goes there and the answer back.
  //    Go:  c.Version()
  say('  its version, computed by Go: ${c.version()}');

  // 3. A handle: the map lives in Go; Dart only holds its number.
  //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
  final ds = go.ipfs.datastore.sync.mutexWrap(DatastoreMapDatastore());
  say('\na handle: ${ds.runtimeType} #${ds.$h} (the object stays in Go)');

  // 4. A function with a context returns a Future: it runs in a goroutine of
  //    the p2p_host while Dart's event loop goes on.
  //    Go:  ctx := context.Background()
  final ctx = go.context.background();
  //    Go:  bs := blockstore.NewBlockstore(ds)
  final bs = BoxoBlockstore(ds);
  //    Go:  data := []byte("hello")
  final data = utf8.encode('hello');
  // Sum is a checksum, not an addition: it hashes data with sha2-256 and
  // wraps the hash in a CIDv1 of codec raw. The CID is the block's name,
  // computed from its content.
  //    Go:  key, err := cid.NewPrefixV1(cid.Raw, mh.SHA2_256).Sum(data)
  final key = go.ipfs.cid
      .newPrefixV1(
          go.ipfs.cid.consts.raw, go.multiformats.multihash.consts.sha2256)
      .sum(data);
  // Dart only: blocks.Block is a Go interface (Cid(), RawData()...), which
  // has no constructor. Dart builds it from what its methods return, and Go
  // gets a value that answers them. In Go you would call
  // blocks.NewBlockWithCid(data, key); go.ipfs.blockFormat.newBlockWithCid
  // exists too, but it gives a handle (BlockFormatBasicBlock), not this value.
  final block = BlockFormatBlock(cid: key, rawData: data);
  //    Go:  err = bs.Put(ctx, block)
  await bs.put(ctx, block);
  //    Go:  has, err := bs.Has(ctx, key)
  say('\nasync: put a block, has it: ${await bs.has(ctx, key)}');

  // 5. A Go error is an exception, with Go's message. Each exported Go error
  //    has its own class (here cid.ErrInvalidCid), so you catch just it.
  //    Go:  _, err := cid.Decode("not-a-cid")
  //         errors.Is(err, cid.ErrInvalidCid{})
  await mistake('decoding a CID from text that is not one',
      why: 'Go returned an error; in Dart it is thrown (no `err != nil`)',
      instead: 'catch the class of the error you expect, here '
          '`on CidErrInvalidCid` (lesson 19)',
      action: () => go.ipfs.cid.decode('not-a-cid'));

  // 6. Done with a handle: release it, so Go can free the object now
  //    (otherwise only when Dart's garbage collector gets to it; lesson 20).
  bs.release();
  ds.release();

  // 7. Stopping the service ends the p2p_host. The values stay usable in
  //    Dart; the handles point to nothing.
  await P2pService.stop();
  say('after stop: the value is still "$c"; '
      'the service is running: ${P2pService.isRunning}');
  await mistake('using Go after P2pService.stop()',
      why: 'the p2p_host process ended with everything it held',
      instead: 'stop the service only at the end, after closing what is open',
      action: () => c.version());
}
