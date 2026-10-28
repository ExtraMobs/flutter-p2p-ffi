// Lição 01 · Como o Dart conversa com o Go?
//
// Pergunta: o p2p_ffi oferece "a API do Go em Dart". Onde o código Go roda, e
// o que acontece quando chamo uma das suas funções?
//
// Resposta: o Go roda em outro processo, o p2p_host (compilado por
// `dart run tool/build.dart`). P2pService.start() o inicia e se conecta a ele
// por memória compartilhada. Cada função Go é uma função Dart que manda uma
// mensagem para esse processo e espera a resposta. O que volta é uma de três
// coisas:
//   - um valor (um CID, uma string, bytes, uma struct de dados): copiado para
//     o Dart, continua existindo sem o Go;
//   - um handle (um datastore, um nó, um arquivo aberto): o objeto fica no Go,
//     e o Dart guarda um número que aponta para ele;
//   - um erro: o `error` do Go é lançado como GolangException, ou como a
//     subclasse daquele erro Go quando ele tem uma (`cid.ErrInvalidCid`...).
// Uma função Go que recebe um `context.Context` pode bloquear (disco, rede),
// então em Dart ela devolve um Future; as outras respondem na hora.
//
// Precisa de: só o build. Sem repositório, sem rede.
//
//   dart run example/pt_br/01_dart_and_go.dart
//
// Próxima pergunta: "O que é aquele CID que acabei de ver?" → lição 02.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  // 1. Antes de o serviço iniciar, não há Go para chamar.
  await mistake('chamar o Go antes do P2pService.start()',
      why: 'o código Go vive no processo p2p_host, que não está rodando',
      instead: 'await P2pService.start() uma vez, no início do programa',
      action: () => cid.decode('bafkqaaa'));

  await P2pService.start();
  say('este processo Dart: pid $pid; o processo Go (p2p_host): '
      'pid ${P2pService.hostPid}');

  // 2. Uma função sem context responde na hora, e o resultado é um valor.
  //    Go:  c, err := cid.Decode("bafkqaaa")
  final c = cid.decode('bafkqaaa');
  say('\num valor: ${c.runtimeType} "$c" (só o seu texto, guardado no Dart)');
  // Um método de um valor continua sendo Go: o texto vai, a resposta volta.
  //    Go:  c.Version()
  say('  a sua versão, calculada pelo Go: ${c.version()}');

  // 3. Um handle: o mapa vive no Go; o Dart só guarda o número dele.
  //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
  final ds = sync.mutexWrap(datastore.MapDatastore());
  say('\num handle: ${ds.runtimeType} #${ds.$h} (o objeto fica no Go)');

  // 4. Uma função com context devolve um Future: ela roda numa goroutine do
  //    p2p_host enquanto o event loop do Dart segue.
  //    Go:  ctx := context.Background()
  final ctx = context.background();
  //    Go:  bs := blockstore.NewBlockstore(ds)
  final bs = blockstore.Blockstore(ds);
  //    Go:  data := []byte("hello")
  final data = utf8.encode('hello');
  // Sum é um checksum, não uma soma: ele calcula o hash sha2-256 de data e
  // embrulha esse hash num CIDv1 de codec raw. O CID é o nome do bloco,
  // calculado a partir do conteúdo.
  //    Go:  key, err := cid.NewPrefixV1(cid.Raw, mh.SHA2_256).Sum(data)
  final key = cid.newPrefixV1(cid.raw, multihash.sha2256).sum(data);
  // Só no Dart: blocks.Block é uma interface Go (Cid(), RawData()...), que
  // não tem construtor. O Dart a monta com o que os métodos dela devolvem, e
  // o Go recebe um valor que os responde. Em Go você chamaria
  // blocks.NewBlockWithCid(data, key), que não está exposta.
  final block = blocks.Block(cid: key, rawData: data);
  //    Go:  err = bs.Put(ctx, block)
  await bs.put(ctx, block);
  //    Go:  has, err := bs.Has(ctx, key)
  say('\nassíncrono: guardei um bloco, ele está lá: '
      '${await bs.has(ctx, key)}');

  // 5. Um erro do Go é uma exceção, com a mensagem do Go. Cada erro Go
  //    exportado tem a sua classe (aqui cid.ErrInvalidCid), então você
  //    captura só ele.
  //    Go:  _, err := cid.Decode("not-a-cid")
  //         errors.Is(err, cid.ErrInvalidCid{})
  await mistake('decodificar um CID de um texto que não é um',
      why: 'o Go devolveu um erro; em Dart ele é lançado (sem `err != nil`)',
      instead: 'capture a classe do erro que você espera, aqui '
          '`on cid.ErrInvalidCid` (lição 19)',
      action: () => cid.decode('not-a-cid'));

  // 6. Terminou com um handle: libere-o, para o Go poder soltar o objeto já
  //    (senão só quando o coletor de lixo do Dart chegar nele; lição 20).
  bs.release();
  ds.release();

  // 7. Parar o serviço encerra o p2p_host. Os valores continuam usáveis no
  //    Dart; os handles não apontam para mais nada.
  await P2pService.stop();
  say('depois do stop: o valor continua "$c"; '
      'o serviço está rodando: ${P2pService.isRunning}');
  await mistake('usar o Go depois do P2pService.stop()',
      why: 'o processo p2p_host terminou, com tudo o que guardava',
      instead: 'pare o serviço só no fim, depois de fechar o que está aberto',
      action: () => c.version());
}
