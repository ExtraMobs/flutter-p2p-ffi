// Typed Go errors (0.27.0): the class generated for a sentinel or an error
// type of an exposed package is thrown; every GolangException carries the
// chain's texts, the errno and the links with a class. Needs
// `dart run tool/build.dart`.
import 'dart:io';

import 'package:p2p_ffi/go/boxo/mfs.dart' as mfs;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io/fs.dart' as fs;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/os.dart' as os;
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
  late core.IpfsNode n;
  late context.Context ctx;

  setUpAll(() async {
    await P2pService.start();
    ctx = context.background();
    loader.PluginLoader('')
      ..initialize()
      ..inject();
    tmp = Directory.systemTemp.createTempSync('p2p_ffi_errors_');
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    n = await core.newNode(
        ctx, node.BuildCfg(repo: fsrepo.open('${tmp.path}/repo')));
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
    final e = await thrown(() async => mfs.lookup(n.filesRoot, '/nope'));
    expect(e, isA<fs.ErrNotExist>());
    final g = e as GolangException;
    expect(g.isA<os.ErrNotExist>(), isTrue);
    expect(g.find<os.ErrNotExist>(), isNotNull);
    expect(g.isA<fs.ErrExist>(), isFalse);
    expect(g.errText, 'file does not exist');
    expect('$e', startsWith('fs.ErrNotExist: '));
  });

  test('an error type: its fields, and the errno of the chain', () async {
    final missing = '${tmp.path}/does-not-exist.bin';
    final e = await thrown(() async => os.open(missing));
    expect(e, isA<fs.PathError>());
    final p = e as fs.PathError;
    expect(p.op, 'open');
    expect(p.path, missing);
    // ENOENT on linux and Android, ERROR_FILE_NOT_FOUND on Windows: both 2
    expect(p.errno, 2);
    expect(p.errTexts.length, greaterThan(1));
    expect(p.message, p.errTexts.first);
    // a PathError wrapping "not found" is also errors.Is(err, fs.ErrNotExist)
    // in Go, through Errno.Is; here it is the errno that says it
    expect(p.isA<fs.PathError>(), isTrue);
  });

  test('a typed error without fields: cid.ErrInvalidCid', () async {
    final e = await thrown(() async => cid.decode('not-a-cid'));
    expect(e, isA<cid.ErrInvalidCid>());
    expect((e as GolangException).errTexts.first, contains('invalid cid'));
  });

  test('an error that is only text: GolangException with the chain', () async {
    final api = coreapi.newCoreApi(n);
    final e = await thrown(() => api.key().generate(ctx, 'self'));
    expect(e.runtimeType, GolangException);
    final g = e as GolangException;
    expect(g.causes, isEmpty);
    expect(g.errno, isNull);
    expect(g.errText, contains('self'));
    expect(g.errTexts.first, g.message);
  });
}
