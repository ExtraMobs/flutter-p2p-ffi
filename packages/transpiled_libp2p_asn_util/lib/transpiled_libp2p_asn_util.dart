// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `github.com/libp2p/go-libp2p-asn-util` (v0.4.1, revision fixed
/// in doc/transpilation/UPSTREAM_LOCK.md): an offline AS-number lookup for
/// IPv6 addresses, backed by a sorted list of (start, end, ASN) ranges.
///
/// Go embeds `sorted-network-list.bin` directly via `//go:embed`; this
/// port instead bakes it into a generated Dart source file
/// (`src/embedded_data.dart`, produced by `tool/generate_embedded.dart`)
/// as a base64 string decoded once into a `Uint8List`, so it works
/// without `dart:io` on every platform this project targets, web
/// included.
///
/// Go stdlib's `net.IP` is stood in for by
/// `package:boilerplate/net/golang.dart`'s `Ip` (see asn.dart's header for
/// why, not `dart:io`'s `InternetAddress`, is the correct stand-in).
///
/// go-libp2p-asn-util's exported `Store` variable (of unexported type
/// `backwardCompat`) is ported as [BackwardCompat]/`store` in the sibling
/// `src/asn_store.dart`, deliberately **not** `part`-ed into or exported
/// from this barrel -- see that file's header for why (AGENTS.md's "Nível
/// de visibilidade" Cenário D).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/net/golang.dart';

// Go: `var Store backwardCompat` é exportada; só o tipo `backwardCompat`
// não é. `store` sai no barril, `BackwardCompat` fica em `src/`.
export 'src/asn_store.dart' show store;

part 'src/embedded_data.dart';
part 'src/asn.dart';
