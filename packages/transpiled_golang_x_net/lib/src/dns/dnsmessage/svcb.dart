// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../../../dns/dnsmessage.dart';

// Port of golang.org/x/net/dns/dnsmessage/svcb.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md). See message.dart for the general
// notes on GoString omission and error-typing shared across this library.

/// An SVCBResource is an SVCB Resource record. Port of
/// `dnsmessage.SVCBResource` (svcb.go:11-16).
final class SVCBResource implements ResourceBody {
  SVCBResource(this.priority, this.target, [List<SVCParam>? params])
    : params = params ?? <SVCParam>[];

  int priority;
  Name target;

  /// Must be in strict increasing order by Key.
  List<SVCParam> params;

  @override
  Type _realType() => Type.svcb;

  /// GetParam returns a parameter value by key. Port of
  /// `(*SVCBResource).GetParam` (svcb.go:55-65).
  Uint8List? getParam(SVCParamKey key) {
    for (final p in params) {
      if (p.key == key) return p.value;
      if (p.key.value > key.value) break;
    }
    return null;
  }

  /// SetParam sets a parameter value by key. The [params] list is kept
  /// sorted by key. Port of `(*SVCBResource).SetParam` (svcb.go:69-84).
  void setParam(SVCParamKey key, Uint8List value) {
    var i = 0;
    while (i < params.length) {
      if (params[i].key.value >= key.value) break;
      i++;
    }
    if (i < params.length && params[i].key == key) {
      params[i] = SVCParam(key, value);
      return;
    }
    params.insert(i, SVCParam(key, value));
  }

  /// DeleteParam deletes a parameter by key. Returns true if the parameter
  /// was present. Port of `(*SVCBResource).DeleteParam` (svcb.go:88-99).
  bool deleteParam(SVCParamKey key) {
    for (var i = 0; i < params.length; i++) {
      if (params[i].key == key) {
        params.removeAt(i);
        return true;
      }
      if (params[i].key.value > key.value) break;
    }
    return false;
  }

  /// Port of `(*SVCBResource).pack` (svcb.go:160-183).
  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    _packUint16(msg, priority);
    // https://datatracker.ietf.org/doc/html/rfc3597#section-4 prohibits name
    // compression for RR types that are not "well-known".
    // https://datatracker.ietf.org/doc/html/rfc9460#section-2.2 explicitly
    // states that compression of the Target is prohibited, following RFC
    // 3597.
    try {
      target._pack(msg, null, 0);
    } on FormatException catch (e) {
      _nest('SVCBResource.Target', e);
    }
    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      if (i > 0 && param.key.value <= params[i - 1].key.value) {
        _nest(
          'SVCBResource.Params',
          const FormatException(_errParamOutOfOrder),
        );
      }
      if (param.value.length > 0xFFFF) {
        _nest(
          'SVCBResource.Params',
          const FormatException(_errTooLongSVCBValue),
        );
      }
      _packUint16(msg, param.key.value);
      _packUint16(msg, param.value.length);
      msg.addAll(param.value);
    }
  }
}

/// Port of `unpackSVCBResource` (svcb.go:185-259).
SVCBResource _unpackSVCBResource(List<int> msg, int off, int length) {
  final r = SVCBResource(0, Name());
  var paramsOff = off;
  final bodyEnd = off + length;

  try {
    final (priority, o) = _unpackUint16(msg, paramsOff);
    r.priority = priority;
    paramsOff = o;
  } on FormatException catch (e) {
    _nest('Priority', e);
  }

  try {
    paramsOff = r.target._unpack(msg, paramsOff);
  } on FormatException catch (e) {
    _nest('Target', e);
  }

  // Two-pass parsing to avoid allocations.
  // First, count the number of params.
  var n = 0;
  var scanOff = paramsOff;
  var previousKey = 0;
  while (scanOff < bodyEnd) {
    final int key, size;
    try {
      (key, scanOff) = _unpackUint16(msg, scanOff);
    } on FormatException catch (e) {
      _nest('Params key', e);
    }
    if (n > 0 && key <= previousKey) {
      // As per https://www.rfc-editor.org/rfc/rfc9460.html#section-2.2,
      // clients MUST consider the RR malformed if the SvcParamKeys are not
      // in strictly increasing numeric order.
      _nest('Params', const FormatException(_errParamOutOfOrder));
    }
    try {
      (size, scanOff) = _unpackUint16(msg, scanOff);
    } on FormatException catch (e) {
      _nest('Params value length', e);
    }
    if (scanOff + size > bodyEnd) {
      throw const FormatException(_errResourceLen);
    }
    previousKey = key;
    scanOff += size;
    n++;
  }
  if (scanOff != bodyEnd) throw const FormatException(_errResourceLen);

  // Second, fill in the params.
  final params = List<SVCParam>.generate(
    n,
    (_) => SVCParam(const SVCParamKey(0), Uint8List(0)),
  );
  scanOff = paramsOff;
  for (var i = 0; i < n; i++) {
    final int key, size;
    try {
      (key, scanOff) = _unpackUint16(msg, scanOff);
    } on FormatException catch (e) {
      _nest('param key', e);
    }
    try {
      (size, scanOff) = _unpackUint16(msg, scanOff);
    } on FormatException catch (e) {
      _nest('param length', e);
    }
    if (msg.length - scanOff < size) {
      _nest('param value', const FormatException(_errCalcLen));
    }
    final value = Uint8List.fromList(msg.sublist(scanOff, scanOff + size));
    params[i] = SVCParam(SVCParamKey(key), value);
    scanOff += size;
  }

  r.params = params;
  return r;
}

/// An HTTPSResource is an HTTPS Resource record. It has the same format as
/// the SVCB record. Port of `dnsmessage.HTTPSResource` (svcb.go:38-43). Go
/// embeds `SVCBResource` anonymously (field-promoted); Dart has no field
/// promotion, so it is a named field instead.
final class HTTPSResource implements ResourceBody {
  HTTPSResource(this.svcbResource);

  /// Alias for SVCB resource record.
  SVCBResource svcbResource;

  @override
  Type _realType() => Type.https;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => svcbResource._pack(msg, compression, compressionOff);
}

/// A SVCParam is a service parameter. Port of `dnsmessage.SVCParam`
/// (svcb.go:102-105).
final class SVCParam {
  SVCParam(this.key, this.value);

  SVCParamKey key;
  Uint8List value;
}

/// A SVCParamKey is a key for a service parameter.
///
/// Values defined at
/// https://www.iana.org/assignments/dns-svcb/dns-svcb.xhtml#dns-svcparamkeys.
/// Port of `dnsmessage.SVCParamKey` (svcb.go:115-129).
final class SVCParamKey implements Comparable<SVCParamKey> {
  const SVCParamKey(this.value);

  final int value;

  static const SVCParamKey mandatory = SVCParamKey(0);
  static const SVCParamKey alpn = SVCParamKey(1);
  static const SVCParamKey noDefaultALPN = SVCParamKey(2);
  static const SVCParamKey port = SVCParamKey(3);
  static const SVCParamKey ipv4Hint = SVCParamKey(4);
  static const SVCParamKey ech = SVCParamKey(5);
  static const SVCParamKey ipv6Hint = SVCParamKey(6);
  static const SVCParamKey dohPath = SVCParamKey(7);
  static const SVCParamKey ohttp = SVCParamKey(8);
  static const SVCParamKey tlsSupportedGroups = SVCParamKey(9);

  static final Map<SVCParamKey, String> _names = {
    mandatory: 'Mandatory',
    alpn: 'ALPN',
    noDefaultALPN: 'NoDefaultALPN',
    port: 'Port',
    ipv4Hint: 'IPv4Hint',
    ech: 'ECH',
    ipv6Hint: 'IPv6Hint',
    dohPath: 'DOHPath',
    ohttp: 'OHTTP',
    tlsSupportedGroups: 'TLSSupportedGroups',
  };

  @override
  String toString() => _names[this] ?? _printUint16(value);

  @override
  bool operator ==(Object other) =>
      other is SVCParamKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(SVCParamKey other) => value.compareTo(other.value);
}
