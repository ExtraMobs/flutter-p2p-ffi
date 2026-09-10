// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Codec interfaces shared by IPLD encoders and decoders.
library;

export 'src/codec/api.dart'
    show BudgetExhaustedException, Decoder, Encoder, MapSortMode;
export 'src/codec/json/codec.dart'
    show decode, encode, JsonCodecException, registerJsonCodec;
export 'src/codec/raw/codec.dart' show registerRawCodec;
export 'src/multicodec/registry.dart';
