// Lesson 19 · How do I set a deadline and cancel? What errors can come?
//
// Question: fetching a CID nobody has, or waiting for a message, can take
// forever (lessons 16-18). How do I stop waiting, and how do I tell the
// different failures apart?
//
// Answer: Go's `context`, the first argument of every call that may wait:
//   - goContext.withTimeout(parent, d) / withDeadline: Go itself gives up when
//     time is out, and the call throws GolangDeadlineExceededException;
//   - goContext.withCancel(parent): call cancel() whenever you want; the call
//     throws GolangCanceledException;
//   - always call the cancel function you got back when done: it frees what
//     Go holds for that context.
// A deadline on the Go side stops the Go work; a Dart `.timeout()` on the
// Future only stops Dart from waiting, while Go keeps working.
// The errors, from narrow to broad (catch the narrow ones first):
//   - GolangNotFoundException, GolangEofException, GolangCanceledException,
//     GolangDeadlineExceededException...: Go's well-known errors;
//   - the class of each exported error of a Go package, named after the
//     package: IoFsErrNotExist (fs.ErrNotExist), IoFsPathError (with its op
//     and path), CidErrInvalidCid...;
//   - GolangException: any other Go error, with Go's message;
// Every one carries the chain: errTexts (the text of each wrapped link,
// from the outside in; errText is the original cause), errno (the
// operating system's number, when there is one) and isA<T>() / find<T>(),
// Go's errors.Is / errors.As.
//   - P2pServiceException: the service itself is not there (not started,
//     stopped, or crashed). It also counts as a GolangException, so catch it
//     before.
// If the p2p_host crashes (a Go panic outside any call), only the service
// goes; the app gets onStop with the reason and Go's report, and can
// restart: a new process, so plugins, repo and node are opened again and
// old handles are invalid.
//
// Needs: lesson 08 (a node) and 17 (something that waits on the network).
//
//   dart run example/en_us/19_deadlines_and_errors.dart
//
// Next question: "The node and every object I opened live in Go. When are
// they freed?" → lesson 20.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';
// ignore: implementation_imports
import 'package:p2p_ffi/src/runtime.dart' show $callSync;

import 'lesson.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson19_');
  var stopped = Completer<P2pStop>();
  await P2pService.start(
      crashLog: '${tmp.path}/crash.log', // where Go writes a crash report
      onStop: (s) => stopped.complete(s));
  var bg = goContext.background();
  // An online node alone (test profile: no bootstrap peers): asking it for
  // a CID nobody has waits forever, the perfect thing to put a limit on.
  var n = await newNode(bg, '${tmp.path}/repo', online: true);
  final nowhere = BoxoPath('/ipfs/'
      '${goCid.newPrefixV1(goMulticodec.raw, goMultihash.sha2256).sum(utf8.encode('nobody has this'))}');
  try {
    var api = goKubo.core.coreapi.newCoreApi(n);

    // 1. A deadline: Go stops the work when time is out.
    //    Go:  ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    //         defer cancel()
    final (withDeadline, cancelDeadline) =
        goContext.withTimeout(bg, const Duration(seconds: 2));
    final watch = Stopwatch()..start();
    try {
      await api.unixfs().get(withDeadline, nowhere);
    } on GolangDeadlineExceededException catch (e) {
      say('1. deadline: after ${watch.elapsedMilliseconds} ms, '
          '${e.runtimeType}: ${e.message}');
    } finally {
      cancelDeadline();
    }

    // 2. Cancel by hand, from anywhere (a button, the app closing).
    //    Go:  ctx, cancel := context.WithCancel(context.Background())
    final (cancelable, cancel) = goContext.withCancel(bg);
    Timer(const Duration(milliseconds: 500), cancel);
    try {
      await api.unixfs().get(cancelable, nowhere);
    } on GolangCanceledException catch (e) {
      say('2. canceled after ~500 ms: ${e.runtimeType}: ${e.message}');
    }

    // 3. The kinds of error, narrow first.
    Future<String> kindOf(Future<Object?> Function() call) async {
      try {
        await call();
        return 'no error';
      } on P2pServiceException catch (e) {
        return 'P2pServiceException (the service): ${brief(e)}';
      } on GolangNotFoundException catch (e) {
        return 'GolangNotFoundException: ${brief(e)}';
      } on IoFsPathError catch (e) {
        return 'fs.PathError: op "${e.op}", errno ${e.errno}';
      } on GolangException catch (e) {
        return '${className(e)}: ${brief(e)}';
      }
    }

    say('\n3. kinds of error:');
    say('  a MFS path that is not there → '
        '${await kindOf(() => goKubo.core.commands.filesStat(n, bg, '/nope').single)}');
    say('  a block not in the blockstore → '
        '${await kindOf(() => n.blockstore.get(bg, goCid.decode(nowhere.value.substring(6))))}');
    say('  a CID that is not one → '
        '${await kindOf(() async => goCid.decode('not-a-cid'))}');
    say('  a file that is not there (goOs.open) → '
        '${await kindOf(() async => goOs.open('${tmp.path}/nope.bin'))}');

    //    The chain of an error: what each layer added, down to the cause.
    try {
      goOs.open('${tmp.path}/nope.bin');
    } on GolangException catch (e) {
      say('  the chain of an goOs.open error, outside in:');
      for (final t in e.errTexts) {
        say('    - ${t.replaceAll(tmp.path, '<tmp>')}');
      }
      say('    the cause: "${e.errText}", errno ${e.errno}, thrown as '
          '${className(e)}');
    }

    // 4. A crash of the service (TEST ONLY: a hook that panics in a Go
    //    goroutine, like a bug inside kubo). Only the p2p_host goes; this
    //    program goes on, told by onStop.
    const panicInGoroutineHook = 24; // WIRE.md
    $callSync(panicInGoroutineHook);
    final s = await stopped.future;
    say('\n4. the service stopped: ${s.reason}, exit code ${s.exitCode}, up '
        '${s.uptime.inSeconds} s');
    say("   Go's report starts with: ${s.report.split('\n').first}");
    say('   the old node now: '
        '${await kindOf(() => api.unixfs().add(bg, goBoxo.files.newBytesFile(utf8.encode('x'))))}');

    // 5. Restart: a new process; open everything again on the same repo.
    //    Every handle belongs to the old service, the context too: make new
    //    ones.
    stopped = Completer<P2pStop>();
    await P2pService.restart();
    bg = goContext.background();
    n = await openNode(bg, '${tmp.path}/repo', online: true);
    api = goKubo.core.coreapi.newCoreApi(n);
    final p = await api
        .unixfs()
        .add(bg, goBoxo.files.newBytesFile(utf8.encode('back')));
    say('5. restarted: the new service added $p');

    say('\n== Common mistakes\n');
    await mistake('a Dart .timeout() instead of a Go deadline',
        why: 'Dart stops waiting, but Go keeps looking for the CID: the work '
            'and what it holds go on in the p2p_host',
        instead: 'goContext.withTimeout: Go itself stops and frees it',
        action: () =>
            api.unixfs().get(bg, nowhere).timeout(const Duration(seconds: 1)));
    final (done, cancelDone) = goContext.withCancel(bg);
    cancelDone();
    await mistake('reusing a context that was already canceled',
        why: 'a canceled context stays canceled: every call with it fails '
            'at once, and kubo may wrap the cause (here as "could not '
            'resolve name", not as a GolangCanceledException)',
        instead: 'a new context per operation (or per screen, per request)',
        action: () => api.unixfs().get(done, nowhere));
  } finally {
    if (P2pService.isRunning) await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}

/// The class name of a Go exception, with its Go package
/// (`fs.ErrNotExist`, `GolangNotFoundException`): the start of its toString.
String className(Object e) => '$e'.split(': ').first;
