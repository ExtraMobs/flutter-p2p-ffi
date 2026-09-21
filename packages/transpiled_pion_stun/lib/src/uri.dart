/// Port of `uri.go` (pion/stun v3.1.1).
///
/// Go's `URI` type is renamed [StunUri]: Dart's `dart:core` already owns
/// the bare name `Uri` (a class every Dart program can reach unqualified),
/// so keeping the Go name verbatim would either collide or force every
/// consumer to import-prefix this package -- exactly the ambiguity Go
/// callers never hit, since they always see this type qualified as
/// `stun.URI` (there is no bare `URI` in Go's own namespace either).
/// Folding the package name into the identifier is the same disambiguation
/// this project already applies elsewhere for cross-module collisions.
library;

/// Port of `ErrUnknownType` (uri.go:12).
final class UnknownTypeException implements Exception {
  const UnknownTypeException();

  @override
  String toString() => 'Unknown';
}

/// Port of `ErrSchemeType` (uri.go:14).
final class SchemeTypeException implements Exception {
  const SchemeTypeException();

  @override
  String toString() => 'unknown scheme type';
}

/// Port of `ErrSTUNQuery` (uri.go:16).
final class StunQueryException implements Exception {
  const StunQueryException();

  @override
  String toString() => 'queries not supported in stun address';
}

/// Port of `ErrInvalidQuery` (uri.go:18).
final class InvalidQueryException implements Exception {
  const InvalidQueryException();

  @override
  String toString() => 'invalid query';
}

/// Port of `ErrHost` (uri.go:20).
final class HostException implements Exception {
  const HostException();

  @override
  String toString() => 'invalid hostname';
}

/// Port of `ErrPort` (uri.go:22).
final class PortException implements Exception {
  const PortException();

  @override
  String toString() => 'invalid port';
}

/// Port of `ErrProtoType` (uri.go:24).
final class ProtoTypeException implements Exception {
  const ProtoTypeException();

  @override
  String toString() => 'invalid transport protocol type';
}

/// Port of `SchemeType` (uri.go:27).
enum SchemeType {
  unknown,
  stun,
  stuns,
  turn,
  turns;

  /// Port of `NewSchemeType` (uri.go:56-70).
  static SchemeType fromRaw(String raw) => switch (raw) {
    'stun' => SchemeType.stun,
    'stuns' => SchemeType.stuns,
    'turn' => SchemeType.turn,
    'turns' => SchemeType.turns,
    _ => SchemeType.unknown,
  };

  /// Port of `SchemeType.String` (uri.go:73-86).
  @override
  String toString() => switch (this) {
    SchemeType.stun => 'stun',
    SchemeType.stuns => 'stuns',
    SchemeType.turn => 'turn',
    SchemeType.turns => 'turns',
    SchemeType.unknown => const UnknownTypeException().toString(),
  };
}

/// Port of `ProtoType` (uri.go:91): the transport protocol type used in the
/// URI structure.
enum ProtoType {
  unknown,
  udp,
  tcp;

  /// Port of `NewProtoType` (uri.go:99-109).
  static ProtoType fromRaw(String raw) => switch (raw) {
    'udp' => ProtoType.udp,
    'tcp' => ProtoType.tcp,
    _ => ProtoType.unknown,
  };

  /// Port of `ProtoType.String` (uri.go:112-121).
  @override
  String toString() => switch (this) {
    ProtoType.udp => 'udp',
    ProtoType.tcp => 'tcp',
    ProtoType.unknown => const UnknownTypeException().toString(),
  };
}

/// Port of `URI` (uri.go:124-131): a STUN (RFC 7064) or TURN (RFC 7065)
/// URI. See file-level doc comment for the `StunUri` rename.
final class StunUri {
  StunUri({
    this.scheme = SchemeType.unknown,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.proto = ProtoType.unknown,
  });

  SchemeType scheme;
  String host;
  int port;
  String username;
  String password;
  ProtoType proto;

  /// Port of `ParseURI` (uri.go:134-186).
  factory StunUri.parse(String raw) {
    final rawParts = _RawUri.parse(raw);

    final uri = StunUri(scheme: SchemeType.fromRaw(rawParts.scheme));
    if (uri.scheme == SchemeType.unknown) throw const SchemeTypeException();

    final (host, rawPort, missingPort) = _splitHostPort(rawParts.opaque);
    if (missingPort) {
      final next = StringBuffer(uri.scheme.toString())
        ..write(':')
        ..write(rawParts.opaque);
      switch (uri.scheme) {
        case SchemeType.stun:
        case SchemeType.turn:
          next.write(':3478');
          if (rawParts.rawQuery.isNotEmpty) next.write('?${rawParts.rawQuery}');
          return StunUri.parse(next.toString());
        case SchemeType.stuns:
        case SchemeType.turns:
          next.write(':5349');
          if (rawParts.rawQuery.isNotEmpty) next.write('?${rawParts.rawQuery}');
          return StunUri.parse(next.toString());
        case SchemeType.unknown:
          throw const SchemeTypeException();
      }
    }

    uri.host = host;
    if (uri.host.isEmpty) throw const HostException();

    final parsedPort = int.tryParse(rawPort);
    if (parsedPort == null) throw const PortException();
    uri.port = parsedPort;

    switch (uri.scheme) {
      case SchemeType.stun:
        if (_parseQuery(rawParts.rawQuery).isNotEmpty) {
          throw const StunQueryException();
        }
        uri.proto = ProtoType.udp;
      case SchemeType.stuns:
        if (_parseQuery(rawParts.rawQuery).isNotEmpty) {
          throw const StunQueryException();
        }
        uri.proto = ProtoType.tcp;
      case SchemeType.turn:
        uri.proto = _parseProto(rawParts.rawQuery) ?? ProtoType.udp;
      case SchemeType.turns:
        uri.proto = _parseProto(rawParts.rawQuery) ?? ProtoType.tcp;
      case SchemeType.unknown:
        break;
    }

    return uri;
  }

  static Map<String, String> _parseQuery(String rawQuery) {
    if (rawQuery.isEmpty) return const {};
    final result = <String, String>{};
    for (final pair in rawQuery.split('&')) {
      if (pair.isEmpty) continue;
      final idx = pair.indexOf('=');
      final key = idx < 0 ? pair : pair.substring(0, idx);
      final value = idx < 0
          ? ''
          : Uri.decodeQueryComponent(pair.substring(idx + 1));
      result[Uri.decodeQueryComponent(key)] = value;
    }
    return result;
  }

  /// Port of `parseProto` (uri.go:189-208). Returns `null` for
  /// `ProtoTypeUnknown` (Go's zero value used as "not specified" sentinel).
  static ProtoType? _parseProto(String raw) {
    final qArgs = _parseQuery(raw);
    if (qArgs.length > 1) throw const InvalidQueryException();

    final rawProto = qArgs['transport'];
    if (rawProto != null && rawProto.isNotEmpty) {
      final proto = ProtoType.fromRaw(rawProto);
      if (proto == ProtoType.unknown) throw const ProtoTypeException();
      return proto;
    }

    if (qArgs.isNotEmpty) throw const InvalidQueryException();
    return null;
  }

  /// Port of `URI.String` (uri.go:211-218).
  @override
  String toString() {
    var rawUrl = '$scheme:${_joinHostPort(host, port)}';
    if (scheme == SchemeType.turn || scheme == SchemeType.turns) {
      rawUrl += '?transport=$proto';
    }
    return rawUrl;
  }

  /// Port of `URI.IsSecure` (uri.go:221-223).
  bool get isSecure => scheme == SchemeType.stuns || scheme == SchemeType.turns;
}

String _joinHostPort(String host, int port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';

/// Splits `opaque` (the part of the URI after `scheme:`) into host and raw
/// port, mirroring `net.SplitHostPort`'s "missing port in address" case:
/// returns `missingPort: true` when there is no `:port` suffix at all,
/// which `ParseURI` (uri.go:145-165) handles by re-parsing with a
/// scheme-default port appended.
(String, String, bool) _splitHostPort(String opaque) {
  var hostPart = opaque;
  if (hostPart.startsWith('[')) {
    final end = hostPart.indexOf(']');
    if (end < 0) return (opaque, '', true);
    final host = hostPart.substring(1, end);
    final rest = hostPart.substring(end + 1);
    if (!rest.startsWith(':')) return (host, '', true);
    return (host, rest.substring(1), false);
  }
  final idx = hostPart.lastIndexOf(':');
  if (idx < 0) return (opaque, '', true);
  return (hostPart.substring(0, idx), hostPart.substring(idx + 1), false);
}

/// Minimal `scheme:opaque[?query]` splitter matching what `ParseURI`
/// (uri.go:135-142) needs from Go's `net/url.Parse` for non-hierarchical
/// (no `//`) STUN/TURN URIs: `Scheme`, `Opaque`, `RawQuery`.
final class _RawUri {
  const _RawUri({
    required this.scheme,
    required this.opaque,
    required this.rawQuery,
  });

  final String scheme;
  final String opaque;
  final String rawQuery;

  factory _RawUri.parse(String raw) {
    final colon = raw.indexOf(':');
    if (colon < 0) {
      throw FormatException('missing scheme separator', raw);
    }
    final scheme = raw.substring(0, colon);
    var rest = raw.substring(colon + 1);
    var rawQuery = '';
    final qMark = rest.indexOf('?');
    if (qMark >= 0) {
      rawQuery = rest.substring(qMark + 1);
      rest = rest.substring(0, qMark);
    }
    return _RawUri(scheme: scheme, opaque: rest, rawQuery: rawQuery);
  }
}
