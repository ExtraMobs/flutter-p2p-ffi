// Lección 16 · ¿Qué necesita boxo para descargar un CID?
//
// Pregunta: en la lección 04 un bloque que faltaba era un error: "el
// exchange offline no tiene a quién preguntar". ¿Qué tiene que estar en su
// sitio para que un CID venga de otra máquina?
//
// Respuesta: cambiar el exchange offline por bitswap, el intercambio de
// bloques de boxo. Traer un archivo pasa a ser esta cadena, donde cada
// eslabón necesita el anterior:
//   1. el DAGService pide al blockservice el CID raíz;
//   2. el blockservice busca en el blockstore local; si no está, pregunta al
//      exchange (bitswap);
//   3. bitswap envía un "want" del CID a cada peer al que está conectado, por
//      su red: un host libp2p que habla /ipfs/bitswap;
//   4. si ningún peer conectado lo tiene, tras una breve espera pregunta a
//      su buscador de proveedores (el DHT de la lección 15, o un enrutador
//      delegado) quién tiene el CID, se conecta a ellos y se lo pide;
//   5. un peer que tiene el bloque (con su propio bitswap, sobre su propio
//      blockstore) lo envía; bitswap calcula el hash y lo compara con el CID
//      (lección 02) antes de guardarlo: nunca se confía en quien lo envía;
//   6. el bloque se guarda, los enlaces de la raíz dan los siguientes CIDs, y
//      la cadena se repite para los hijos (muchos a la vez).
// Así que, técnicamente: un host (para hablar), un buscador de proveedores
// (para encontrar), un blockstore (para guardar), bitswap en LOS DOS lados,
// y alguien que tenga los bloques y esté conectado o los haya anunciado
// (Provide). Un nodo kubo online (lección 17) arma exactamente esto como
// n.exchange.
//
// Necesita: las lecciones 03-04 (la pila), 13-15 (hosts, conexiones, DHT).
//
//   dart run example/es/16_fetch_a_cid.dart
//
// Siguiente pregunta: "¿Y para traer de la red IPFS de verdad, no de mis
// propios hosts?" → lección 17.
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = Go.context.background();

    // El mundo: a tiene el ejemplo de la lección 03 en su blockstore; b y c
    // empiezan vacíos. Cada uno tiene un host y un DHT; b y c conocen a d,
    // el bootstrap. a se queda fuera de la red hasta el paso 3.
    final s = await Sample.build(ctx);
    final root = s.root;
    Future<Libp2pCoreHost> newHost() => Go.libp2p.new$([
          Go.libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newHost()];
    final opts = [
      Go.libp2pKadDht.mode(Go.libp2pKadDht.modeServer),
      Go.libp2pKadDht.protocolPrefix('/lesson16')
    ];
    final [dhtA, dhtB, dhtC, dhtD] = [
      for (final h in [a, b, c, d]) Go.libp2pKadDht.new$(h, opts)
    ];
    for (final h in [b, c]) {
      await h.connect(ctx, Go.libp2p.core.host.infoFromHost(d));
    }
    for (final x in [dhtB, dhtC, dhtD]) {
      await x.bootstrap(ctx);
    }
    say('a tiene la carpeta de ejemplo ${root.toString().substring(0, 12)}…; '
        'b y c no tienen nada');

    // Bitswap en un host: su red (el host hablando /ipfs/bitswap), un
    // buscador de proveedores (el DHT) y el blockstore que sirve y llena.
    //    Go:  bs := bitswap.New(ctx, bsnet.NewFromIpfsHost(h), finder, bstore)
    Future<BoxoBitswap> bitswapOn(Libp2pCoreHost h, Libp2pKadDhtIpfsDht finder,
            BoxoBlockstore store) =>
        Go.boxo.bitswap.new$(ctx,
            Go.boxo.bitswap.network.bsnet.newFromIpfsHost(h), finder, store);
    BoxoBlockstore emptyStore() =>
        BoxoBlockstore(Go.datastore.sync.mutexWrap(DatastoreMapDatastore()));
    final bsA = await bitswapOn(a, dhtA, s.store); // a sirve sus bloques

    // Lee data.bin de un blockservice sobre [store] y [ex], con un plazo: el
    // lector de la lección 04, sin cambios.
    Future<int> readWith(BoxoBlockstore store, BoxoExchangeInterface ex,
        {Duration within = const Duration(seconds: 20)}) async {
      final (tctx, cancel) = Go.context.withTimeout(ctx, within);
      try {
        final dag = Go.boxo.ipld.merkledag
            .newDagService(Go.boxo.blockservice.new$(store, ex));
        final folder = await dag.get(tctx, root);
        final dataBin = await dag.get(tctx, folder.links().first.cid!);
        final f =
            await Go.boxo.ipld.unixfs.file.newUnixfsFile(tctx, dag, dataBin);
        return Go.io.readAll(Go.boxo.files.toFile(f)).length;
      } finally {
        cancel();
      }
    }

    // 1. b con el exchange offline: la lección 04 otra vez.
    final storeB = emptyStore();
    await mistake('b trayendo con el exchange offline',
        why: 'el blockstore no lo tiene y offline no tiene a quién preguntar',
        instead: 'un exchange que pregunte a los peers: bitswap (abajo)',
        action: () =>
            readWith(storeB, Go.boxo.exchange.offline.exchange(storeB)));

    // 2. b con bitswap, pero a nunca anunció el CID y b no está conectado a
    //    a: los wants no van a nadie útil, el DHT no tiene registro.
    final bsB = await bitswapOn(b, dhtB, storeB);
    await mistake('b trayendo antes de que nadie anuncie el CID',
        why: 'bitswap pregunta a los peers conectados (ninguno lo tiene) y al '
            'DHT (ningún registro de proveedor): espera hasta el plazo',
        instead: 'quien lo tiene lo anuncia (Provide), o te conectas a él',
        action: () =>
            readWith(storeB, bsB, within: const Duration(seconds: 3)));

    // 3. a entra en el DHT y anuncia la raíz; b vuelve a pedir: bitswap
    //    encuentra a a por el DHT, se conecta, pide, recibe, comprueba.
    //    Go:  dhtA.Provide(ctx, root, true)
    await a.connect(ctx, Go.libp2p.core.host.infoFromHost(d));
    await dhtA.bootstrap(ctx);
    await dhtA.provide(ctx, root, true);
    final watch = Stopwatch()..start();
    final viaDht = await readWith(storeB, bsB);
    say('\nb, después de que a anunciara la raíz: leyó data.bin, $viaDht '
        'bytes, en ${watch.elapsedMilliseconds} ms (encontró a a por el DHT; '
        'b ahora conectado a a: ${b.network().connectedness(a.id()) == 1})');

    // 4. c se conecta directamente a a: los wants van directos a a, sin
    //    búsqueda.
    final storeC = emptyStore();
    final bsC = await bitswapOn(c, dhtC, storeC);
    await c.connect(ctx, Go.libp2p.core.host.infoFromHost(a));
    watch.reset();
    final direct = await readWith(storeC, bsC);
    say('c, conectado a a: $direct bytes en ${watch.elapsedMilliseconds} ms '
        '(sin búsqueda en el DHT)');

    // 5. Lo que contó bitswap. Ahora b tiene los bloques: también los sirve,
    //    como todo nodo IPFS que trajo algo.
    final stA = bsA.stat(), stB = bsB.stat();
    say('\nestadísticas de bitswap: a envió ${stA.blocksSent} bloques; b '
        'recibió ${stB.blocksReceived} (${stB.dataReceived} bytes), b tiene '
        'la raíz ahora: ${await storeB.has(ctx, root)}');

    say('\n== Errores comunes\n');
    // e guarda los mismos bloques que a (el blockstore de a) pero no ejecuta
    // bitswap; f se conecta solo a e y pide la raíz.
    final e = await newHost(), f = await newHost();
    final dhtF = Go.libp2pKadDht.new$(f, opts);
    final storeF = emptyStore();
    final bsF = await bitswapOn(f, dhtF, storeF);
    await f.connect(ctx, Go.libp2p.core.host.infoFromHost(e));
    await mistake('traer de un peer que tiene los bloques pero no bitswap',
        why: 'e nunca oye los wants: tener los bloques no basta, algo tiene '
            'que servirlos por /ipfs/bitswap',
        instead: 'bitswap en los dos lados: quien trae pide, quien tiene sirve '
            '(un nodo kubo online hace las dos cosas)',
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
