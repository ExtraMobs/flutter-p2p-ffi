// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Deprecated Bitswap wantlist forwarding API.
@Deprecated('Use bitswap/client/wantlist instead')
library;

export '../src/bitswap/wantlist/forward.dart'
    show Entry, Wantlist, refEntry, wantlist;
