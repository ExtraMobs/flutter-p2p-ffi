// Lição 05 · Como levo blocos sem rede?
//
// Pergunta: os meus blocos estão num blockstore (lições 03-04). Como mando um
// DAG inteiro para outra máquina, ou o guardo num arquivo só, sem a rede do
// IPFS?
//
// Resposta: um arquivo CAR (Content-Addressed aRchive): um cabeçalho com as
// raízes, depois os blocos um atrás do outro, cada um com o seu CID. Um CAR é
// um blockstore num arquivo: gravado com o blockstore de leitura e escrita do
// CAR, lido com o de só leitura, que se encaixa na mesma pilha da lição 03 no
// lugar do blockstore em memória. Quem recebe não confia em nada: cada bloco é
// conferido com o seu CID (lição 02). É o que o `ipfs dag export` grava, o que
// os gateways servem com `?format=car` e o que o `ipfs dag import` lê.
//
// Precisa de: lições 03-04 (o DAG de exemplo e a pilha). Para gravar um CAR:
// as raízes na abertura (os CIDs por onde quem recebe deve começar) e todos os
// blocos do DAG. Para extrair arquivos dele: um blockservice e um DAGService
// sobre o CAR (offline, então todo bloco tem de estar no CAR).
//
//   dart run example/pt_br/05_car_files.dart
//
// Próxima pergunta: "CARv1, CARv2, índice, raízes... e se eu quiser só uma
// parte do DAG, ou juntar dois CARs?" → lição 06.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson05_');
  try {
    final ctx = Go.context.background();
    final s = await Sample.build(ctx);
    say('a pasta de exemplo: ${s.root}');

    // 1. Quais blocos: percorra o DAG a partir da raiz, o pai antes dos
    //    filhos (a ordem em que o `ipfs dag export` grava). Cada Get pelo CID
    //    de um link devolve o bloco sob aquele CID exato, codec incluído.
    Future<List<BlockFormatBlock>> dagBlocks(Cid c) async => [
          await s.store.get(ctx, c),
          for (final l in await Go.ipldFormat.getLinks(ctx, s.dag, c))
            ...await dagBlocks(l.cid!),
        ];

    // 2. Gravar: abra o CAR com as raízes, ponha os blocos, finalize.
    //    O Finalize grava o cabeçalho (CARv2) e um índice (lição 06).
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, []cid.Cid{root})
    //         rw.PutMany(ctx, blks); rw.Finalize()
    final out = '${tmp.path}/folder.car';
    Future<void> writeCar(String path, List<BlockFormatBlock> all) async {
      final rw = Go.car.v2.blockstore.openReadWrite(path, [s.root]);
      await rw.putMany(ctx, all);
      rw.finalize();
    }

    final all = await dagBlocks(s.root);
    await writeCar(out, all);
    say('\ngravei $out: ${all.length} blocos, ${File(out).lengthSync()} bytes');

    // 3. Inspecionar: versão, raízes, quantos blocos, as raízes estão dentro.
    //    O Reader mapeia o arquivo: feche-o sempre.
    //    Go:  r, _ := car.OpenReader(out); defer r.Close(); st, _ := r.Inspect(false)
    final r = Go.car.v2.openReader(out);
    try {
      final st = r.inspect(false);
      say('CARv${r.version}, raízes ${r.roots()}, ${st.blockCount} blocos '
          '(as raízes estão nele: ${st.rootsPresent})');
      say('  por codec ${st.codecCounts} (0x70 dag-pb), tamanhos '
          '${st.minBlockLength}..${st.maxBlockLength} bytes');
    } finally {
      r.close();
    }

    // 4. Listar os blocos na ordem do arquivo. O BlockReader confere o hash
    //    de cada bloco ao ler; o fim é o io.EOF do Go.
    //    Go:  br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final f = Go.os.open(out);
    try {
      final br = CarV2BlockReader(f);
      say('\nos blocos no arquivo:');
      while (true) {
        try {
          final b = br.next();
          say('  ${b.cid}  ${b.rawData!.length} bytes');
        } on GolangEofException {
          break;
        }
      }
    } finally {
      f.close();
    }

    // 5. O CAR como blockstore: pegar um bloco pelo CID (pelo índice), e
    //    extrair os arquivos pondo-o debaixo da pilha da lição 04.
    //    Go:  ro, _ := blockstore.OpenReadOnly(out); defer ro.Close()
    //         dag := merkledag.NewDAGService(blockservice.New(ro, offline.Exchange(ro)))
    //         nd, _ := dag.Get(ctx, root); f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         files.WriteTo(f, dir)
    Future<void> extract(String carPath, String dir) async {
      final ro = Go.car.v2.blockstore.openReadOnly(carPath);
      try {
        final dag = Go.boxo.ipld.merkledag.newDagService(Go.boxo.blockservice
            .new$(ro, Go.boxo.exchange.offline.exchange(ro)));
        final root = ro.roots().single;
        Go.boxo.files.writeTo(
            await Go.boxo.ipld.unixfs.file
                .newUnixfsFile(ctx, dag, await dag.get(ctx, root)),
            dir);
      } finally {
        ro.close();
      }
    }

    final ro = Go.car.v2.blockstore.openReadOnly(out);
    try {
      final b = await ro.get(ctx, s.root);
      say('\no bloco raiz, lido do CAR: ${b.rawData!.length} bytes');
    } finally {
      ro.close();
    }
    final dir = '${tmp.path}/extracted';
    await extract(out, dir);
    final back = File('$dir/data.bin').readAsBytesSync();
    say('extraí para $dir: ${Directory(dir).listSync().length} entradas; '
        'data.bin é igual: ${_same(back, s.data)}');

    say('\n== Erros comuns\n');
    final notCar = '${tmp.path}/not_a_car.car';
    File(notCar).writeAsStringSync('{"this": "is not a CAR"}');
    await mistake('abrir um arquivo que não é um CAR',
        why: 'o go-car confere o cabeçalho e o recusa',
        instead: 'trate o erro: um CAR que você recebe pode vir de qualquer '
            'lugar',
        action: () => Go.car.v2.openReader(notCar).close());

    // Um byte invertido perto do fim, nos dados de uma folha.
    final good = File(out).readAsBytesSync();
    final corrupted = '${tmp.path}/corrupted.car';
    File(corrupted).writeAsBytesSync(
        Uint8List.fromList(good)..[good.length - 2000] ^= 0xff);
    String inspect(String path, bool check) {
      final r = Go.car.v2.openReader(path);
      try {
        return '${r.inspect(check).blockCount} blocos, sem erro';
      } on GolangException catch (e) {
        return 'erro: ${brief(e)}';
      } finally {
        r.close();
      }
    }

    await silentlyWrong('confiar num CAR porque o inspect(false) o contou',
        why: 'o inspect(false) só lê a estrutura, não os hashes',
        instead: 'inspect(true), o BlockReader ou o `ipfs dag import`, que '
            'conferem cada bloco',
        wrong: () => inspect(corrupted, false),
        right: () => inspect(corrupted, true));

    final unfinished = '${tmp.path}/unfinished.car';
    final rw = Go.car.v2.blockstore.openReadWrite(unfinished, [s.root]);
    await rw.put(ctx, await s.store.get(ctx, s.root));
    await mistake('ler um CAR cujo gravador nunca foi finalizado',
        why: 'o cabeçalho só é gravado pelo finalize()',
        instead: 'finalize() ao terminar (ou discard() para desistir)',
        action: () => Go.car.v2.openReader(unfinished).close());
    rw.discard();

    // Copiar "todos os blocos do blockstore" em vez de percorrer o DAG. Um
    // blockstore guarda os blocos só pelo multihash: o AllKeysChan devolve
    // cada um como um CIDv1 raw, sem o codec com que foi guardado.
    String rootsInside(String path) {
      final r = Go.car.v2.openReader(path);
      try {
        final st = r.inspect(false);
        return 'raízes no CAR: ${st.rootsPresent}, codecs ${st.codecCounts}';
      } finally {
        r.close();
      }
    }

    final byKeys = '${tmp.path}/by_keys.car';
    await silentlyWrong('gravar um CAR a partir do blockstore.allKeysChan()',
        why: 'o blockstore guarda multihashes, não CIDs: todo bloco volta '
            'como raw (0x55), e a raiz dag-pb não é encontrada',
        instead: 'percorra o DAG a partir da raiz (passo 1), ou use o '
            '`ipfs dag export`',
        wrong: () async {
          await writeCar(byKeys, [
            await for (final c in s.store.allKeysChan(ctx))
              await s.store.get(ctx, c),
          ]);
          return rootsInside(byKeys);
        },
        right: () => rootsInside(out));

    // Um CAR sem a 2ª folha de data.bin.
    final dataBin = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final missing = (await s.dag.get(ctx, dataBin)).links()[1].cid!;
    final partial = '${tmp.path}/partial.car';
    await writeCar(partial, [
      for (final b in all)
        if (b.cid != missing) b,
    ]);
    await mistake('extrair os arquivos de um CAR parcial',
        why: 'offline, todo bloco tem de estar no CAR; um não está',
        instead: 'confira antes o que o CAR tem (passos 3-4), ou importe-o '
            'num nó que consiga buscar o resto (lição 16)',
        action: () => extract(partial, '${tmp.path}/out'));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
