// p2p_ffi checks on the device: the local ones (the desktop suite's flows that
// fit in one process, the close and reopen cycles and the bridge's cost) run in
// the integration test and when the app opens; the public network ones only in
// the app, over its node. Each one writes to the log and fails with an exception.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/commands.dart' as commands;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface.dart' as iface;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/corerepo.dart' as corerepo;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/core/node/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangException, hasIpv6;
import 'package:p2p_ffi/src/runtime.dart'
    show $W, $call, $callSync, $stream, GoSink;

typedef Log = void Function(String line);

/// A context of the current service (the handle of a previous service is not
/// valid after the p2p_host is restarted).
context.Context get ctx => context.background();

void check(bool ok, String what) {
  if (!ok) throw StateError('failed: $what');
}

Future<void> expectThrows(Future<Object?> f, String what) async {
  try {
    await f;
  } on GolangException {
    return;
  }
  throw StateError('failed: $what (no error)');
}

/// Runs [checks] in order, each one isolated; returns how many failed.
Future<int> runAll(Map<String, Future<void> Function()> checks, Log log) async {
  var failed = 0;
  for (final MapEntry(key: name, value: run) in checks.entries) {
    log('▶ $name');
    final sw = Stopwatch()..start();
    try {
      await run();
      log('✔ $name (${sw.elapsedMilliseconds} ms)');
    } catch (e, st) {
      failed++;
      log('✘ $name (${sw.elapsedMilliseconds} ms): $e\n$st');
    }
  }
  return failed;
}

/// A new repo with the `test` profile (127.0.0.1, random ports, no bootstrap).
String newRepo(Directory tmp, String name) {
  final repoPath = '${tmp.path}/$name';
  final cfg = config.initWithIdentity(
      config.createIdentity(null, [options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(repoPath, cfg);
  return repoPath;
}

/// The local checks, in their own temporary directory (the plugins must already
/// be injected). Returns how many failed.
Future<int> localChecks(Log log) async {
  final tmp = Directory.systemTemp.createTempSync('p2p_ffi_chk_');
  final n = await core.newNode(
      ctx, node.BuildCfg(repo: fsrepo.open(newRepo(tmp, 'offline'))));
  final api = coreapi.newCoreApi(n);
  try {
    return await runAll({
      'add/get, options and pins + GC': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(utf8.encode('hello from Android')),
            [options.unixfs.pin(true, '')]);
        final got = files.toFile(await api.unixfs().get(ctx, p));
        check(
            utf8.decode(io.readAll(got)) == 'hello from Android', 'get == add');
        final loose = await api.unixfs().add(
            ctx, files.newBytesFile(utf8.encode('loose ${DateTime.now()}')));
        final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
        check(removed.isNotEmpty, 'GC removed something');
        await expectThrows(api.block().stat(ctx, loose), 'loose block is gone');
        check((await api.block().stat(ctx, p)).size > 0, 'pinned one stayed');
      },
      'add progress (events + progress)': () async {
        final data = Uint8List.fromList(List.generate(2 << 20, (i) => i * 7));
        final events = StreamController<iface.AddEvent>();
        final got = events.stream.toList();
        final p = await api.unixfs().add(ctx, files.newBytesFile(data), [
          options.unixfs.events(events.sink),
          options.unixfs.progress(true)
        ]);
        final list = await got;
        check(
            [
                  for (final e in list)
                    if (e.path == null) e.bytes
                ].last ==
                data.length,
            'last progress == size');
        check(list.last.path?.value == p.value, 'last event carries the CID');
      },
      'IPNS, keys and dag put/get': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(utf8.encode('ipns ${DateTime.now()}')),
            [options.unixfs.pin(true, '')]);
        final name =
            await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
        final back = await api
            .name()
            .resolve(ctx, '/ipns/$name', [options.name.cache(false)]);
        check(back.value == p.value, 'resolve == publish');

        final k = await api
            .key()
            .generate(ctx, 'k-android', [options.key.type('ed25519')]);
        final (_, sig) = await api.key().sign(ctx, k.name, utf8.encode('x'));
        check((await api.key().verify(ctx, k.name, sig, utf8.encode('x'))).$2,
            'signature matches');
        await api.key().remove(ctx, k.name);

        final c =
            await dag.dagPut(api, ctx, utf8.encode('{"a": {"b": [1, 2]}}'));
        final got = jsonDecode(
            utf8.decode(await dag.dagGet(api, ctx, path.Path('/ipfs/$c/a/b'))));
        check('$got' == '[1, 2]', 'dag get /a/b');
      },
      'CAR: export, GC, import back': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(
                Uint8List.fromList(List.generate(600000, (i) => i))),
            [options.unixfs.pin(true, '')]);
        final bytes = await dag.dagExport(n, ctx, p);
        await api.pin().rm(ctx, p);
        await corerepo.garbageCollect(n, ctx);
        await expectThrows(api.block().stat(ctx, p), 'GC took the file');
        final r = await dag.dagImport(n, ctx, bytes);
        check(r.roots.single.pinErrorMsg.isEmpty, 'import pinned');
        check((await api.pin().isPinned(ctx, p)).$2, 'pinned after import');
      },
      'RPC commands: id and files': () async {
        final id = await commands.id(n, ctx, null).single;
        check(id.id == (await api.key().self(ctx)).id!.value, 'id == self');
        await commands
            .filesMkdir(n, ctx, '/app/d', parents: true)
            .drain<void>();
        await commands
            .filesWrite(n, ctx, '/app/d/a.txt',
                files.newBytesFile(utf8.encode('hello files')),
                create: true)
            .drain<void>();
        final st = await commands.filesStat(n, ctx, '/app/d/a.txt').single;
        check(st.size == utf8.encode('hello files').length, 'files stat');
        final ls = await commands.filesLs(n, ctx, '/app/d').single;
        check(
            [for (final e in ls.entries) e.name].join() == 'a.txt', 'files ls');
        final read = await commands.filesRead(n, ctx, '/app/d/a.txt').toList();
        check(utf8.decode([for (final b in read) ...b]) == 'hello files',
            'files read');
        await commands.filesRm(n, ctx, ['/app'], recursive: true).toList();
        await expectThrows(commands.filesStat(n, ctx, '/app').single,
            'files rm took the directory');
      },
      'two nodes: connect, bitswap, provide/findProviders and pubsub': () =>
          _twoNodes(tmp),
      // Alternates DHT client (the app's) and Routing none: in kubo 0.43, none
      // left the provider-keystore datastore open after close, and reopening hit
      // the lock; the build fixes it with a patch (tool/build.dart,
      // upstreamPatches).
      'life cycle: 10x newNode → close → fsrepo.open on the same repo':
          () async {
        final repoPath = newRepo(tmp, 'cycles');
        for (var i = 0; i < 10; i++) {
          final nn = await core.newNode(
              ctx,
              node.BuildCfg(
                  repo: fsrepo.open(repoPath),
                  online: true,
                  routing: i.isEven
                      ? libp2p.dhtClientOption
                      : libp2p.nilRouterOption));
          await nn.close();
        }
        final nn =
            await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
        try {
          final a = coreapi.newCoreApi(nn);
          final p =
              await a.unixfs().add(ctx, files.newBytesFile(utf8.encode('end')));
          check(
              utf8.decode(
                      io.readAll(files.toFile(await a.unixfs().get(ctx, p)))) ==
                  'end',
              'add/get after the cycles');
        } finally {
          await nn.close();
        }
      },
      // p2p_ffi's own goroutines (try/goTry in go/runtime.go)
      'a panic in an p2p_ffi goroutine becomes GolangException': () async {
        final items = <Object?>[];
        await expectThrows($stream(25).map((r) => r.i64()).forEach(items.add),
            'function with a channel');
        check('$items' == '[1]', 'the item before the panic arrived');
        final c = StreamController<Object?>();
        final sink = expectThrows(c.stream.drain<void>(), 'sink');
        await $call(26, $W()..sink(GoSink(c.sink, (r) => r.i64())));
        await sink;
      },
      'bridge cost (channel to the p2p_host)': () async {
        final repoPath = '${tmp.path}/offline';
        // the median of each call: the mean becomes hostage to the tail (the
        // host or the isolate losing the CPU right after the heavy tests,
        // hundreds of µs on the device; integration_test/bench_test.dart)
        double bench(void Function() f) {
          for (var i = 0; i < 500; i++) {
            f();
          }
          const count = 5000;
          final sw = Stopwatch()..start();
          final t = List<int>.filled(count, 0);
          for (var i = 0; i < count; i++) {
            final t0 = sw.elapsedTicks;
            f();
            t[i] = sw.elapsedTicks - t0;
          }
          t.sort();
          return t[count ~/ 2] * 1e6 / sw.frequency;
        }

        Future<double> benchAsync(Future<Object?> Function() f) async {
          for (var i = 0; i < 200; i++) {
            await f();
          }
          const count = 2000;
          final sw = Stopwatch()..start();
          for (var i = 0; i < count; i++) {
            await f();
          }
          return sw.elapsedMicroseconds / count;
        }

        String us(double v) => '${v.toStringAsFixed(1)} µs';
        final getter = bench(() => api.unixfs());
        final stat = bench(() => fsrepo.isInitialized(repoPath));
        final c0 = ctx;
        final err = bench(() => c0.err());
        final timeout = bench(() {
          final (_, cancel) =
              context.withTimeout(c0, const Duration(seconds: 1));
          cancel();
        });
        // Noop (function 0): the channel's floor, without kubo
        final noop = bench(() => $callSync(0));
        final noopAsync = await benchAsync(() => $call(0));
        final p =
            await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('x')));
        final block = api.block();
        final statAsync = await benchAsync(() => block.stat(ctx, p));
        log('  synchronous (median): api.unixfs() ${us(getter)}; fsrepo.isInitialized '
            '${us(stat)}; ctx.err() ${us(err)}; withTimeout+cancel ${us(timeout)}');
        log('  Noop synchronous (median) ${us(noop)}, asynchronous (mean) ${us(noopAsync)}; '
            'block.stat asynchronous ${us(statAsync)}');
        check(getter < noop * 20, "api.unixfs() close to the channel's floor");
      },
    }, log);
  } finally {
    await n.close();
    tmp.deleteSync(recursive: true);
  }
}

Future<void> _twoNodes(Directory tmp) async {
  Future<(core.IpfsNode, iface.CoreApi)> online(String name) async {
    final nn = await core.newNode(
        ctx,
        node.BuildCfg(
            repo: fsrepo.open(newRepo(tmp, name)),
            online: true,
            routing: libp2p.dhtServerOption,
            extraOpts: {'pubsub': true}));
    return (nn, coreapi.newCoreApi(nn));
  }

  final (na, a) = await online('a');
  final (nb, b) = await online('b');
  try {
    final idA = (await a.key().self(ctx)).id!;
    await b.swarm().connect(
        ctx, peer.AddrInfo(id: idA, addrs: await a.swarm().localAddrs(ctx)));

    final p = await a.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('from A ${DateTime.now()}')),
        [options.unixfs.pin(true, '')]);
    final (c, cancel) = context.withTimeout(ctx, const Duration(seconds: 30));
    try {
      check(
          utf8
              .decode(io.readAll(files.toFile(await b.unixfs().get(c, p))))
              .startsWith('from A'),
          'B read over bitswap');
    } finally {
      cancel();
    }

    await a.routing().provide(ctx, p);
    var provs = <peer.AddrInfo>[];
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (
        !provs.any((i) => i.id == idA) && DateTime.now().isBefore(deadline)) {
      provs = await b
          .routing()
          .findProviders(ctx, p, [options.routing.numProviders(5)]).toList();
      if (provs.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    check(provs.any((i) => i.id == idA), 'B found A as a provider');

    const topic = 'ipfs-ffi-android';
    final sub = await a.pubSub().subscribe(ctx, topic);
    while (!(await b.pubSub().peers(ctx, [options.pubSub.topic(topic)]))
            .contains(idA) &&
        DateTime.now().isBefore(deadline.add(const Duration(seconds: 30)))) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await b.pubSub().publish(ctx, topic, utf8.encode('hi from B'));
    final (c2, cancel2) = context.withTimeout(ctx, const Duration(seconds: 30));
    try {
      check(utf8.decode((await sub.next(c2)).data!) == 'hi from B',
          "A got B's message");
    } finally {
      cancel2();
      sub.close();
    }
  } finally {
    await na.close();
    await nb.close();
  }
}

/// The public network checks over the app's online node [api]: interfaces
/// (wlan* = Wi-Fi, rmnet*/ccmni* = mobile data), peers (inbound × outbound tells
/// whether the NAT lets in), addresses, DNS (DNSLink) and a block from the network.
Future<int> networkChecks(iface.CoreApi api, Log log) => runAll({
      'network interfaces': () async {
        for (final i in await NetworkInterface.list()) {
          log('  ${i.name}: ${[
            for (final a in i.addresses) a.address
          ].join(', ')}');
        }
        log('  hasIpv6(): ${await hasIpv6()}');
      },
      'public network peers (up to 60 s)': () async {
        final sw = Stopwatch()..start();
        var peers = await api.swarm().peers(ctx);
        while (peers.isEmpty && sw.elapsed < const Duration(seconds: 60)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          peers = await api.swarm().peers(ctx);
        }
        final inbound = peers.where((p) => p.direction == 1).length;
        log('  ${peers.length} peers (inbound $inbound, '
            'outbound ${peers.length - inbound}) in ${sw.elapsed.inSeconds} s');
        check(peers.isNotEmpty, 'some peer');
      },
      "the node's addresses": () async {
        log('  local: ${(await api.swarm().localAddrs(ctx)).join(' ')}');
        final listen = [
          for (final a in await api.swarm().listenAddrs(ctx)) '$a'
        ];
        log('  listening: ${listen.join(' ')}');
        // the app's repo also listens on UDP (QUIC): without it there is no hole punching
        check(listen.any((a) => a.contains('/udp/') && a.contains('/quic-v1')),
            'listening on UDP (QUIC)');
      },
      'DNSLink + a block from the network (/ipns/ipfs.tech, up to 60 s)':
          () async {
        final (c, cancel) =
            context.withTimeout(ctx, const Duration(seconds: 60));
        try {
          final sw = Stopwatch()..start();
          final p = await api.name().resolve(c, '/ipns/ipfs.tech');
          log('  resolved in ${sw.elapsedMilliseconds} ms: $p');
          final st = await api.block().stat(c, p);
          log('  root block (${st.size} bytes) in ${sw.elapsedMilliseconds} ms');
        } finally {
          cancel();
        }
      },
    }, log);

/// Reachability, with the node online for [wait] (AutoRelay and hole punching
/// take a while): the connections' transports, who came in (directly or through a
/// relay) and whether the node has a relay address (/p2p-circuit) to announce.
Future<int> reachabilityChecks(iface.CoreApi api, Stopwatch online, Log log,
        {Duration wait = const Duration(minutes: 2)}) =>
    runAll({
      'reachability (node online for ${wait.inMinutes} min)': () async {
        final rest = wait - online.elapsed;
        if (rest > Duration.zero) {
          log('  waiting ${rest.inSeconds} s');
          await Future<void>.delayed(rest);
        }
        // the relay reservation varies: on mobile data it once arrived within
        // 2 min (11 addresses) and, another time, only later; wait up to `wait`
        // more
        Future<bool> reachable() async =>
            (await api.swarm().localAddrs(ctx))
                .any((a) => '$a'.contains('/p2p-circuit')) ||
            (await api.swarm().peers(ctx)).any((p) => p.direction == 1);
        final extra = Stopwatch()..start();
        while (!await reachable() && extra.elapsed < wait) {
          await Future<void>.delayed(const Duration(seconds: 10));
        }
        if (extra.elapsed.inSeconds > 0) {
          log('  ${extra.elapsed.inSeconds} s more waiting for the relay');
        }
        final peers = await api.swarm().peers(ctx);
        String transport(String a) => a.contains('/p2p-circuit')
            ? 'relay'
            : a.contains('/webrtc')
                ? 'webrtc'
                : a.contains('/webtransport')
                    ? 'webtransport'
                    : a.contains('/quic')
                        ? 'quic'
                        : a.contains('/tcp')
                            ? 'tcp'
                            : '?';
        final byTransport = <String, int>{};
        for (final p in peers) {
          final t = transport('${p.address}');
          byTransport[t] = (byTransport[t] ?? 0) + 1;
        }
        // libp2p's network.Direction: 1 = inbound, 2 = outbound
        final inbound = [
          for (final p in peers)
            if (p.direction == 1) '${p.address}'
        ];
        log('  ${peers.length} peers; transports $byTransport; '
            'inbound ${inbound.length}');
        for (final a in inbound.take(5)) {
          log('  came in through $a');
        }
        // direct connections on the local network (mDNS or the announced local IP)
        final lan = RegExp(r'/ip4/(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)');
        final local = [
          for (final p in peers)
            if (lan.hasMatch('${p.address}')) '${p.id} through ${p.address}'
        ];
        log('  ${local.length} connections on the local network');
        for (final a in local.take(5)) {
          log('    $a');
        }
        final addrs = [for (final a in await api.swarm().localAddrs(ctx)) '$a'];
        final relay = addrs.where((a) => a.contains('/p2p-circuit')).length;
        log('  ${addrs.length} announced addresses ($relay relay):');
        for (final a in addrs) {
          log('    $a');
        }
        check(relay > 0 || inbound.isNotEmpty,
            'reachable (a relay address or an inbound connection)');
      },
    }, log);
