@Tags(['p0'])
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:transpiled_go_codec_dagpb/transpiled_go_codec_dagpb.dart'
    hide decode, encode;
import 'package:transpiled_go_dag_jose/transpiled_go_dag_jose.dart'
    as go_dag_jose;
import 'package:transpiled_go_ipld_git/transpiled_go_ipld_git.dart'
    as go_ipld_git;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';
import 'package:transpiled_multicodec/transpiled_multicodec.dart';

import '../lib/local_kubo_harness.dart';

void main() {
  setUpAll(() {
    // Pre-register all IPLD codecs in defaultRegistry matching Kubo's preload plugins
    registerDagPbCodec();
    go_ipld_git.registerGitCodec();
    go_dag_jose.registerDagJoseCodec();
  });

  group('IPLD Codecs Interoperability with Kubo', () {
    test(
      'Roundtrip and serving for all 8 standard Kubo codecs (raw, dag-pb, dag-cbor, cbor, dag-json, json, git-raw, dag-jose)',
      () async {
        final executable = await LocalKuboHarness.findExecutable();
        if (executable == null) {
          markTestSkipped(
            'Kubo executable not found; set IPFS_EXECUTABLE or add ipfs to PATH',
          );
          return;
        }

        LocalKuboHarness? kubo;
        IpfsNode? node;

        try {
          kubo = await LocalKuboHarness.start(executable: executable);
          final kuboVersion = await kubo.version();

          node = await IpfsNode.fromBuildCfg(
            BuildCfg(
              online: true,
              config: const IpfsConfig(
                offline: false,
                network: NetworkConfig(
                  listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
                  bootstrapPeers: [],
                ),
              ),
            ),
          );

          expect(node.isOnline, isTrue);
          final dartSwarmAddr = node.swarmAddresses.first;

          // Connect swarm between Dart node and local Kubo
          await node.connect(addrInfoFromString(kubo.swarmAddress));
          await kubo.swarmConnect(dartSwarmAddr);

          // 1. Raw (0x55)
          final rawBytes = Uint8List.fromList(utf8.encode('interop raw test data'));
          final rawCid = Cid.computeForDataSync(rawBytes, codec: 'raw');
          await _verifyCodecRoundtrip(node, kubo, rawCid, rawBytes);

          // 2. DAG-PB (0x70)
          final pbNode = _makeSampleDagPbNode('interop dag-pb payload');
          final pbBytes = appendEncode(Uint8List(0), pbNode);
          final pbCid = Cid.computeForDataSync(pbBytes, codec: 'dag-pb');
          await _verifyCodecRoundtrip(node, kubo, pbCid, pbBytes);

          // 3. DAG-CBOR (0x71)
          final sampleMapNode = _makeSampleMapNode('hello dag-cbor');
          final cborBytes = _encodeWithRegistry(0x71, sampleMapNode);
          final cborCid = Cid.computeForDataSync(cborBytes, codec: 'dag-cbor');
          await _verifyCodecRoundtrip(node, kubo, cborCid, cborBytes);

          // 4. CBOR (0x51)
          final cborStdBytes = _encodeWithRegistry(0x51, sampleMapNode);
          final cborStdCid = Cid.computeForDataSync(cborStdBytes, codec: 'cbor');
          await _verifyCodecRoundtrip(node, kubo, cborStdCid, cborStdBytes);

          // 5. DAG-JSON (0x0129)
          final dagJsonBytes = _encodeWithRegistry(0x0129, sampleMapNode);
          final dagJsonCid = Cid.computeForDataSync(dagJsonBytes, codec: 'dag-json');
          await _verifyCodecRoundtrip(node, kubo, dagJsonCid, dagJsonBytes);

          // 6. JSON (0x0200)
          final jsonBytes = _encodeWithRegistry(0x0200, sampleMapNode);
          final jsonCid = Cid.computeForDataSync(jsonBytes, codec: 'json');
          await _verifyCodecRoundtrip(node, kubo, jsonCid, jsonBytes);

          // 7. Git-Raw (0x78)
          final gitContent = utf8.encode('interop git-raw blob content');
          final gitBlob = Uint8List.fromList([
            ...utf8.encode('blob ${gitContent.length}\x00'),
            ...gitContent,
          ]);
          final gitSha = Uint8List.fromList(crypto.sha1.convert(gitBlob).bytes);
          final gitCid = go_ipld_git.shaToCid(gitSha);
          await _verifyCodecRoundtrip(node, kubo, gitCid, gitBlob);

          // 8. DAG-JOSE (0x85)
          final josePayload = rawCid.bytes();
          final jwsMap = prototype.map.newBuilder();
          final jwsMa = jwsMap.beginMap(2);
          jwsMa.assembleKey().assignString('payload');
          jwsMa.assembleValue().assignBytes(josePayload);
          jwsMa.assembleKey().assignString('signatures');
          final la = jwsMa.assembleValue().beginList(1);
          final sigMa = la.assembleValue().beginMap(1);
          sigMa.assembleKey().assignString('signature');
          sigMa.assembleValue().assignBytes(Uint8List.fromList([1, 2, 3, 4]));
          sigMa.finish();
          la.finish();
          jwsMa.finish();
          final jwsNode = jwsMap.build();

          final joseBytes = _encodeWithRegistry(0x85, jwsNode);
          final joseCid = Cid.computeForDataSync(joseBytes, codec: 'dag-jose');
          await _verifyCodecRoundtrip(node, kubo, joseCid, joseBytes);

          expect(rawCid.codec, equals('raw'));
          expect(pbCid.codec, equals('dag-pb'));
          expect(cborCid.codec, equals('dag-cbor'));
          expect(cborStdCid.codec, equals('cbor'));
          expect(dagJsonCid.codec, equals('dag-json'));
          expect(jsonCid.codec, equals('json'));
          expect(gitCid.codec, equals('git-raw'));
          expect(joseCid.codec, equals('dag-jose'));

          printOnFailure('CIDs comprovados para todos os formatos:');
          printOnFailure('  raw (0x55):      $rawCid');
          printOnFailure('  dag-pb (0x70):   $pbCid');
          printOnFailure('  dag-cbor (0x71): $cborCid');
          printOnFailure('  cbor (0x51):     $cborStdCid');
          printOnFailure('  dag-json (0x129): $dagJsonCid');
          printOnFailure('  json (0x200):    $jsonCid');
          printOnFailure('  git-raw (0x78):  $gitCid');
          printOnFailure('  dag-jose (0x85): $joseCid');
          printOnFailure('All 8 codecs successfully verified with Kubo $kuboVersion');
        } finally {
          if (node != null) await node.close();
          await kubo?.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

Uint8List _encodeWithRegistry(int codecIndicator, Node node) {
  final encoder = defaultRegistry.lookupEncoder(codecIndicator);
  final sink = <List<int>>[];
  encoder(node, StreamControllerSink(sink.add));
  return Uint8List.fromList(sink.expand((e) => e).toList());
}

Future<void> _verifyCodecRoundtrip(
  IpfsNode node,
  LocalKuboHarness kubo,
  Cid cid,
  Uint8List blockBytes,
) async {
  // 1. Put block in Dart node local blockstore
  final block = BasicBlock(blockBytes, cid);
  await node.putBlock(block);

  // 2. Fetch block in Kubo via Bitswap
  final downloadedBytes = await kubo.getRawBlock(cid.toString());
  expect(downloadedBytes, orderedEquals(blockBytes), reason: 'Kubo downloaded bytes for ${cid.codec}');

  // 3. Decode with Dart registered decoder
  final codecCode = Multicodec.code(cid.codec);
  final decoder = defaultRegistry.lookupDecoder(codecCode);
  expect(decoder, isNotNull);
  final builder = prototype.any.newBuilder();
  decoder(builder, blockBytes);
  final decodedNode = builder.build();
  expect(decodedNode, isNotNull);
}

Node _makeSampleMapNode(String greeting) {
  final builder = prototype.map.newBuilder();
  final ma = builder.beginMap(1);
  ma.assembleKey().assignString('greeting');
  ma.assembleValue().assignString(greeting);
  ma.finish();
  return builder.build();
}

Node _makeSampleDagPbNode(String text) {
  final builder = prototype.map.newBuilder();
  final ma = builder.beginMap(2);
  ma.assembleKey().assignString('Data');
  ma.assembleValue().assignBytes(Uint8List.fromList(utf8.encode(text)));
  ma.assembleKey().assignString('Links');
  final la = ma.assembleValue().beginList(0);
  la.finish();
  ma.finish();
  return builder.build();
}

class StreamControllerSink<T> implements Sink<T> {
  StreamControllerSink(this._onAdd);

  final void Function(T) _onAdd;

  @override
  void add(T data) => _onAdd(data);

  @override
  void close() {}
}
