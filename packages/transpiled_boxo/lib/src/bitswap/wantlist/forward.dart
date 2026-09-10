// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of boxo/bitswap/wantlist/forward.go.
//
// Deprecated: use bitswap/client/wantlist instead.
@Deprecated('Use bitswap/client/wantlist instead')
library;

import 'package:transpiled_cid/transpiled_cid.dart';

import '../client/wantlist/wantlist.dart' as client;

/// Deprecated: use [client.Entry] instead.
@Deprecated('Use client.Entry instead')
typedef Entry = client.Entry;

/// Deprecated: use [client.Wantlist] instead.
@Deprecated('Use client.Wantlist instead')
typedef Wantlist = client.Wantlist;

/// Deprecated: use [client.Wantlist.new] instead.
@Deprecated('Use client.Wantlist instead')
Wantlist wantlist() => client.Wantlist();

/// Deprecated: use [client.Entry.ref] instead.
@Deprecated('Use client.Entry.ref instead')
Entry refEntry(Cid cid, int priority) => client.Entry.ref(cid, priority);
