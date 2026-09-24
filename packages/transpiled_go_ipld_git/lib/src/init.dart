// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/init.go.
import 'package:transpiled_ipld_prime/codec.dart' as ipld_prime;

import 'marshal.dart';
import 'unmarshal.dart';

/// Registers the git-raw multicodec (0x78) encoder and decoder in [registry] or [ipld_prime.defaultRegistry].
void registerGitCodec([ipld_prime.Registry? registry]) {
  final target = registry ?? ipld_prime.defaultRegistry;
  target.registerEncoder(0x78, encode);
  target.registerDecoder(0x78, decode);
}
