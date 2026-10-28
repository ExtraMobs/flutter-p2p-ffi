// Lección 02 · ¿Qué es un CID?
//
// Pregunta: todo en IPFS se direcciona por un CID (`bafkrei...`, `Qm...`).
// ¿Qué hay dentro, y por qué puedo confiar en lo que vuelve para él?
//
// Respuesta: un CID es el nombre de unos bytes, calculado a partir de los
// propios bytes. Reúne tres cosas:
//   - el hash de los bytes (un multihash: qué función de hash, la longitud y
//     el digest);
//   - el codec: cómo leer los bytes (bytes crudos, un nodo dag-pb de un
//     archivo, dag-cbor, ...);
//   - la versión: v0 (`Qm...`, solo sha2-256 + dag-pb, base58) o v1
//     (cualquier hash, cualquier codec, cualquier base de texto).
// Quien recibe los bytes vuelve a calcular el hash y compara: si coincide,
// los bytes son los correctos, los mande quien los mande. Eso es lo que
// permite a IPFS traer contenido de desconocidos (lección 16).
//
// Necesita: la lección 01 (el servicio). Sin repositorio, sin red: un CID es
// puro cálculo.
//
//   dart run example/es/02_what_is_a_cid.dart
//
// Siguiente pregunta: "Un CID nombra unos bytes; ¿cómo obtiene un CID un
// archivo entero, demasiado grande para un bloque?" → lección 03.
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/multibase.dart' as multibase;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    // 1. De los bytes a un CID. El prefijo dice qué versión, codec y hash
    //    usar; Sum calcula el hash de los bytes y arma el CID.
    //    Go:  p := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256)
    //         c, _ := p.Sum(data)
    final raw = cid.newPrefixV1(cid.raw, multihash.sha2256);
    final hello = raw.sum(utf8.encode('hello'));
    say('"hello" como bytes crudos:   $hello');
    say('  los mismos bytes otra vez: ${raw.sum(utf8.encode('hello'))} '
        '(siempre el mismo nombre)');
    say('  un byte distinto:          ${raw.sum(utf8.encode('hellO'))}');

    // 2. Qué hay dentro: la forma binaria del CID, campo por campo.
    final b = hello.bytes();
    final mh = hello.hash(); // el multihash: función, longitud, digest
    say('\nlos ${b.length} bytes del CID: ${hex(b)}');
    say('  ${hex(b.sublist(0, 1))}      versión ${hello.version()}');
    say('  ${hex(b.sublist(1, 2))}      codec 0x${hello.type().toRadixString(16)} (raw)');
    say('  ${hex(mh.sublist(0, 1))}      función de hash 0x12 (sha2-256)');
    say('  ${hex(mh.sublist(1, 2))}      longitud del digest: ${mh[1]} bytes');
    say('  ${hex(mh.sublist(2, 6))}…  el digest en sí');
    // Los mismos campos sin el digest: lo que Sum necesita para hacer un CID.
    final p = hello.prefix();
    say('  como Prefix: versión ${p.version}, codec 0x'
        '${p.codec.toRadixString(16)}, hash 0x${p.mhType.toRadixString(16)}, '
        'longitud ${p.mhLength}');

    // 3. El texto es solo una base: el mismo CID escrito de tres maneras.
    say('\nel mismo CID en tres bases:');
    for (final (name, base) in [
      ('base32', multibase.base32), // 'b', la predeterminada del CIDv1
      ('base58btc', multibase.base58btc), // 'z', la única base del CIDv0
      (
        'base36',
        multibase.base36
      ), // 'k', para subdominios (sin mayúsculas, corta)
    ]) {
      final text = hello.stringOfBase(base);
      say('  ${name.padRight(9)} $text  (decodifica al mismo: '
          '${cid.decode(text).equals(hello)})');
    }

    // 4. El codec es parte del nombre: los mismos bytes leídos como raw o
    //    como dag-pb son CIDs distintos con el mismo hash.
    final asDagPb = cid.newCidV1(multicodec.dagPb, mh);
    say('\nel mismo hash con el codec dag-pb: $asDagPb');
    say('  mismo hash: ${hex(asDagPb.hash()) == hex(mh)}, mismo CID: '
        '${asDagPb.equals(hello)}');

    // 5. CIDv0: el antiguo `Qm...`, sha2-256 + dag-pb, base58, sin bytes de
    //    prefijo. Se convierte a v1 sin pérdida (mismo codec, mismo hash).
    //    Go:  v0 := cid.NewCidV0(mh); v1 := cid.NewCidV1(cid.DagProtobuf, v0.Hash())
    final v0 = cid.newCidV0(mh);
    final v1 = cid.newCidV1(multicodec.dagPb, v0.hash());
    say('\nCIDv0 $v0 (${v0.bytes().length} bytes: solo el multihash)');
    say('  como CIDv1:     $v1 (el mismo que el dag-pb de arriba: '
        '${v1.equals(asDagPb)})');

    // 6. Otras funciones de hash, e identity: el "hash" son los propios
    //    datos, para bytes tan pequeños que el hash alargaría el nombre.
    final sha512 = cid.newPrefixV1(multicodec.raw, multihash.sha2512);
    say('\ncon sha2-512: ${sha512.sum(utf8.encode('hello'))}');
    final identity = cid.newPrefixV1(multicodec.raw, multihash.identity);
    final inline = identity.sum(utf8.encode('hi'));
    say('con identity: $inline (los bytes "hi" están dentro: '
        '${utf8.decode(inline.hash().sublist(2))})');
    say('  el CID identity vacío, usado en la lección 01: '
        '${identity.sum(Uint8List(0))}');

    // 7. Verificar: rehacer el CID con los bytes recibidos y comparar.
    //    Es lo que todo nodo IPFS hace con cada bloque que recibe.
    bool verify(cid.Cid c, Uint8List data) => c.prefix().sum(data).equals(c);
    say('\nverify("hello"): ${verify(hello, utf8.encode('hello'))}, '
        'verify("HELLO"): ${verify(hello, utf8.encode('HELLO'))}');

    say('\n== Errores comunes\n');
    await silentlyWrong('comparar dos CIDs por su texto',
        why: 'un CID tiene muchos textos (la base, y v0 o v1 para dag-pb)',
        instead: 'compara con equals(), o compara los hashes entre v0 y v1',
        wrong: () => '$hello' == hello.stringOfBase(multibase.base58btc),
        right: () =>
            hello.equals(cid.decode(hello.stringOfBase(multibase.base58btc))));
    await mistake('un CIDv0 con un hash que no es sha2-256',
        why: 'el v0 no tiene bytes de prefijo: sha2-256 y dag-pb van '
            'implícitos',
        instead: 'cid.newPrefixV1(codec, hash) para cualquier otra cosa',
        action: () => cid.newPrefixV0(multihash.sha2512).sum(Uint8List(3)));
    await mistake('decodificar un texto cortado a la mitad',
        why: 'la longitud del digest está dentro del CID; uno corto falla',
        instead: 'decodifica el texto entero (al copiar de una URL, ojo con '
            'el final)',
        action: () => cid.decode('$hello'.substring(0, 30)));
  } finally {
    await P2pService.stop();
  }
}
