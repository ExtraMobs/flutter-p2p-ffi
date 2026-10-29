// Typed Go errors (0.27.0): the class generated for a sentinel or an error
// type of an exposed package is thrown; every GolangException carries the
// chain's texts, the errno and the links with a class. Needs
// `dart run tool/build.dart`.
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

/// What [f] throws.
Future<Object> thrown(Future<Object?> Function() f) async {
  try {
    await f();
  } on Object catch (e) {
    return e;
  }
  fail('nothing was thrown');
}

void main() {
  late Directory tmp;
  late KuboCoreIpfsNode n;
  late Context ctx;

  setUpAll(() async {
    await P2pService.start();
    ctx = go.context.background();
    KuboPluginLoader('')
      ..initialize()
      ..inject();
    tmp = Directory.systemTemp.createTempSync('p2p_ffi_errors_');
    final cfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
        .createIdentity(
            null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
    go.ipfs.kubo.config.profiles['test']!.transform(cfg);
    go.ipfs.kubo.repo.fsrepo.init('${tmp.path}/repo', cfg);
    n = await go.ipfs.kubo.core.newNode(
        ctx,
        KuboCoreNodeBuildCfg(
            repo: go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/repo')));
  });
  tearDownAll(() async {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('a sentinel: its class is thrown, and every name of the same value',
      () async {
    // mfs answers a missing path with os.ErrNotExist, which is
    // fs.ErrNotExist: both classes are in the chain
    final e =
        await thrown(() async => go.ipfs.boxo.mfs.lookup(n.filesRoot, '/nope'));
    expect(e, isA<IoFsErrNotExist>());
    final g = e as GolangException;
    expect(g.isA<OsErrNotExist>(), isTrue);
    expect(g.find<OsErrNotExist>(), isNotNull);
    expect(g.isA<IoFsErrExist>(), isFalse);
    expect(g.errText, 'file does not exist');
    expect('$e', startsWith('fs.ErrNotExist: '));
  });

  test('an error type: its fields, and the errno of the chain', () async {
    final missing = '${tmp.path}/does-not-exist.bin';
    final e = await thrown(() async => go.os.open(missing));
    expect(e, isA<IoFsPathError>());
    final p = e as IoFsPathError;
    expect(p.op, 'open');
    expect(p.path, missing);
    // ENOENT on linux and Android, ERROR_FILE_NOT_FOUND on Windows: both 2
    expect(p.errno, 2);
    expect(p.errTexts.length, greaterThan(1));
    expect(p.message, p.errTexts.first);
    // a PathError wrapping "not found" is also errors.Is(err, fs.ErrNotExist)
    // in Go, through Errno.Is; here it is the errno that says it
    expect(p.isA<IoFsPathError>(), isTrue);
  });

  test('a typed error without fields: cid.ErrInvalidCid', () async {
    final e = await thrown(() async => go.ipfs.cid.decode('not-a-cid'));
    expect(e, isA<CidErrInvalidCid>());
    expect((e as GolangException).errTexts.first, contains('invalid cid'));
  });

  test('an error that is only text: GolangException with the chain', () async {
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);
    final e = await thrown(() => api.key().generate(ctx, 'self'));
    expect(e.runtimeType, GolangException);
    final g = e as GolangException;
    expect(g.causes, isEmpty);
    expect(g.errno, isNull);
    expect(g.errText, contains('self'));
    expect(g.errTexts.first, g.message);
  });
}
