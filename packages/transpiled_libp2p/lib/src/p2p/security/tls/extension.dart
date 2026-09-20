// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/security/tls/extension.dart
//
// Port of go-libp2p's p2p/security/tls/extension.go: the private
// enterprise OID prefix under which the libp2p TLS certificate extension
// lives, and the helpers crypto.dart uses to build and compare extension
// OIDs.
//
// All three symbols here (`extensionPrefix`, `getPrefixedExtensionID`,
// `extensionIDEqual`) are unexported in Go -- used only within the
// `libp2ptls` package, which spans both extension.go and crypto.go. Dart
// has no package-scoped privacy (only file-scoped, via `_name`), and this
// project does not otherwise use `part`/`part of` to bridge that gap, so
// these are kept public here -- the only way for crypto.dart (a separate
// library) to reach them -- rather than merging both Go files into one
// Dart file. This also lets go-libp2p's own extension_test.go vectors be
// reused directly as atomic tests instead of only exercised indirectly.

/// The private enterprise number IANA assigned to the libp2p project
/// (53594), under `1.3.6.1.4.1` (`iso.org.dod.internet.private.enterprise`),
/// per go-libp2p's `extensionPrefix` (extension.go:3).
const List<int> extensionPrefix = [1, 3, 6, 1, 4, 1, 53594];

/// Returns an Object Identifier under [extensionPrefix] that can be used
/// in X.509 certificates, per go-libp2p's `getPrefixedExtensionID`
/// (extension.go:5-9).
List<int> getPrefixedExtensionId(List<int> suffix) => [...extensionPrefix, ...suffix];

/// Compares two extension IDs for structural equality, per go-libp2p's
/// `extensionIDEqual` (extension.go:11-22).
bool extensionIdEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
