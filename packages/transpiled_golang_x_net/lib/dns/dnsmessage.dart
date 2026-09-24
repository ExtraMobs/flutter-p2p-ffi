// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `golang.org/x/net/dns/dnsmessage` (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md) -- a mostly RFC 1035 compliant
/// implementation of DNS message packing and unpacking, including EDNS(0)
/// (RFC 6891) and SVCB/HTTPS records (RFC 9460).
///
/// `message.go` and `svcb.go` share package-private helpers in upstream Go
/// (both are part of the single `dnsmessage` package), so this port keeps
/// them as `part`/`part of` of one library, mirroring the pattern already
/// used by `packages/transpiled_pion_sdp`.
///
/// Import with the library-named prefix to avoid collisions with identical
/// names in other transpiled Go packages (AGENTS.md rule 25):
/// ```dart
/// import 'package:transpiled_golang_x_net/dns/dnsmessage.dart' as dnsmessage;
/// ```
library;

import 'dart:typed_data';

part '../src/dns/dnsmessage/message.dart';
part '../src/dns/dnsmessage/svcb.dart';
