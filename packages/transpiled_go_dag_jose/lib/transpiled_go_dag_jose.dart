// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `github.com/ceramicnetwork/go-dag-jose/dagjose`.
///
/// Implements the DAG-JOSE multicodec (0x85) for JWS and JWE objects encoded
/// into DAG-CBOR.
library;

export 'src/jose_bytes.dart'
    show
        Base64Url,
        Raw,
        decodeBase64Url,
        encodeBase64Url;
export 'src/jose_decode.dart'
    show DecodeOptions, decode, decodeJwe, decodeJws;
export 'src/jose_encode.dart' show encode, encodeJwe, encodeJws;
export 'src/jose_utils.dart'
    show
        isJwe,
        isJws,
        lookupIgnoreAbsent,
        lookupIgnoreNoSuchField,
        parseJose,
        unflattenJwe,
        unflattenJws,
        validateLink;
export 'src/multicodec.dart' show dagJoseCodecCode, registerDagJoseCodec;
