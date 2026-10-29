// Lição 02 · O que é um CID?
//
// Pergunta: tudo no IPFS é endereçado por um CID (`bafkrei...`, `Qm...`). O
// que tem dentro dele, e por que posso confiar no que volta para ele?
//
// Resposta: um CID é o nome de alguns bytes, calculado a partir dos próprios
// bytes. Ele junta três coisas:
//   - o hash dos bytes (um multihash: qual função de hash, o tamanho e o
//     digest);
//   - o codec: como ler os bytes (bytes crus, um nó dag-pb de um arquivo,
//     dag-cbor, ...);
//   - a versão: v0 (`Qm...`, só sha2-256 + dag-pb, base58) ou v1 (qualquer
//     hash, qualquer codec, qualquer base de texto).
// Quem recebe os bytes calcula o hash de novo e compara: se bate, os bytes
// são os certos, venham de quem vierem. É isso que permite ao IPFS buscar
// conteúdo de desconhecidos (lição 16).
//
// Precisa de: lição 01 (o serviço). Sem repositório, sem rede: um CID é só
// cálculo.
//
//   dart run example/pt_br/02_what_is_a_cid.dart
//
// Próxima pergunta: "Um CID dá nome a alguns bytes; como um arquivo inteiro,
// grande demais para um bloco, ganha um CID?" → lição 03.
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. Dos bytes a um CID. O prefixo diz qual versão, codec e hash usar;
    //    Sum calcula o hash dos bytes e monta o CID.
    //    Go:  p := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256)
    //         c, _ := p.Sum(data)
    final raw = Go.cid.newPrefixV1(Go.cid.raw, Go.multihash.sha2256);
    final hello = raw.sum(utf8.encode('hello'));
    say('"hello" como bytes crus:   $hello');
    say('  os mesmos bytes de novo: ${raw.sum(utf8.encode('hello'))} '
        '(sempre o mesmo nome)');
    say('  um byte diferente:       ${raw.sum(utf8.encode('hellO'))}');

    // 2. O que tem dentro: a forma binária do CID, campo a campo.
    final b = hello.bytes();
    final mh = hello.hash(); // o multihash: função, tamanho, digest
    say('\nos ${b.length} bytes do CID: ${hex(b)}');
    say('  ${hex(b.sublist(0, 1))}      versão ${hello.version()}');
    say('  ${hex(b.sublist(1, 2))}      codec 0x${hello.type().toRadixString(16)} (raw)');
    say('  ${hex(mh.sublist(0, 1))}      função de hash 0x12 (sha2-256)');
    say('  ${hex(mh.sublist(1, 2))}      tamanho do digest: ${mh[1]} bytes');
    say('  ${hex(mh.sublist(2, 6))}…  o próprio digest');
    // Os mesmos campos sem o digest: o que o Sum precisa para fazer um CID.
    final p = hello.prefix();
    say('  como Prefix: versão ${p.version}, codec 0x'
        '${p.codec.toRadixString(16)}, hash 0x${p.mhType.toRadixString(16)}, '
        'tamanho ${p.mhLength}');

    // 3. O texto é só uma base: o mesmo CID escrito de três jeitos.
    say('\no mesmo CID em três bases:');
    for (final (name, base) in [
      ('base32', Go.multibase.base32), // 'b', o padrão do CIDv1
      ('base58btc', Go.multibase.base58btc), // 'z', a única base do CIDv0
      (
        'base36',
        Go.multibase.base36
      ), // 'k', para subdomínios (sem maiúsculas, curto)
    ]) {
      final text = hello.stringOfBase(base);
      say('  ${name.padRight(9)} $text  (decodifica para o mesmo: '
          '${Go.cid.decode(text).equals(hello)})');
    }

    // 4. O codec faz parte do nome: os mesmos bytes lidos como raw ou como
    //    dag-pb são CIDs diferentes com o mesmo hash.
    final asDagPb = Go.cid.newCidV1(Go.multicodec.dagPb, mh);
    say('\no mesmo hash com o codec dag-pb: $asDagPb');
    say('  mesmo hash: ${hex(asDagPb.hash()) == hex(mh)}, mesmo CID: '
        '${asDagPb.equals(hello)}');

    // 5. CIDv0: o antigo `Qm...`, sha2-256 + dag-pb, base58, sem bytes de
    //    prefixo. Converte para v1 sem perda (mesmo codec, mesmo hash).
    //    Go:  v0 := cid.NewCidV0(mh); v1 := cid.NewCidV1(cid.DagProtobuf, v0.Hash())
    final v0 = Go.cid.newCidV0(mh);
    final v1 = Go.cid.newCidV1(Go.multicodec.dagPb, v0.hash());
    say('\nCIDv0 $v0 (${v0.bytes().length} bytes: só o multihash)');
    say('  como CIDv1:     $v1 (o mesmo que o dag-pb acima: '
        '${v1.equals(asDagPb)})');

    // 6. Outras funções de hash, e identity: o "hash" são os próprios dados,
    //    para bytes tão pequenos que o hash deixaria o nome mais longo.
    final sha512 = Go.cid.newPrefixV1(Go.multicodec.raw, Go.multihash.sha2512);
    say('\ncom sha2-512: ${sha512.sum(utf8.encode('hello'))}');
    final identity =
        Go.cid.newPrefixV1(Go.multicodec.raw, Go.multihash.identity);
    final inline = identity.sum(utf8.encode('hi'));
    say('com identity: $inline (os bytes "hi" estão dentro: '
        '${utf8.decode(inline.hash().sublist(2))})');
    say('  o CID identity vazio, usado na lição 01: '
        '${identity.sum(Uint8List(0))}');

    // 7. Verificar: refazer o CID a partir dos bytes recebidos e comparar.
    //    É o que todo nó IPFS faz com cada bloco que recebe.
    bool verify(Cid c, Uint8List data) => c.prefix().sum(data).equals(c);
    say('\nverify("hello"): ${verify(hello, utf8.encode('hello'))}, '
        'verify("HELLO"): ${verify(hello, utf8.encode('HELLO'))}');

    say('\n== Erros comuns\n');
    await silentlyWrong('comparar dois CIDs pelo texto',
        why: 'um CID tem vários textos (a base, e v0 ou v1 para dag-pb)',
        instead: 'compare com equals(), ou compare os hashes entre v0 e v1',
        wrong: () => '$hello' == hello.stringOfBase(Go.multibase.base58btc),
        right: () => hello
            .equals(Go.cid.decode(hello.stringOfBase(Go.multibase.base58btc))));
    await mistake('um CIDv0 com um hash que não é sha2-256',
        why: 'o v0 não tem bytes de prefixo: sha2-256 e dag-pb ficam '
            'implícitos',
        instead: 'Go.cid.newPrefixV1(codec, hash) para qualquer outra coisa',
        action: () =>
            Go.cid.newPrefixV0(Go.multihash.sha2512).sum(Uint8List(3)));
    await mistake('decodificar um texto cortado no meio',
        why: 'o tamanho do digest está dentro do CID; um texto curto falha',
        instead: 'decodifique o texto inteiro (ao copiar de uma URL, cuidado '
            'com o fim)',
        action: () => Go.cid.decode('$hello'.substring(0, 30)));
  } finally {
    await P2pService.stop();
  }
}
