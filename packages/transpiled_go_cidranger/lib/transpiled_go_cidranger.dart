// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `github.com/libp2p/go-cidranger` (v1.1.0, revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md): CIDR-block containment lookups via a
/// path-compressed trie, plus the module's own `net` subpackage of IP/CIDR
/// byte-level helpers (`rnet` in the upstream import aliasing).
///
/// Both Go packages live under this single module's `go.mod`, so both map
/// onto this one Dart package, split across `part` files sharing one
/// library so the internal factories below can redirect to private
/// implementation classes declared in other files (Dart privacy is
/// per-library, not per-package -- unlike Go's same-package unexported
/// identifiers).
///
/// Go stdlib's `net.IP` / `net.IPNet` (imported here as `net`, aliased
/// `rnet` for the module's own `net` subpackage) are stood in for by
/// `package:boilerplate/net/golang.dart`'s `Ip` / `IpNet`, the same
/// faithful port already used by `transpiled_multiaddr`'s `manet` and by
/// `transpiled_libp2p`'s `conngater.dart` -- see that file's header for
/// why it, and not `dart:io`'s `InternetAddress`, is the correct stand-in
/// (IPv4-mapped folding on containment and comparison). Every place Go
/// takes/returns `net.IP` (`Ranger.Contains`, `RangerEntry.Network`'s
/// address, `rnet.NewNetworkNumber`, ...) or `net.IPNet`
/// (`RangerEntry.Network`, `Ranger.CoveredNetworks`, `NewBasicRangerEntry`,
/// ...) takes/returns `Ip` / `IpNet` here.
///
/// [Ranger.brute]'s Go counterpart, `newBruteRanger`, is unexported
/// upstream (used only by go-cidranger's own same-package test suite as
/// the ground-truth comparator for the trie implementation). This port's
/// parity tests reuse that exact technique but Dart has no
/// same-package-only visibility to grant a test file instead, so the
/// brute-force `Ranger` lives as the public `BruteRanger` class in its own
/// library file, `src/brute_ranger.dart`, deliberately **not** `part`-ed
/// into (or exported from) this barrel -- visible within the package via a
/// direct `package:transpiled_go_cidranger/src/brute_ranger.dart` import
/// (as this package's own tests do), never through the public API surface
/// (AGENTS.md's "Nível de visibilidade" Cenário D: the next-lower-compatible
/// visibility for a Go-unexported symbol this port still needs to reach).
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/net/golang.dart';

part 'src/net/network_number.dart';
part 'src/net/network.dart';
part 'src/ranger.dart';
part 'src/trie.dart';
part 'src/version_ranger.dart';
