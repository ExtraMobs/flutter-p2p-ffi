// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/config
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as $options;

/// Go: `config.Config` (valor).
class Config extends GoJsonValue {
  Config(super.json);
}

/// Go: `config.Identity`.
final class Identity implements GoJson {
  Identity({String? peerId, String? privKey})
      : peerId = peerId ?? '',
        privKey = privKey ?? '';

  Identity.$fromJson(Map<String, Object?> j)
      : peerId = j['PeerID'] as String,
        privKey = j['PrivKey'] as String;

  /// Go: `PeerID`.
  String peerId;

  /// Go: `PrivKey`.
  String privKey;

  @override
  Map<String, Object?> $toJson() =>
      {'PeerID': $enc(peerId), 'PrivKey': $enc(privKey)};
}

/// Go: `func config.CreateIdentity(out io.Writer, opts []options.KeyGenerateOption) (config.Identity, error)`.
Identity createIdentity(List<$options.KeyGenerateOption> opts) {
  final $r = $callSync('github.com/ipfs/kubo/config.CreateIdentity', [opts]);
  return Identity.$fromJson($nn($r) as Map<String, Object?>);
}

/// Go: `func config.InitWithIdentity(identity config.Identity) (*config.Config, error)`.
Config initWithIdentity(Identity identity) {
  final $r =
      $callSync('github.com/ipfs/kubo/config.InitWithIdentity', [identity]);
  return Config($nn($r) as Map<String, Object?>);
}

/// Go: `var config.Profiles map[string]config.Profile`. Escrito à mão
/// (go/gen/extra): no Go o perfil é uma função `Transform`.
final Map<String, Profile> profiles = {
  for (final name
      in ($callSync('config.Profiles', const []) as List).cast<String>())
    name: Profile._(name),
};

/// Go: `config.Profile`.
final class Profile {
  Profile._(this._name);

  final String _name;

  /// Go: `Transform(c *Config) error`: aplica o perfil a [c].
  void transform(Config c) {
    final r = $callSync('config.Profile.Transform', [_name, c])
        as Map<String, Object?>;
    c.json
      ..clear()
      ..addAll(r);
  }
}
