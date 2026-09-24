// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-dag-jose/dagjose/jose_encode.go.

import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'jose_bytes.dart';
import 'jose_utils.dart';

/// Encodes walks the given [Node] and serializes it to [w]. Fits the [Encoder]
/// function interface.
void encode(Node n, Sink<List<int>> w) {
  if (isJwe(n)) {
    final unflattened = unflattenJwe(n);
    encodeJwe(unflattened, w);
  } else if (isJws(n)) {
    final unflattened = unflattenJws(n);
    encodeJws(unflattened, w);
  } else {
    throw const FormatException('invalid JOSE object');
  }
}

/// Encodes a JWE [Node] to DAG-CBOR.
void encodeJwe(Node n, Sink<List<int>> w) {
  final prepared = _prepareJweForCbor(n);
  const EncodeOptions(
    allowLinks: true,
    mapSortMode: MapSortMode.rfc7049,
  ).encode(prepared, w);
}

/// Encodes a JWS [Node] to DAG-CBOR.
void encodeJws(Node n, Sink<List<int>> w) {
  validateLink(n);
  final prepared = _prepareJwsForCbor(n);
  const EncodeOptions(
    allowLinks: true,
    mapSortMode: MapSortMode.rfc7049,
  ).encode(prepared, w);
}

Uint8List _toRawBytes(dynamic val) {
  if (val is Uint8List) return val;
  if (val is List<int>) return Uint8List.fromList(val);
  if (val is String) return decodeBase64Url(val);
  if (val is Node) {
    if (val.kind() == Kind.bytes) {
      return val.asBytes();
    } else {
      return decodeBase64Url(val.asString());
    }
  }
  throw FormatException('unexpected binary value type: ${val.runtimeType}');
}

Node _prepareJwsForCbor(Node n) {
  final map = <String, dynamic>{};

  final payloadNode = n.lookupByString('payload');
  map['payload'] = _toRawBytes(payloadNode);

  final sigsNode = lookupIgnoreAbsent('signatures', n);
  if (sigsNode != null && sigsNode.kind() == Kind.list) {
    final sigsList = <Map<String, dynamic>>[];
    final itr = sigsNode.listIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (_, entryNode) = itr.next();
        final sigMap = <String, dynamic>{};

        final sigNode = lookupIgnoreNoSuchField('signature', entryNode);
        if (sigNode != null) {
          sigMap['signature'] = _toRawBytes(sigNode);
        }

        final protNode = lookupIgnoreNoSuchField('protected', entryNode);
        if (protNode != null) {
          sigMap['protected'] = _toRawBytes(protNode);
        }

        final headerNode = lookupIgnoreNoSuchField('header', entryNode);
        if (headerNode != null) {
          sigMap['header'] = _nodeToDynamic(headerNode);
        }

        sigsList.add(sigMap);
      }
    }
    map['signatures'] = sigsList;
  }

  return _buildCborNode(map);
}

Node _prepareJweForCbor(Node n) {
  final map = <String, dynamic>{};

  final ciphertextNode = n.lookupByString('ciphertext');
  map['ciphertext'] = _toRawBytes(ciphertextNode);

  final aadNode = lookupIgnoreAbsent('aad', n);
  if (aadNode != null) {
    map['aad'] = _toRawBytes(aadNode);
  }

  final ivNode = lookupIgnoreAbsent('iv', n);
  if (ivNode != null) {
    map['iv'] = _toRawBytes(ivNode);
  }

  final protNode = lookupIgnoreAbsent('protected', n);
  if (protNode != null) {
    map['protected'] = _toRawBytes(protNode);
  }

  final tagNode = lookupIgnoreAbsent('tag', n);
  if (tagNode != null) {
    map['tag'] = _toRawBytes(tagNode);
  }

  final unprotectedNode = lookupIgnoreAbsent('unprotected', n);
  if (unprotectedNode != null) {
    map['unprotected'] = _nodeToDynamic(unprotectedNode);
  }

  final recipientsNode = lookupIgnoreAbsent('recipients', n);
  if (recipientsNode != null && recipientsNode.kind() == Kind.list) {
    final recList = <Map<String, dynamic>>[];
    final itr = recipientsNode.listIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (_, entryNode) = itr.next();
        final recMap = <String, dynamic>{};

        final encKeyNode = lookupIgnoreNoSuchField('encrypted_key', entryNode);
        if (encKeyNode != null) {
          recMap['encrypted_key'] = _toRawBytes(encKeyNode);
        }

        final headerNode = lookupIgnoreNoSuchField('header', entryNode);
        if (headerNode != null) {
          recMap['header'] = _nodeToDynamic(headerNode);
        }

        recList.add(recMap);
      }
    }
    map['recipients'] = recList;
  }

  return _buildCborNode(map);
}

dynamic _nodeToDynamic(Node node) {
  if (node.kind() == Kind.map) {
    final map = <String, dynamic>{};
    final itr = node.mapIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (k, v) = itr.next();
        map[k.asString()] = _nodeToDynamic(v);
      }
    }
    return map;
  } else if (node.kind() == Kind.list) {
    final list = <dynamic>[];
    final itr = node.listIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (_, v) = itr.next();
        list.add(_nodeToDynamic(v));
      }
    }
    return list;
  } else if (node.kind() == Kind.bytes) {
    return node.asBytes();
  } else if (node.kind() == Kind.string) {
    return node.asString();
  } else if (node.kind() == Kind.int_) {
    return node.asInt();
  } else if (node.kind() == Kind.bool_) {
    return node.asBool();
  } else if (node.kind() == Kind.float) {
    return node.asFloat();
  } else if (node.kind() == Kind.null_) {
    return null;
  }
  return null;
}

Node _buildCborNode(Map<String, dynamic> map) {
  final nb = prototype.map.newBuilder();
  final ma = nb.beginMap(map.length);
  for (final entry in map.entries) {
    ma.assembleKey().assignString(entry.key);
    _assembleCborValue(ma.assembleValue(), entry.value);
  }
  ma.finish();
  return nb.build();
}

void _assembleCborValue(NodeAssembler na, dynamic val) {
  if (val == null) {
    na.assignNull();
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
      _assembleCborValue(ma.assembleValue(), e.value);
    }
    ma.finish();
  } else if (val is List) {
    final la = na.beginList(val.length);
    for (final item in val) {
      _assembleCborValue(la.assembleValue(), item);
    }
    la.finish();
  } else if (val is Node) {
    copyNode(val, na);
  }
}
