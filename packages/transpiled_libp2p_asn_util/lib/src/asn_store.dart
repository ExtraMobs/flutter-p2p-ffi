// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Port of github.com/libp2p/go-libp2p-asn-util/asn.go's exported `Store`
// variable and its unexported `backwardCompat` struct (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// `Store backwardCompat` is exported and carries Go's own
// `// Deprecated:` marker; `backwardCompat` itself is unexported. Per
// AGENTS.md's "Nível de visibilidade" Cenário D, the next-lower-compatible
// visibility for a Go-unexported type reached through an exported member
// is: a public name (here [BackwardCompat], matching the Go type modulo
// casing) declared under `lib/src/`, deliberately **not** `part`-ed into
// or exported from `transpiled_libp2p_asn_util.dart` -- visible only via
// a direct
// `package:transpiled_libp2p_asn_util/src/asn_store.dart` import (as this
// package's own tests do), never through the public barrel. [store]
// itself stays reachable that same way, since it's typed by the
// not-barrel-exported [BackwardCompat].
//
// A standalone library (rather than a `part of` file) is required to make
// that omission possible at all: a `part` file shares its enclosing
// library wholesale and can't be selectively left out of it.
library;

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:boilerplate/net/golang.dart';

import '../transpiled_libp2p_asn_util.dart';

/// The AS number for [ip] as a decimal string, or `''` if none is known.
/// Throws an exception if [ip] is not IPv6-capable (see
/// [_UnsupportedIpVersionException]). Equivalent to go-libp2p-asn-util's
/// `backwardCompat.AsnForIPv6`.
///
/// Neither this class nor its methods carry Go's own `// Deprecated:`
/// marker -- only the [store] singleton value does -- so this class and
/// its methods are left unmarked too, per this project's rule against
/// inventing `@Deprecated` annotations the upstream symbol doesn't have.
class BackwardCompat {
  const BackwardCompat._();

  /// The AS number for [ip] as a decimal string, or `''` if none is
  /// known. Throws [_UnsupportedIpVersionException] if [ip] is not
  /// IPv6-capable (Go: `ip.To16()` is nil -- reachable here since [Ip]
  /// can hold a byte slice of any length, exactly like Go's `net.IP`,
  /// unlike `dart:io`'s always-4-or-16-byte `InternetAddress`). Equivalent
  /// to go-libp2p-asn-util's `backwardCompat.AsnForIPv6`.
  String asnForIpv6(Ip ip) {
    final v6 = ip.to16();
    if (v6 == null) throw const _UnsupportedIpVersionException();
    // Go's `backwardCompat.AsnForIPv6` inlines `binary.BigEndian.Uint64`
    // itself rather than delegating to a shared helper -- the top-level
    // `AsnForIPv6` does the same in its own body -- so this reproduces
    // that same small read rather than reaching into asn.dart's private
    // `_networkPrefix`.
    final bytes = v6.asBytes();
    var network = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      network = (network << 8) | BigInt.from(bytes[i]);
    }
    final asn = asnForIpv6Network(Golang.Uint64.fromBigInt(network));
    return asn == 0 ? '' : asn.toString();
  }

  /// A documented no-op, exactly as upstream's own `backwardCompat.Init`
  /// is. Equivalent to go-libp2p-asn-util's `backwardCompat.Init`.
  void init() {}
}

/// Thrown by [BackwardCompat.asnForIpv6] when [Ip] is not IPv6-capable.
/// Equivalent to the anonymous `errors.New("ONLY IPv6 addresses
/// supported")` go-libp2p-asn-util's `backwardCompat.AsnForIPv6` returns:
/// Go's own `errors.New` result is itself an *unexported* `*errorString`
/// value, so keeping this exception Dart-private (rather than inventing a
/// public name with no upstream symbol to answer to, which the AST
/// auditor's Rule 12 rejects) is the more faithful visibility, not a
/// concession -- callers observe it only via its message, exactly as a Go
/// caller of `backwardCompat.AsnForIPv6` observes only `err.Error()`.
class _UnsupportedIpVersionException implements Exception {
  /// Creates the exception.
  const _UnsupportedIpVersionException();
  @override
  String toString() => 'ONLY IPv6 addresses supported';
}

/// Deprecated legacy singleton wrapper kept only for upstream parity.
/// Equivalent to go-libp2p-asn-util's `Store` package variable (of type
/// `backwardCompat`).
// Deprecated: use [asnForIpv6] or [asnForIpv6Network], they do not
// allocate.
@Deprecated('use asnForIpv6 or asnForIpv6Network, they do not allocate')
const BackwardCompat store = BackwardCompat._();
