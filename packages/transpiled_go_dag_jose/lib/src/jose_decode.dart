// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-dag-jose/dagjose/jose_decode.go.

import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'jose_bytes.dart';

/// Options customizing the decoding of DAG-JOSE objects.
final class DecodeOptions {
  /// If true and the `payload` field is present, add a `link` field
  /// corresponding to the `payload`.
  final bool addLink;

  const DecodeOptions({this.addLink = true});

  /// Deserializes data from [reader] and feeds it into [na]. Fits the
  /// [Decoder] interface.
  void decode(NodeAssembler na, Iterable<int> reader) {
    final bytes = reader is Uint8List ? reader : Uint8List.fromList(reader.toList());
    try {
      decodeJwe(na, bytes);
    } catch (_) {
      decodeJws(na, bytes);
    }
  }

  /// Deserializes data from [reader] as a JWE and feeds it into [na].
  void decodeJwe(NodeAssembler na, Iterable<int> reader) {
    final builder = prototype.any.newBuilder();
    decodeDagCbor(builder, reader);
    final rawNode = builder.build();

    if (rawNode.kind() != Kind.map) {
      throw const FormatException('JWE must be an IPLD map');
    }

    try {
      final ciphertextNode = rawNode.lookupByString('ciphertext');
      if (ciphertextNode.isAbsent()) {
        throw const FormatException("missing mandatory 'ciphertext' field");
      }
    } catch (e) {
      throw const FormatException("missing mandatory 'ciphertext' field");
    }

    final decodedNode = _transformToDecodedJwe(rawNode);
    copyNode(decodedNode, na);
  }

  /// Deserializes data from [reader] as a JWS and feeds it into [na].
  void decodeJws(NodeAssembler na, Iterable<int> reader) {
    final builder = prototype.any.newBuilder();
    decodeDagCbor(builder, reader);
    final rawNode = builder.build();

    if (rawNode.kind() != Kind.map) {
      throw const FormatException('JWS must be an IPLD map');
    }

    final Node payloadNode;
    try {
      payloadNode = rawNode.lookupByString('payload');
      if (payloadNode.isAbsent()) {
        throw const FormatException("missing mandatory 'payload' field");
      }
    } catch (e) {
      throw const FormatException("missing mandatory 'payload' field");
    }

    final decodedNode = _transformToDecodedJws(rawNode, payloadNode);
    copyNode(decodedNode, na);
  }

  Node _transformToDecodedJws(Node rawNode, Node payloadNode) {
    final map = <String, dynamic>{};

    final Uint8List payloadBytes;
    if (payloadNode.kind() == Kind.bytes) {
      payloadBytes = payloadNode.asBytes();
    } else {
      payloadBytes = decodeBase64Url(payloadNode.asString());
    }
    map['payload'] = Base64Url(payloadBytes);

    if (addLink) {
      Node? existingLink;
      try {
        final lnk = rawNode.lookupByString('link');
        if (!lnk.isAbsent()) existingLink = lnk;
      } catch (_) {}

      if (existingLink == null) {
        final cid = Cid.fromBytes(payloadBytes);
        map['link'] = CidLink(cid);
      } else {
        map['link'] = existingLink.asLink();
      }
    }

    try {
      final sigsNode = rawNode.lookupByString('signatures');
      if (!sigsNode.isAbsent() && sigsNode.kind() == Kind.list) {
        final sigList = <Map<String, dynamic>>[];
        final itr = sigsNode.listIterator();
        if (itr != null) {
          while (!itr.done()) {
            final (_, entryNode) = itr.next();
            final entryMap = <String, dynamic>{};

            try {
              final sig = entryNode.lookupByString('signature');
              if (!sig.isAbsent()) {
                final sigBytes = sig.kind() == Kind.bytes
                    ? sig.asBytes()
                    : decodeBase64Url(sig.asString());
                entryMap['signature'] = Base64Url(sigBytes);
              }
            } catch (_) {}

            try {
              final prot = entryNode.lookupByString('protected');
              if (!prot.isAbsent()) {
                final protBytes = prot.kind() == Kind.bytes
                    ? prot.asBytes()
                    : decodeBase64Url(prot.asString());
                entryMap['protected'] = Base64Url(protBytes);
              }
            } catch (_) {}

            try {
              final hdr = entryNode.lookupByString('header');
              if (!hdr.isAbsent()) {
                entryMap['header'] = _nodeToMap(hdr);
              }
            } catch (_) {}

            sigList.add(entryMap);
          }
        }
        map['signatures'] = sigList;
      }
    } catch (_) {}

    return _buildDecodedNode(map);
  }

  Node _transformToDecodedJwe(Node rawNode) {
    final map = <String, dynamic>{};

    final ciphertext = rawNode.lookupByString('ciphertext');
    final ctBytes = ciphertext.kind() == Kind.bytes
        ? ciphertext.asBytes()
        : decodeBase64Url(ciphertext.asString());
    map['ciphertext'] = Base64Url(ctBytes);

    for (final field in const ['aad', 'iv', 'protected', 'tag']) {
      try {
        final valNode = rawNode.lookupByString(field);
        if (!valNode.isAbsent()) {
          final valBytes = valNode.kind() == Kind.bytes
              ? valNode.asBytes()
              : decodeBase64Url(valNode.asString());
          map[field] = Base64Url(valBytes);
        }
      } catch (_) {}
    }

    try {
      final unprot = rawNode.lookupByString('unprotected');
      if (!unprot.isAbsent()) {
        map['unprotected'] = _nodeToMap(unprot);
      }
    } catch (_) {}

    try {
      final recipients = rawNode.lookupByString('recipients');
      if (!recipients.isAbsent() && recipients.kind() == Kind.list) {
        final recList = <Map<String, dynamic>>[];
        final itr = recipients.listIterator();
        if (itr != null) {
          while (!itr.done()) {
            final (_, entryNode) = itr.next();
            final recMap = <String, dynamic>{};

            try {
              final encKey = entryNode.lookupByString('encrypted_key');
              if (!encKey.isAbsent()) {
                final keyBytes = encKey.kind() == Kind.bytes
                    ? encKey.asBytes()
                    : decodeBase64Url(encKey.asString());
                recMap['encrypted_key'] = Base64Url(keyBytes);
              }
            } catch (_) {}

            try {
              final hdr = entryNode.lookupByString('header');
              if (!hdr.isAbsent()) {
                recMap['header'] = _nodeToMap(hdr);
              }
            } catch (_) {}

            recList.add(recMap);
          }
        }
        map['recipients'] = recList;
      }
    } catch (_) {}

    return _buildDecodedNode(map);
  }
}

/// Deserializes data from [reader] and feeds it into [na] with default options
/// (addLink = true). Fits the [Decoder] interface.
void decode(NodeAssembler na, Iterable<int> reader) {
  const DecodeOptions(addLink: true).decode(na, reader);
}

/// Deserializes data from [reader] as a JWE into [na].
void decodeJwe(NodeAssembler na, Iterable<int> reader) {
  const DecodeOptions(addLink: true).decodeJwe(na, reader);
}

/// Deserializes data from [reader] as a JWS into [na].
void decodeJws(NodeAssembler na, Iterable<int> reader) {
  const DecodeOptions(addLink: true).decodeJws(na, reader);
}

Map<String, dynamic> _nodeToMap(Node node) {
  final map = <String, dynamic>{};
  final itr = node.mapIterator();
  if (itr != null) {
    while (!itr.done()) {
      final (k, v) = itr.next();
      map[k.asString()] = _anyNodeToVal(v);
    }
  }
  return map;
}

dynamic _anyNodeToVal(Node v) {
  if (v.kind() == Kind.map) return _nodeToMap(v);
  if (v.kind() == Kind.list) {
    final list = <dynamic>[];
    final itr = v.listIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (_, item) = itr.next();
        list.add(_anyNodeToVal(item));
      }
    }
    return list;
  }
  if (v.kind() == Kind.string) return v.asString();
  if (v.kind() == Kind.bytes) return v.asBytes();
  if (v.kind() == Kind.int_) return v.asInt();
  if (v.kind() == Kind.bool_) return v.asBool();
  if (v.kind() == Kind.float) return v.asFloat();
  if (v.kind() == Kind.link) return v.asLink();
  return null;
}

Node _buildDecodedNode(Map<String, dynamic> map) {
  final nb = prototype.map.newBuilder();
  final ma = nb.beginMap(map.length);
  for (final entry in map.entries) {
    ma.assembleKey().assignString(entry.key);
    _assembleDecodedValue(ma.assembleValue(), entry.value);
  }
  ma.finish();
  return nb.build();
}

void _assembleDecodedValue(NodeAssembler na, dynamic val) {
  if (val == null) {
    na.assignNull();
  } else if (val is Base64Url) {
    na.assignNode(val);
  } else if (val is Raw) {
    na.assignNode(val);
  } else if (val is Link) {
    na.assignLink(val);
  } else if (val is bool) {
    na.assignBool(val);
  } else if (val is int) {
    na.assignInt(val);
  } else if (val is double) {
    na.assignFloat(val);
  } else if (val is String) {
    na.assignString(val);
  } else if (val is Uint8List) {
    na.assignBytes(val);
  } else if (val is List<int>) {
    na.assignBytes(Uint8List.fromList(val));
  } else if (val is Map<String, dynamic>) {
    final ma = na.beginMap(val.length);
    for (final e in val.entries) {
      ma.assembleKey().assignString(e.key);
      _assembleDecodedValue(ma.assembleValue(), e.value);
    }
    ma.finish();
  } else if (val is List) {
    final la = na.beginList(val.length);
    for (final item in val) {
      _assembleDecodedValue(la.assembleValue(), item);
    }
    la.finish();
  } else if (val is Node) {
    copyNode(val, na);
  }
}
