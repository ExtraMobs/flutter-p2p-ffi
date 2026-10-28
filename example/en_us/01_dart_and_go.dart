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
//   - an error: Go's `error` is thrown as a GolangException.
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

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  // 1. Before the service starts there is no Go to call.
  await mistake('calling Go before P2pService.start()',
      why: 'the Go code lives in the p2p_host process, which is not running',
      instead: 'await P2pService.start() once, at the start of the program',
      action: () => cid.decode('bafkqaaa'));

  await P2pService.start();
  say('this Dart process: pid $pid; the Go process (p2p_host): '
      'pid ${P2pService.hostPid}');

  // 2. A function without a context answers right away, and its result is a
  //    value. Go:  c, err := cid.Decode("bafkqaaa")
  final c = cid.decode('bafkqaaa');
  say('\na value: ${c.runtimeType} "$c" (just its text, kept in Dart)');
  // A method of a value is still Go: the text goes there and the answer back.
  say('  its version, computed by Go: ${c.version()}');

  // 3. A handle: the map lives in Go; Dart only holds its number.
  //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
  final ds = sync.mutexWrap(datastore.MapDatastore());
  say('\na handle: ${ds.runtimeType} #${ds.$h} (the object stays in Go)');

  // 4. A function with a context returns a Future: it runs in a goroutine of
  //    the p2p_host while Dart's event loop goes on.
  //    Go:  bs := blockstore.NewBlockstore(ds)
  //         err := bs.Put(ctx, blocks.NewBlock(data))
  final ctx = context.background();
  final bs = blockstore.Blockstore(ds);
  final data = utf8.encode('hello');
  final block = blocks.Block(
      cid: cid.newPrefixV1(cid.raw, 0x12).sum(data), rawData: data);
  await bs.put(ctx, block);
  say('\nasync: put a block, has it: ${await bs.has(ctx, block.cid!)}');

  // 5. A Go error is an exception, with Go's message.
  await mistake('decoding a CID from text that is not one',
      why: 'Go returned an error; in Dart it is thrown (no `err != nil`)',
      instead: 'catch GolangException where bad input is expected',
      action: () => cid.decode('not-a-cid'));

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
