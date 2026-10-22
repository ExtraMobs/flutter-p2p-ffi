// Step 11: deadlines and cancellation (Go's `context`), the two kinds of error
// and what to do when the service goes down.
//
//   dart run example/11_context_and_errors.dart
//
// The Future and Stream concepts are explained at the start of example 09.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/core/commands.dart' as commands;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/ipfs_ffi.dart'
    show GolangException, P2pService, P2pServiceException, P2pStop;
// Only for step 4: a TEST function of the package, which brings the ipfs_host
// down on purpose. Do not use it in an app; it exists to prove the recovery.
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;

/// Kubo's plugins: once per service (kubo refuses a second time in the same
/// process, and a restarted service is a new process, without them).
void plugins() => loader.PluginLoader('')
  ..initialize()
  ..inject();

/// The node over [repoPath]. Online, because step 1's pubsub only exists in an
/// online node (the daemon's `Pubsub.Enabled`); with the repo's `test` profile,
/// it listens only on 127.0.0.1 and does not go out to the internet.
Future<core.IpfsNode> openNode(String repoPath) => core.newNode(
    context.background(),
    node.BuildCfg(
        repo: fsrepo.open(repoPath),
        online: true,
        extraOpts: {'pubsub': true}));

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex11_');
  final repoPath = '${tmp.path}/repo';

  // `onStop` is called when the service stops without you asking (a kubo crash,
  // or the app going to the background on Android). The package NEVER restarts
  // on its own: you decide, here. We keep each stop in a Completer (a Future we
  // complete by hand) for step 4 to wait for it.
  var stopped = Completer<P2pStop>();
  await P2pService.start(
      crashLog: '${tmp.path}/crash.log', // where Go writes the report
      onStop: (s) => stopped.complete(s));

  final cfg = config.initWithIdentity(
      config.createIdentity(null, [options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  plugins();
  fsrepo.init(repoPath, cfg);
  var n = await openNode(repoPath);

  try {
    // ------------------------------------------------------------------
    // 1. A deadline: withTimeout
    // ------------------------------------------------------------------
    // `withTimeout` creates a child context that expires on its own after the
    // deadline, and returns TWO values (a Dart "record"): the context and the
    // `cancel` function. Always call cancel when you are done, even if the
    // deadline already passed: it is what releases the context in Go.
    final (withDeadline, cancelDeadline) =
        context.withTimeout(context.background(), const Duration(seconds: 2));
    final sw = Stopwatch()..start();
    try {
      // `ipfs pubsub sub` never ends on its own: it keeps waiting for messages.
      // With the 2 s deadline, kubo ends the Stream with a deadline-exceeded
      // error, which `await for` turns into an exception.
      await for (final m in commands.pubsubSub(n, withDeadline, 'room-11')) {
        print('message: ${m.data}'); // nobody publishes: it will not show up
      }
    } on GolangException catch (e) {
      print('1. after ${sw.elapsed.inMilliseconds} ms: $e');
    } finally {
      cancelDeadline();
    }

    // ------------------------------------------------------------------
    // 2. Canceling right away: withCancel
    // ------------------------------------------------------------------
    // The same, but without a deadline: the context only ends when you call
    // cancel (e.g. the user left the chat screen). Here we listen with `.listen`
    // (it does not pause the code) and cancel after 1 s.
    final (cancelable, cancel) = context.withCancel(context.background());
    final end = Completer<String>();
    commands.pubsubSub(n, cancelable, 'room-11').listen(
          (m) {}, // onData: each message (none comes)
          onError: (Object e) => end.complete('error: $e'),
          onDone: () {
            // After an error, the Stream still reports the end (onDone), unless
            // you ask for `cancelOnError: true` (below). That is why we check:
            // completing the same Completer twice is an error.
            if (!end.isCompleted) end.complete('ended without an error');
          },
          cancelOnError: true, // stop listening on the first error
        );
    await Future<void>.delayed(const Duration(seconds: 1));
    // Kubo sees the canceled context and closes the subscription. Note the
    // output: in `pubsub sub`, cancellation ends the Stream WITHOUT an error
    // (onDone), unlike step 1's deadline, which ended with an error.
    cancel();
    print('2. after cancel: ${await end.future}');

    // ------------------------------------------------------------------
    // 3. A kubo error: GolangException
    // ------------------------------------------------------------------
    // The call reached kubo, and it answered with an error (in Go, the `error`
    // the function returned). The service is still up; you can go on.
    try {
      await commands
          .filesStat(n, context.background(), '/does/not/exist')
          .single;
    } on P2pServiceException {
      rethrow; // (it is a subclass of GolangException: handle it first, if needed)
    } on GolangException catch (e) {
      print('3. kubo error, the service goes on: $e');
    }

    // ------------------------------------------------------------------
    // 4. The service went down: P2pServiceException and onStop
    // ------------------------------------------------------------------
    // A Go panic nobody handles (one of kubo's internal goroutines, for example)
    // brings the ipfs_host process down. The app stays alive: pending calls fail
    // with P2pServiceException, and onStop gets the reason and Go's report.
    // Here we cause the crash on purpose.
    $callSync(24); // TEST ONLY: a panic in a host goroutine
    final s = await stopped.future; // waits for onStop
    print('4. the service stopped: ${s.reason}, exit ${s.exitCode}, '
        'up for ${s.uptime.inSeconds} s');
    print("   Go's report: ${s.report.split('\n').first}");

    // Everything that came from the previous service (node, CoreAPI,
    // contexts...) died with it: using it now gives P2pServiceException.
    try {
      coreapi.newCoreApi(n);
    } on P2pServiceException catch (e) {
      // (the message carries Go's whole report; here, only the first line)
      print('   the old node is no longer valid: ${'$e'.split('\n').first}');
    }

    // Restarting is your decision: here, yes. The process is new, so we redo
    // plugins and node; the repo's data is on disk and stays there.
    stopped = Completer<P2pStop>();
    await P2pService.restart();
    plugins();
    n = await openNode(repoPath);
    final p = await coreapi.newCoreApi(n).unixfs().add(
        context.background(), files.newBytesFile(utf8.encode('back again')));
    print('5. back: the new service already added $p');
  } finally {
    if (P2pService.isRunning) await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
