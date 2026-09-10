// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `multiformats/go-varint`.
library;

export 'src/varint.dart' show maxLenUvarint63, maxValueUvarint63, uvarintSize, toUvarint, putUvarint, fromUvarint, readVarint, encodeVarint, errOverflow, errUnderflow, errNotMinimal;
