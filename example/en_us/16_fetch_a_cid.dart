// Lesson 16 · What does boxo need to download a CID?
//
// Question: in lesson 04 a missing block was an error: "the offline exchange
// has nobody to ask". What has to be in place for a CID to come from
// another machine instead?
//
// Answer: swap the offline exchange for bitswap, boxo's block exchange.
// Fetching a file is then this chain, each link needing the one before:
//   1. the DAGService asks the blockservice for the root CID;
//   2. the blockservice looks in the local blockstore; not there, it asks
//      the exchange (bitswap);
//   3. bitswap sends a "want" for the CID to every peer it is connected to,
//      through its network: a libp2p host speaking /ipfs/bitswap;
//   4. if no connected peer has it, after a short delay it asks its
//      provider finder (the DHT of lesson 15, or a delegated router) who
//      has the CID, connects to them, and wants it from them;
//   5. a peer that has the block (its own bitswap, over its own blockstore)
//      sends it; bitswap hashes it and checks it against the CID (lesson 02)
//      before storing it: the sender is never trusted;
//   6. the block is stored, the root's links give the next CIDs, and the
//      chain repeats for the children (many at once).
// So, technically: a host (to talk), a provider finder (to find), a
// blockstore (to keep), bitswap on BOTH sides, and someone who has the
// blocks and either is connected or has announced them (Provide).
// An online kubo node (lesson 17) builds exactly this as n.exchange.
//
// Needs: lessons 03-04 (the stack), 13-15 (hosts, connections, DHT).
//
//   dart run example/en_us/16_fetch_a_cid.dart
//
// Next question: "And to fetch from the real IPFS network, not my own
// hosts?" → lesson 17.
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = goContext.background();

    // The world: a has the sample of lesson 03 in its blockstore; b and c
    // start empty. Each has a host and a DHT; b and c know d, the
    // bootstrap. a stays off the network until step 3.
    final s = await Sample.build(ctx);
    final root = s.root;
    Future<Libp2pCoreHost> newHost() => goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newHost()];
    final opts = [
      goLibp2pKadDht.mode(goLibp2pKadDht.modeServer),
      goLibp2pKadDht.protocolPrefix('/lesson16')
    ];
    final [dhtA, dhtB, dhtC, dhtD] = [
      for (final h in [a, b, c, d]) goLibp2pKadDht.new$(h, opts)
    ];
    for (final h in [b, c]) {
      await h.connect(ctx, goLibp2p.core.host.infoFromHost(d));
    }
    for (final x in [dhtB, dhtC, dhtD]) {
      await x.bootstrap(ctx);
    }
    say('a has the sample folder ${root.toString().substring(0, 12)}…; b, c '
        'have nothing');

    // Bitswap on a host: its network (the host speaking /ipfs/bitswap), a
    // provider finder (the DHT) and the blockstore it serves and fills.
    //    Go:  bs := bitswap.New(ctx, bsnet.NewFromIpfsHost(h), finder, bstore)
    Future<BoxoBitswap> bitswapOn(Libp2pCoreHost h, Libp2pKadDhtIpfsDht finder,
            BoxoBlockstore store) =>
        goBoxo.bitswap.new$(ctx,
            goBoxo.bitswap.network.bsnet.newFromIpfsHost(h), finder, store);
    BoxoBlockstore emptyStore() =>
        BoxoBlockstore(goDatastore.sync.mutexWrap(DatastoreMapDatastore()));
    final bsA = await bitswapOn(a, dhtA, s.store); // a serves its blocks

    // Read data.bin from a blockservice over [store] and [ex], with a
    // deadline: the lesson 04 reader, unchanged.
    Future<int> readWith(BoxoBlockstore store, BoxoExchangeInterface ex,
        {Duration within = const Duration(seconds: 20)}) async {
      final (tctx, cancel) = goContext.withTimeout(ctx, within);
      try {
        final dag = goBoxo.ipld.merkledag
            .newDagService(goBoxo.blockservice.new$(store, ex));
        final folder = await dag.get(tctx, root);
        final dataBin = await dag.get(tctx, folder.links().first.cid!);
        final f =
            await goBoxo.ipld.unixfs.file.newUnixfsFile(tctx, dag, dataBin);
        return goIo.readAll(goBoxo.files.toFile(f)).length;
      } finally {
        cancel();
      }
    }

    // 1. b with the offline exchange: lesson 04 again.
    final storeB = emptyStore();
    await mistake('b fetching with the offline exchange',
        why: 'the blockstore does not have it and offline has nobody to ask',
        instead: 'an exchange that asks peers: bitswap (below)',
        action: () =>
            readWith(storeB, goBoxo.exchange.offline.exchange(storeB)));

    // 2. b with bitswap, but a never announced the CID and b is not
    //    connected to a: wants go to nobody useful, the DHT has no record.
    final bsB = await bitswapOn(b, dhtB, storeB);
    await mistake('b fetching before anyone announced the CID',
        why: 'bitswap asks connected peers (none has it) and the DHT (no '
            'provider record): it waits until the deadline',
        instead: 'the holder announces it (Provide), or you connect to it',
        action: () =>
            readWith(storeB, bsB, within: const Duration(seconds: 3)));

    // 3. a joins the DHT and announces the root; b fetches again: bitswap
    //    finds a through the DHT, connects, wants, receives, checks.
    //    Go:  dhtA.Provide(ctx, root, true)
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(d));
    await dhtA.bootstrap(ctx);
    await dhtA.provide(ctx, root, true);
    final watch = Stopwatch()..start();
    final viaDht = await readWith(storeB, bsB);
    say('\nb, after a provided the root: read data.bin, $viaDht bytes, in '
        '${watch.elapsedMilliseconds} ms (found a through the DHT; b now '
        'connected to a: ${b.network().connectedness(a.id()) == 1})');

    // 4. c connects to a directly: the wants go straight to a, no lookup.
    final storeC = emptyStore();
    final bsC = await bitswapOn(c, dhtC, storeC);
    await c.connect(ctx, goLibp2p.core.host.infoFromHost(a));
    watch.reset();
    final direct = await readWith(storeC, bsC);
    say('c, connected to a: $direct bytes in ${watch.elapsedMilliseconds} ms '
        '(no DHT lookup)');

    // 5. What bitswap counted. b now has the blocks: it serves them too,
    //    like every IPFS node that fetched something.
    final stA = bsA.stat(), stB = bsB.stat();
    say('\nbitswap stats: a sent ${stA.blocksSent} blocks; b received '
        '${stB.blocksReceived} (${stB.dataReceived} bytes), b has the root '
        'now: ${await storeB.has(ctx, root)}');

    say('\n== Common mistakes\n');
    // e holds the same blocks as a (a's blockstore) but runs no bitswap;
    // f connects to e only and wants the root.
    final e = await newHost(), f = await newHost();
    final dhtF = goLibp2pKadDht.new$(f, opts);
    final storeF = emptyStore();
    final bsF = await bitswapOn(f, dhtF, storeF);
    await f.connect(ctx, goLibp2p.core.host.infoFromHost(e));
    await mistake('fetching from a peer that has the blocks but no bitswap',
        why: 'e never hears the wants: having the blocks is not enough, '
            'something must serve them over /ipfs/bitswap',
        instead: 'bitswap on both sides: the fetcher wants, the holder serves '
            '(an online kubo node does both)',
        action: () =>
            readWith(storeF, bsF, within: const Duration(seconds: 3)));

    for (final x in [bsA, bsB, bsC, bsF]) {
      x.close();
    }
    for (final x in [dhtA, dhtB, dhtC, dhtD, dhtF]) {
      await x.close();
    }
    for (final h in [a, b, c, d, e, f]) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
  }
}
