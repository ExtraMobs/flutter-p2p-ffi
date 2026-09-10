// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/multiaddr/dns_resolver.dart
//
// Port of go-multiaddr-dns's Resolver orchestration
// (github.com/multiformats/go-multiaddr-dns resolve.go, util.go, mock.go):
// walks a `/dns4/`, `/dns6/`, `/dns/`, or `/dnsaddr/` component out of a
// Multiaddr and replaces it with the addresses a [BasicResolver] returns.
//
// This is the pure orchestration layer only -- it takes a [BasicResolver]
// as a dependency rather than performing lookups itself, so it's fully
// testable with [MockResolver] (this file's own port of go-multiaddr-dns's
// mock.go) without any real network or platform I/O. A concrete resolver
// backed by actual DNS (system resolver for A/AAAA, plus a DNS client
// capable of TXT lookups for `/dnsaddr/`, which `dart:io` doesn't expose)
// is deliberately a separate, later step -- see
// doc/transpilation/PROGRESS.md's go-multiaddr-dns row -- and lives outside
// transpiled_multiaddr_dns, which stays free of `dart:io` for web compatibility.
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// A low-level DNS resolution dependency. Equivalent to go-multiaddr-dns's
/// `BasicResolver` interface. Implementations return resolved addresses as
/// plain text (dotted-decimal IPv4 or colon-form IPv6) rather than a typed
/// IP-address value, so this file has no `dart:io` dependency.
abstract class BasicResolver {
  /// Resolves [name] to zero or more IPv4/IPv6 address strings.
  Future<List<String>> lookupIpAddr(String name);

  /// Resolves the TXT records for [name].
  Future<List<String>> lookupTxt(String name);
}

/// A [BasicResolver] backed by fixed maps, for tests. Equivalent to
/// go-multiaddr-dns's `MockResolver`.
class MockResolver implements BasicResolver {
  /// Builds a resolver returning [ip]/[txt] for exactly the names present
  /// as keys, and an empty list for every other name.
  MockResolver({Map<String, List<String>>? ip, Map<String, List<String>>? txt})
    : ip = ip ?? const {},
      txt = txt ?? const {};

  /// Domain name -> fixed IPv4/IPv6 address strings.
  final Map<String, List<String>> ip;

  /// Domain name -> fixed TXT record values.
  final Map<String, List<String>> txt;

  @override
  Future<List<String>> lookupIpAddr(String name) async => ip[name] ?? const [];

  @override
  Future<List<String>> lookupTxt(String name) async => txt[name] ?? const [];
}

/// Checks if [s] is a fully qualified domain name: ends with an unescaped
/// dot. A run of trailing backslashes immediately before that dot escapes
/// it only when the run's length is odd (each pair of backslashes is one
/// literal backslash; a leftover single backslash escapes the dot).
bool isFqdn(String s) {
  if (s.isEmpty || !s.endsWith('.')) return false;
  final trimmed = s.substring(0, s.length - 1);
  if (trimmed.isEmpty || !trimmed.endsWith('\\')) return true;
  var i = trimmed.length;
  while (i > 0 && trimmed[i - 1] == '\\') {
    i--;
  }
  final backslashCount = trimmed.length - i;
  return backslashCount % 2 == 0;
}

/// Returns the fully qualified form of [s] (a trailing dot appended, unless
/// already present).
String fqdn(String s) => isFqdn(s) ? s : '$s.';

int get _dnsaddrCode => Protocols.dnsaddr;
int get _dns4Code => Protocols.dns4;
int get _dns6Code => Protocols.dns6;
int get _dnsCode => Protocols.dns;

/// Whether [maddr] contains a `/dns4/`, `/dns6/`, `/dns/`, or `/dnsaddr/`
/// component. Equivalent to go-multiaddr-dns's `Matches`.
bool dnsMatches(Multiaddr maddr) {
  var matches = false;
  maddr.forEach((c) {
    final code = c.protocol.code;
    if (code == _dnsCode ||
        code == _dns4Code ||
        code == _dns6Code ||
        code == _dnsaddrCode) {
      matches = true;
    }
    return !matches;
  });
  return matches;
}

const int _maxResolvedAddrs = 100;
const String _dnsaddrTXTPrefix = 'dnsaddr=';

int _componentCount(Multiaddr maddr) {
  var n = 0;
  maddr.forEach((_) {
    n++;
    return true;
  });
  return n;
}

/// Trims [count] components from the beginning of [maddr].
Multiaddr _dropFirst(Multiaddr maddr, int count) {
  var remaining = count;
  final (_, after) = maddr.splitFunc((c) {
    if (remaining == 0) return true;
    remaining--;
    return false;
  });
  return after ?? Multiaddr.empty;
}

/// Resolves `/dns4/`, `/dns6/`, `/dns/`, and `/dnsaddr/` components in a
/// [Multiaddr] using one or more [BasicResolver]s, with optional per-domain
/// overrides. Equivalent to go-multiaddr-dns's `Resolver`.
class Resolver implements BasicResolver {
  /// Builds a resolver falling back to [defaultResolver] for any domain
  /// without a more specific one added via [withDomainResolver].
  Resolver({BasicResolver? defaultResolver})
    : _default = defaultResolver,
      _custom = {};

  BasicResolver? _default;
  final Map<String, BasicResolver> _custom;

  /// Registers [resolver] as the resolver for [domain] and its
  /// subdomains, matching left-to-right (a resolver registered for
  /// `custom.test` also serves `another.custom.test` unless a more
  /// specific resolver is registered for that name too). Equivalent to
  /// go-multiaddr-dns's `WithDomainResolver` option.
  void withDomainResolver(String domain, BasicResolver resolver) {
    _custom[fqdn(domain)] = resolver;
  }

  /// Sets the fallback resolver used for any domain without a more
  /// specific one registered via [withDomainResolver]. Equivalent to
  /// go-multiaddr-dns's `WithDefaultResolver` option.
  void withDefaultResolver(BasicResolver resolver) {
    _default = resolver;
  }

  BasicResolver _resolverFor(String domain) {
    var name = fqdn(domain);
    final direct = _custom[name];
    if (direct != null) return direct;

    var dot = name.indexOf('.');
    while (dot != -1) {
      name = name.substring(dot + 1);
      if (name.isEmpty) break; // the "." is the default resolver.
      final match = _custom[name];
      if (match != null) return match;
      dot = name.indexOf('.');
    }

    final def = _default;
    if (def == null) {
      throw StateError('Resolver has no default BasicResolver configured');
    }
    return def;
  }

  @override
  Future<List<String>> lookupIpAddr(String name) =>
      _resolverFor(name).lookupIpAddr(name);

  @override
  Future<List<String>> lookupTxt(String name) =>
      _resolverFor(name).lookupTxt(name);

  /// Resolves the first `/dns4/`, `/dns6/`, `/dns/`, or `/dnsaddr/`
  /// component in [maddr]. Call again on each returned address to resolve
  /// further DNS components. Equivalent to go-multiaddr-dns's
  /// `Resolver.Resolve`.
  Future<List<Multiaddr>> resolve(Multiaddr? maddr) async {
    if (maddr == null) return const [];

    final (preDNS, rest) = maddr.splitFunc((c) {
      final code = c.protocol.code;
      return code == _dnsCode ||
          code == _dns4Code ||
          code == _dns6Code ||
          code == _dnsaddrCode;
    });

    if (rest == null) {
      return [preDNS];
    }

    final (first, postDNS) = rest.splitFirst();
    final resolve = first!;
    final code = resolve.protocol.code;
    final value = resolve.value;
    final rslv = _resolverFor(value);

    var resolved = <Multiaddr>[];
    if (code == _dns4Code || code == _dns6Code || code == _dnsCode) {
      final v4only = code == _dns4Code;
      final v6only = code == _dns6Code;

      final records = await rslv.lookupIpAddr(value);
      for (final ip in records) {
        final isV6 = ip.contains(':');
        if (isV6) {
          if (v4only) continue;
          resolved.add(Multiaddr.parse('/ip6/$ip'));
        } else {
          if (v6only) continue;
          resolved.add(Multiaddr.parse('/ip4/$ip'));
        }
      }
    } else if (code == _dnsaddrCode) {
      final records = await rslv.lookupTxt('_dnsaddr.$value');

      final length = postDNS == null ? 0 : _componentCount(postDNS);

      for (final r in records) {
        if (!r.startsWith(_dnsaddrTXTPrefix)) continue;

        Multiaddr rmaddr;
        try {
          rmaddr = Multiaddr.parse(r.substring(_dnsaddrTXTPrefix.length));
        } on FormatException {
          continue; // discard multiaddrs we don't understand.
        }

        if (postDNS != null) {
          final rmlen = _componentCount(rmaddr);
          if (rmlen < length) continue;
          if (_dropFirst(rmaddr, rmlen - length) != postDNS) continue;
        }

        final trimmed = postDNS != null
            ? rmaddr.decapsulate(postDNS)
            : rmaddr;
        resolved.add(trimmed);
      }
    } else {
      throw StateError('unreachable: unexpected protocol code $code');
    }

    if (resolved.isEmpty) return const [];
    if (resolved.length > _maxResolvedAddrs) {
      resolved = resolved.sublist(0, _maxResolvedAddrs);
    }

    if (preDNS.components.isNotEmpty) {
      resolved = [for (final m in resolved) preDNS.encapsulate(m)];
    }
    if (postDNS != null) {
      resolved = [for (final m in resolved) m.encapsulate(postDNS)];
    }
    return resolved;
  }
}
