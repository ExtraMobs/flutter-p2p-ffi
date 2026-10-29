// Lição 13 · Quem sou eu na rede?
//
// Pergunta: até aqui tudo era local. Para falar com outras máquinas, o meu
// programa precisa de um nome e de um endereço na rede. O que são, e o que os
// decide?
//
// Resposta: o libp2p, a camada de rede debaixo do IPFS. Três ideias:
//   - o peer ID: o hash de uma chave pública (`12D3KooW...`). É quem você é,
//     de onde quer que se conecte; guardar a chave privada guarda o ID. Toda
//     conexão o prova com uma assinatura, então ele não pode ser forjado.
//   - o multiaddr: como chegar até você, como um caminho de protocolos
//     (`/ip4/127.0.0.1/tcp/4001/p2p/12D3KooW...`): um IP, um transporte, uma
//     porta e, no fim, o peer ID esperado ali. Um peer tem vários.
//   - o host: o objeto que guarda a chave, escuta nos endereços e fala uma
//     pilha de protocolos em cada conexão: um transporte (TCP, QUIC,
//     WebSocket...), uma camada de segurança (Noise ou TLS: cifra e confere
//     o peer ID) e um multiplexador (yamux: muitos streams numa conexão).
// Um nó kubo (lição 08) monta o seu host a partir da identidade e dos
// Addresses da config; aqui montamos hosts direto, sem kubo.
//
// Precisa de: lição 01 (o serviço). Tecnicamente, um host precisa de um par
// de chaves (gerado ou carregado), de endereços de escuta que o sistema o
// deixe ocupar, e de pelo menos um transporte, uma segurança e um
// multiplexador (os padrões do libp2p, se não forem dados).
//
//   dart run example/pt_br/13_who_am_i.dart
//
// Próxima pergunta: "Tenho um endereço; como dois hosts conversam de fato?"
// → lição 14.
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. Um par de chaves, e o peer ID que vem dele.
    //    Go:  sk, pk, _ := crypto.GenerateKeyPair(crypto.Ed25519, -1)
    //         id, _ := peer.IDFromPrivateKey(sk)
    final (sk, pk) = Go.libp2p.core.crypto
        .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1);
    final id = Go.libp2p.core.peer.idFromPrivateKey(sk);
    say('peer ID: $id');
    say('  também a partir da chave pública: '
        '${Go.libp2p.core.peer.idFromPublicKey(pk) == id}; bate com a chave privada: '
        '${id.matchesPrivateKey(sk)}');
    // O mesmo ID como CID (codec libp2p-key): é o que um nome IPNS é
    // (lição 11).
    final asCid = Go.libp2p.core.peer.toCid(id);
    say('  como CID: ${asCid.stringOfBase(Go.multibase.base36)} (codec 0x'
        '${asCid.type().toRadixString(16)}, libp2p-key: '
        '${asCid.type() == Go.multicodec.libp2pKey})');

    // 2. Guardar a chave é guardar o ID: serialize-a (num arquivo, num
    //    armazenamento seguro) e a desserialize no próximo início.
    //    Go:  b, _ := crypto.MarshalPrivateKey(sk); sk2, _ := crypto.UnmarshalPrivateKey(b)
    final saved = Go.libp2p.core.crypto.marshalPrivateKey(sk);
    final loaded = Go.libp2p.core.crypto.unmarshalPrivateKey(saved);
    say('\na chave guardada em ${saved.length} bytes e carregada de volta: o '
        'mesmo ID ${Go.libp2p.core.peer.idFromPrivateKey(loaded) == id}');

    // 3. Multiaddrs: interpretar, desmontar, montar.
    //    Go:  ma, _ := multiaddr.NewMultiaddr("/ip4/127.0.0.1/tcp/4001")
    final addr = Go.multiaddr.newMultiaddr('/ip4/127.0.0.1/tcp/4001');
    final full = Go.multiaddr.newMultiaddr('$addr/p2p/$id');
    say('\nmultiaddr $addr');
    say('  com o peer: $full');
    say('  a porta TCP: ${addr.valueForProtocol(6)}; o peer no fim: '
        '${Go.libp2p.core.peer.splitAddr(full).$2 == id}');

    // 4. Um host com esta chave, escutando em dois transportes, portas
    //    escolhidas pelo sistema (0).
    //    Go:  h, _ := libp2p.New(libp2p.Identity(sk), libp2p.ListenAddrStrings(...))
    final h = await Go.libp2p.new$([
      Go.libp2p.identity(loaded),
      Go.libp2p.listenAddrStrings(
          ['/ip4/127.0.0.1/tcp/0', '/ip4/127.0.0.1/udp/0/quic-v1']),
    ]);
    say('\num host: ${h.id()} (o mesmo ID: ${h.id() == id})');
    for (final a in h.addrs()) {
      say('  escutando em $a');
    }
    await h.close();

    // 5. Escolher a pilha à mão: só TCP, Noise e yamux. Cada peça é um
    //    construtor Go, passado como token.
    //    Go:  libp2p.New(libp2p.Transport(tcp.NewTCPTransport),
    //             libp2p.Security(noise.ID, noise.New), libp2p.Muxer(yamux.ID, yamux.DefaultTransport))
    final small = await Go.libp2p.new$([
      Go.libp2p.transport(Go.libp2p.p2p.transport.tcp.newTcpTransportFunc),
      Go.libp2p.security(Go.libp2p.p2p.security.noise.id,
          Go.libp2p.p2p.security.noise.newFunc),
      Go.libp2p.muxer(Go.libp2p.p2p.muxer.yamux.id,
          Go.libp2p.p2p.muxer.yamux.defaultTransport),
      Go.libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);
    say('\num host só TCP: ${small.addrs()} (uma chave aleatória: outro ID, '
        '${small.id().shortString()})');

    say('\n== Erros comuns\n');
    await mistake('escutar num IP que não é desta máquina',
        why: 'um host só escuta nas próprias interfaces (0.0.0.0 quer dizer '
            'todas elas)',
        instead: '/ip4/0.0.0.0/tcp/0, ou 127.0.0.1 só para esta máquina',
        action: () async => (await Go.libp2p.new$([
              Go.libp2p.listenAddrStrings(['/ip4/203.0.113.7/tcp/0'])
            ]))
                .close());
    await small.close();
    await mistake('um multiaddr escrito como URL',
        why: 'um multiaddr são pares /protocolo/valor, não host:porta',
        instead: '/ip4/127.0.0.1/tcp/4001 (ou /dns4/example.com/tcp/4001)',
        action: () => Go.multiaddr.newMultiaddr('127.0.0.1:4001'));
    await mistake('um peer ID que não é um',
        why: 'um peer ID é o multihash de uma chave; um texto qualquer não '
            'decodifica',
        instead: 'pegue-o do host (h.id()) ou de um endereço /p2p/',
        action: () => Go.libp2p.core.peer.decode('my-peer'));
    await silentlyWrong('uma chave nova a cada início',
        why: 'o peer ID é a chave: chave nova é peer novo para todos que '
            'conheciam você',
        instead: 'serialize a chave uma vez e carregue-a a cada início '
            '(passo 2)',
        wrong: () => Go.libp2p.core.peer.idFromPrivateKey(Go.libp2p.core.crypto
            .generateKeyPair(Go.libp2p.core.crypto.ed25519, -1)
            .$1),
        right: () => Go.libp2p.core.peer.idFromPrivateKey(
            Go.libp2p.core.crypto.unmarshalPrivateKey(saved)));
  } finally {
    await P2pService.stop();
  }
}
