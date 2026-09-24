// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-dag-jose/dagjose/multicodec.go.

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'jose_decode.dart';
import 'jose_encode.dart';

/// Multicodec indicator code for DAG-JOSE (0x85).
const int dagJoseCodecCode = 0x85;

/// Registers DAG-JOSE (multicodec 0x85) in [registry].
void registerDagJoseCodec([Registry? registry]) {
  final target = registry ?? defaultRegistry;
  target.registerEncoder(dagJoseCodecCode, encode);
  target.registerDecoder(dagJoseCodecCode, decode);
}
