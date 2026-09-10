import 'package:test/test.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';

void main() {
  test('zero BuildCfg is offline like Kubo', () {
    final cfg = BuildCfg();
    expect(cfg.online, isFalse);
    expect(cfg.config.offline, isTrue);
    expect(cfg.shutdownTimeout, Duration.zero);
  });

  test('Online is independent from the repository configuration', () {
    final cfg = BuildCfg(config: const IpfsConfig(offline: false));
    expect(cfg.online, isFalse);
    expect(cfg.config.offline, isTrue);
  });

  test('online and ExtraOpts preserve Kubo field semantics', () {
    final options = <String, bool>{'pubsub': true};
    final cfg = BuildCfg(online: true, extraOpts: options);
    options['ipnsps'] = true;
    expect(cfg.config.offline, isFalse);
    expect(cfg.extraOpts, {'pubsub': true, 'ipnsps': true});
  });

  test('nil ExtraOpts reads as false and durations preserve their value', () {
    final zero = BuildCfg();
    final negative = BuildCfg(shutdownTimeout: const Duration(seconds: -1));
    expect(zero.extraOpts['pubsub'] ?? false, isFalse);
    expect(negative.shutdownTimeout, const Duration(seconds: -1));
  });

  test('fromBuildCfg creates and closes an offline node once', () async {
    final node = await IpfsNode.fromBuildCfg(BuildCfg());
    expect(node.isOnline, isFalse);
    final first = node.close();
    final second = node.close();
    expect(identical(first, second), isTrue);
    await first;
  });
}
