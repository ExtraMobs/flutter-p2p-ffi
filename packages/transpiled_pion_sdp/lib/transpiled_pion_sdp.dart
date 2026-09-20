// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `github.com/pion/sdp` v3 (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md) -- Session Description Protocol
/// (RFC 4566) parsing and marshalling.
///
/// This library is split across `lib/src/*.dart` files via `part`/`part of`,
/// mirroring the single Go package `sdp` spread across many upstream files.
/// Go allows package-private (lowercase) identifiers to be shared freely
/// across every file of a package; Dart's equivalent for that is a single
/// library sharing one private namespace via `part`, which is what lets this
/// port keep the same per-concern file layout as upstream while still
/// enforcing this project's rule that symbols without an exported Go
/// counterpart stay Dart-private (`_Name`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_pion_randutil/transpiled_pion_randutil.dart'
    show cryptoUint64;

part 'src/direction.dart';
part 'src/common_description.dart';
part 'src/time_description.dart';
part 'src/session_description.dart';
part 'src/media_description.dart';
part 'src/extmap.dart';
part 'src/base_lexer.dart';
part 'src/unmarshal_cache.dart';
part 'src/util.dart';
part 'src/unmarshal.dart';
part 'src/marshal.dart';
part 'src/jsep.dart';
