// Lección 13 · ¿Quién soy en la red?
//
// Pregunta: hasta aquí todo era local. Para hablar con otras máquinas, mi
// programa necesita un nombre y una dirección en la red. ¿Qué son, y qué los
// decide?
//
// Respuesta: libp2p, la capa de red debajo de IPFS. Tres ideas:
//   - el peer ID: el hash de una clave pública (`12D3KooW...`). Es quién
//     eres, te conectes desde donde te conectes; guardar la clave privada
//     guarda el ID. Cada conexión lo prueba con una firma, así que no se puede
//     falsificar.
//   - el multiaddr: cómo llegar a ti, como una ruta de protocolos
//     (`/ip4/127.0.0.1/tcp/4001/p2p/12D3KooW...`): una IP, un transporte, un
//     puerto y, al final, el peer ID esperado ahí. Un peer tiene varios.
//   - el host: el objeto que guarda la clave, escucha en las direcciones y
//     habla una pila de protocolos en cada conexión: un transporte (TCP,
//     QUIC, WebSocket...), una capa de seguridad (Noise o TLS: cifra y
//     comprueba el peer ID) y un multiplexor (yamux: muchos streams en una
//     conexión).
// Un nodo kubo (lección 08) arma su host a partir de la identidad y de los
// Addresses de la config; aquí armamos hosts directamente, sin kubo.
//
// Necesita: la lección 01 (el servicio). Técnicamente, un host necesita un
// par de claves (generado o cargado), direcciones de escucha que el sistema
// le deje ocupar, y al menos un transporte, una seguridad y un multiplexor
// (los valores por defecto de libp2p, si no se dan).
//
//   dart run example/es/13_who_am_i.dart
//
// Siguiente pregunta: "Tengo una dirección; ¿cómo hablan de verdad dos
// hosts?" → lección 14.
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. Un par de claves, y el peer ID que sale de él.
    //    Go:  sk, pk, _ := crypto.GenerateKeyPair(crypto.Ed25519, -1)
    //         id, _ := peer.IDFromPrivateKey(sk)
    final (sk, pk) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.consts.ed25519, -1);
    final id = go.libp2p.libp2p.core.peer.idFromPrivateKey(sk);
    say('peer ID: $id');
    say('  también desde la clave pública: '
        '${go.libp2p.libp2p.core.peer.idFromPublicKey(pk) == id}; coincide con la clave privada: '
        '${id.matchesPrivateKey(sk)}');
    // El mismo ID como CID (codec libp2p-key): es lo que es un nombre IPNS
    // (lección 11).
    final asCid = go.libp2p.libp2p.core.peer.toCid(id);
    say('  como CID: ${asCid.stringOfBase(go.multiformats.multibase.consts.base36)} (codec 0x'
        '${asCid.type().toRadixString(16)}, libp2p-key: '
        '${asCid.type() == go.multiformats.multicodec.enums.libp2pKey})');

    // 2. Guardar la clave es guardar el ID: serialízala (en un archivo, en un
    //    almacenamiento seguro) y deserialízala en el siguiente arranque.
    //    Go:  b, _ := crypto.MarshalPrivateKey(sk); sk2, _ := crypto.UnmarshalPrivateKey(b)
    final saved = go.libp2p.libp2p.core.crypto.marshalPrivateKey(sk);
    final loaded = go.libp2p.libp2p.core.crypto.unmarshalPrivateKey(saved);
    say('\nla clave guardada en ${saved.length} bytes y cargada de vuelta: '
        'el mismo ID ${go.libp2p.libp2p.core.peer.idFromPrivateKey(loaded) == id}');

    // 3. Multiaddrs: interpretar, desarmar, armar.
    //    Go:  ma, _ := multiaddr.NewMultiaddr("/ip4/127.0.0.1/tcp/4001")
    final addr =
        go.multiformats.multiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = go.multiformats.multiaddr.newMultiaddr('$addr/p2p/$id');
    say('\nmultiaddr $addr');
    say('  con el peer: $full');
    say('  el puerto TCP: ${addr.valueForProtocol(6)}; el peer al final: '
        '${go.libp2p.libp2p.core.peer.splitAddr(full).$2 == id}');

    // 4. Un host con esta clave, escuchando en dos transportes, puertos
    //    elegidos por el sistema (0).
    //    Go:  h, _ := libp2p.New(libp2p.Identity(sk), libp2p.ListenAddrStrings(...))
    final h = await go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options.identity(loaded),
      go.libp2p.libp2p.options.listenAddrStrings(
          ['/ip4/127.0.0.1/tcp/0', '/ip4/127.0.0.1/udp/0/quic-v1']),
    ]);
    say('\nun host: ${h.id()} (el mismo ID: ${h.id() == id})');
    for (final a in h.addrs()) {
      say('  escuchando en $a');
    }
    await h.close();

    // 5. Elegir la pila a mano: solo TCP, Noise y yamux. Cada pieza es un
    //    constructor Go, pasado como token.
    //    Go:  libp2p.New(libp2p.Transport(tcp.NewTCPTransport),
    //             libp2p.Security(noise.ID, noise.New), libp2p.Muxer(yamux.ID, yamux.DefaultTransport))
    final small = await go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options
          .transport(go.libp2p.libp2p.p2p.transport.tcp.newTcpTransportFunc),
      go.libp2p.libp2p.options.security(
          go.libp2p.libp2p.p2p.security.noise.consts.id,
          go.libp2p.libp2p.p2p.security.noise.newFunc),
      go.libp2p.libp2p.options.muxer(go.libp2p.libp2p.p2p.muxer.yamux.consts.id,
          go.libp2p.libp2p.p2p.muxer.yamux.defaultTransport),
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);
    say('\nun host solo TCP: ${small.addrs()} (una clave aleatoria: otro ID, '
        '${small.id().shortString()})');

    say('\n== Errores comunes\n');
    await mistake('escuchar en una IP que no es de esta máquina',
        why: 'un host solo puede escuchar en sus propias interfaces (0.0.0.0 '
            'significa todas)',
        instead: '/ip4/0.0.0.0/tcp/0, o 127.0.0.1 solo para esta máquina',
        action: () async => (await go.libp2p.libp2p.new$([
              go.libp2p.libp2p.options
                  .listenAddrStrings(['/ip4/203.0.113.7/tcp/0'])
            ]))
                .close());
    await small.close();
    await mistake('un multiaddr escrito como una URL',
        why: 'un multiaddr son pares /protocolo/valor, no host:puerto',
        instead: '/ip4/127.0.0.1/tcp/4001 (o /dns4/example.com/tcp/4001)',
        action: () => go.multiformats.multiaddr.newMultiaddr('127.0.0.1:4001'));
    await mistake('un peer ID que no lo es',
        why: 'un peer ID es el multihash de una clave; un texto cualquiera no '
            'se decodifica',
        instead: 'tómalo del host (h.id()) o de una dirección /p2p/',
        action: () => go.libp2p.libp2p.core.peer.decode('my-peer'));
    await silentlyWrong('una clave nueva en cada arranque',
        why: 'el peer ID es la clave: una clave nueva es un peer nuevo para '
            'todos los que te conocían',
        instead: 'serializa la clave una vez y cárgala en cada arranque '
            '(paso 2)',
        wrong: () => go.libp2p.libp2p.core.peer.idFromPrivateKey(go
            .libp2p.libp2p.core.crypto
            .generateKeyPair(go.libp2p.libp2p.core.crypto.consts.ed25519, -1)
            .$1),
        right: () => go.libp2p.libp2p.core.peer.idFromPrivateKey(
            go.libp2p.libp2p.core.crypto.unmarshalPrivateKey(saved)));
  } finally {
    await P2pService.stop();
  }
}
