// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/bootstrap.dart
//
// Port of go-libp2p-routing-helpers's bootstrap.go.
import 'dart:async';

/// Implemented by any router wishing to be bootstrapped. Equivalent to
/// go-libp2p-routing-helpers's `Bootstrap` interface.
abstract class Bootstrap {
  /// Bootstraps the router.
  Future<void> bootstrap();
}
