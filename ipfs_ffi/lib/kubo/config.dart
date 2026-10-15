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
final class Identity implements GoDto {
  Identity({String? peerId, String? privKey})
      : peerId = peerId ?? '',
        privKey = privKey ?? '';

  Identity.$dec($R r)
      : peerId = r.str(),
        privKey = r.str();

  /// Go: `PeerID`.
  String peerId;

  /// Go: `PrivKey`.
  String privKey;

  @override
  void $enc($W w) {
    w
      ..str(peerId)
      ..str(privKey);
  }
}

/// Go: `func config.CreateIdentity(out io.Writer, opts []options.KeyGenerateOption) (config.Identity, error)`.
Identity createIdentity(List<$options.KeyGenerateOption> opts) {
  final $r = $callSync(80, $W()..list(opts, (w0, e0) => w0.opt(e0)));
  return $r.p() ? Identity.$dec($r) : $nil();
}

/// Go: `func config.InitWithIdentity(identity config.Identity) (*config.Config, error)`.
Config initWithIdentity(Identity identity) {
  final $r = $callSync(81, $W()..dto(identity));
  return $r.p() ? Config($r.json()) : $nil();
}

/// Go: `var config.Profiles map[string]config.Profile`. Escrito à mão
/// (go/gen/extra; funções 40 e 41 do WIRE.md): no Go o perfil é uma função
/// `Transform`. Lido no primeiro uso, com o serviço já iniciado.
final Map<String, Profile> profiles = () {
  final r = $callSync(40);
  return {for (final name in r.list(r.str)) name: Profile._(name)};
}();

/// Go: `config.Profile`.
final class Profile {
  Profile._(this._name);

  final String _name;

  /// Go: `Transform(c *Config) error`: aplica o perfil a [c].
  void transform(Config c) {
    final r = $callSync(
            41,
            $W()
              ..str(_name)
              ..jsonStr(c.json))
        .json();
    c.json
      ..clear()
      ..addAll(r);
  }
}
