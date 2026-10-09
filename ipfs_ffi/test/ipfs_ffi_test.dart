import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('IpfsNode (em memória)', () {
    late IpfsNode node;
    setUp(() => node = IpfsNode.start());
    tearDown(() {
      try {
        node.stop();
      } on IpfsException {
        // o teste já parou o nó
      }
    });

    test('add e get de bloco', () {
      final data = Uint8List.fromList(utf8.encode('olá ipfs'));
      final cid = node.add(data);
      // bloco raw com sha2-256, como `ipfs block put`
      expect(cid, startsWith('bafkrei'));
      expect(node.get(cid), data);
      expect(node.add(data), cid, reason: 'endereçado por conteúdo');
    });

    test('bloco vazio e bloco de 1 MiB', () {
      expect(node.get(node.add(Uint8List(0))), isEmpty);
      final big = Uint8List.fromList(List.generate(1 << 20, (i) => i * 7));
      expect(node.get(node.add(big)), big);
    });

    test('nós são independentes', () {
      final other = IpfsNode.start();
      final cid = other.add(Uint8List.fromList([1, 2, 3]));
      expect(() => node.get(cid), throwsA(isA<IpfsException>()));
      other.stop();
    });

    test('erros viram IpfsException', () {
      expect(() => node.get('lixo'), throwsA(isA<IpfsException>()));
      node.stop();
      expect(node.stop, throwsA(isA<IpfsException>()));
      expect(() => node.add(Uint8List(1)), throwsA(isA<IpfsException>()));
    });
  });

  group('ipfsRun (CLI do kubo)', () {
    test('version sai com 0 e comando inválido não', () {
      expect(ipfsRun(['version']), 0);
      expect(ipfsRun(['comando-que-nao-existe']), isNot(0));
    });
  });

  group('IpfsDaemon', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ipfs_ffi_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('init, API RPC, add/cat e shutdown', () async {
      final repo = '${dir.path}/repo';
      // perfil test: portas aleatórias em 127.0.0.1 e sem bootstrap
      var d = await IpfsDaemon.start(repo, initArgs: ['--profile=test']);
      final id = await d.rpc('id') as Map;
      expect(id['ID'], startsWith('12D3KooW'));

      final added = await d.rpc('add', file: utf8.encode('conteúdo')) as Map;
      final client = HttpClient();
      final res = await (await client
              .postUrl(d.api.resolve('cat?arg=${added['Hash']}')))
          .close();
      expect(await res.transform(utf8.decoder).join(), 'conteúdo');
      client.close();
      expect(await d.stop(), 0);

      // um daemon por processo: o segundo falha sem derrubar o processo
      await expectLater(
        IpfsDaemon.start(repo),
        throwsA(isA<IpfsException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
