// Lesson 21 · How does Go call my Dart code?
//
// Question: some Go functions take a function: a stream handler (lesson 14),
// a pubsub validator (lesson 18), a callback per index entry. Go runs in
// another process; how does it call a Dart function, and what are the
// rules?
//
// Answer: a Dart function passed where Go expects a function becomes a
// callback: when Go calls it, the p2p_host sends the arguments to Dart, Dart
// runs the function on its event loop, and the answer (or the exception)
// goes back to Go. Four shapes:
//   - called during the call, many times (an index's ForEach): Go sends
//     the calls in batches to save round trips (`batchSize`); throwing
//     from the function stops Go, and the call fails with your error;
//   - kept by Go after the call returns (a stream handler, a Notifiee, a
//     validator): Go calls it whenever the event happens, until you remove
//     it (removeStreamHandler, stopNotify...);
//   - a Go interface implemented in Dart (network.Notifiee, mdns.Notifee):
//     one Dart function per Go method, the ones you leave out do nothing;
//   - a function that receives a Go object valid only during the call (a
//     selector builder): use it inside, never keep it.
// If, inside a callback, your Dart code calls back into a Go object that
// the waiting Go function holds locked, the p2p_host notices and throws
// GolangDeadlockException in your function instead of hanging.
//
// Needs: lessons 06 (an index, a selector), 14 (a stream handler).
//
//   dart run example/en_us/21_callbacks.dart
//
// That is the end of the course; the questions it answers are in README.md.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// Thrown from a callback to stop the Go loop early.
class Enough implements Exception {}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson21_');
  try {
    final ctx = goContext.background();

    // 1. Called many times during the call: each entry of a CAR index.
    //    Go:  idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    final s = await Sample.build(ctx);
    final carFile = '${tmp.path}/sample.car';
    await s.writeCar(ctx, carFile);
    final idx =
        goCar.v2.generateIndexFromFile(carFile).asCarV2IndexIterableIndex()!;
    final offsets = <int>[];
    await idx.forEach((multihash, offset) => offsets.add(offset));
    say('forEach called the Dart function ${offsets.length} times; offsets '
        '${offsets..sort()}');
    //    Stopping early: throw; Go stops and the call fails with your error.
    var seen = 0;
    try {
      await idx.forEach((_, __) {
        if (++seen == 2) throw Enough();
      }, batchSize: 1);
    } on Enough {
      say('  stopped after $seen entries by throwing from the callback');
    }

    // 2. Kept by Go: a stream handler, called for every stream that comes,
    //    until removed.
    //    Go:  b.SetStreamHandler(proto, func(s network.Stream) {...})
    Future<Libp2pCoreHost> newHost() => goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final a = await newHost(), b = await newHost();
    var served = 0;
    b.setStreamHandler('/lesson/echo/1.0.0', (st) async {
      served++;
      final got = await readerStream(st).expand((c) => c).toList();
      await st.write(Uint8List.fromList(got.reversed.toList()));
      await st.close();
    });
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(b));
    Future<String> echo(String text) async {
      final st = await a.newStream(ctx, b.id(), ['/lesson/echo/1.0.0']);
      await st.write(Uint8List.fromList(utf8.encode(text)));
      await st.closeWrite();
      return utf8.decode(await readerStream(st).expand((c) => c).toList());
    }

    say('\necho "abc" → "${await echo('abc')}", "dart" → '
        '"${await echo('dart')}" (the handler ran $served times)');
    b.removeStreamHandler('/lesson/echo/1.0.0');

    // 3. A Go interface implemented in Dart: only the methods you need.
    //    Go:  a.Network().Notify(&network.NotifyBundle{DisconnectedF: ...})
    final gone = Libp2pCoreNetworkNotifiee(
        disconnected: (_, c) =>
            say('  [Notifiee] lost ${c.remotePeer().shortString()}'));
    a.network().notify(gone);
    final c = await newHost();
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(c));
    say('\nclosing c, with a Notifiee on a:');
    await c.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.network().stopNotify(gone);

    // 4. A Go object valid only during the call: a selector builder hands
    //    a fields builder to the function, which fills it right there.
    //    Go:  ssb.ExploreFields(func(efsb builder.ExploreFieldsSpecBuilder) {
    //             efsb.Insert("Links", ssb.Matcher()) })
    final ssb = IpldPrimeTraversalSelectorBuilderSelectorSpecBuilder(
        IpldPrimeNodeBasicnodePrototypeAny());
    final spec =
        await ssb.exploreFields((f) => f.insert('Links', ssb.matcher()));
    say('\nexploreFields: built a selector spec inside the callback: '
        '${spec.runtimeType}');

    say('\n== Common mistakes\n');
    await mistake('a big batch for a callback that gets a Go object',
        why: 'with a batch, Go moves on before Dart runs the function: the '
            'fields builder is already finished when Dart inserts into it',
        instead: 'keep the default (1) when the callback receives a Go '
            'object; batches only for plain values (offsets, bytes)',
        action: () => ssb.exploreFields((f) => f.insert('Links', ssb.matcher()),
            batchSize: 1024));
    await mistake('opening a stream to a handler that was removed',
        why: 'removeStreamHandler took the Dart function away from Go: b '
            'no longer speaks the protocol',
        instead: 'keep the handler while you serve; remove it when done',
        action: () => echo('again'));
    await a.close();
    await b.close();
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
