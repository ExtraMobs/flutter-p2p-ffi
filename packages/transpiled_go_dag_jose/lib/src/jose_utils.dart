// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-dag-jose/dagjose/jose_utils.go.

import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

import 'jose_bytes.dart';

Node? lookupIgnoreAbsent(String key, Node n) {
  try {
    final val = n.lookupByString(key);
    if (val.isAbsent()) {
      return null;
    }
    return val;
  } on NotExistsException {
    return null;
  } catch (_) {
    return null;
  }
}

Node? lookupIgnoreNoSuchField(String key, Node n) {
  return lookupIgnoreAbsent(key, n);
}

bool isJws(Node n) {
  final payload = lookupIgnoreNoSuchField('payload', n);
  return payload != null;
}

bool isJwe(Node n) {
  final ciphertext = lookupIgnoreNoSuchField('ciphertext', n);
  return ciphertext != null;
}

void validateLink(Node n) {
  final linkNode = lookupIgnoreNoSuchField('link', n);
  if (linkNode == null) return;

  final payloadNode = lookupIgnoreNoSuchField('payload', n);
  if (payloadNode == null) {
    throw const FormatException('payload missing when link is present');
  }

  Cid cidFromPayload;
  try {
    if (payloadNode.kind() == Kind.bytes) {
      cidFromPayload = Cid.fromBytes(payloadNode.asBytes());
    } else {
      final payloadString = payloadNode.asString();
      try {
        cidFromPayload = Cid.decode('u$payloadString');
      } catch (_) {
        final decodedBytes = decodeBase64Url(payloadString);
        cidFromPayload = Cid.fromBytes(decodedBytes);
      }
    }
  } catch (e) {
    throw FormatException('payload is not a valid CID: $e');
  }

  final linkVal = linkNode.asLink();
  Cid linkCid;
  if (linkVal is CidLink) {
    linkCid = linkVal.cid;
  } else {
    linkCid = Cid.decode(linkVal.toString());
  }

  if (linkCid != cidFromPayload) {
    throw const FormatException('cid mismatch');
  }
}

Node unflattenJwe(Node n) {
  final ciphertext = lookupIgnoreAbsent('ciphertext', n);
  if (ciphertext == null) {
    throw const FormatException("missing mandatory 'ciphertext' field");
  }

  final result = <String, dynamic>{};
  if (ciphertext.kind() == Kind.bytes) {
    result['ciphertext'] = ciphertext.asBytes();
  } else {
    result['ciphertext'] = ciphertext.asString();
  }

  final recipients = lookupIgnoreAbsent('recipients', n);
  if (recipients == null) {
    // Flattened JWE
    final recipientEntry = <String, dynamic>{};
    final encryptedKey = lookupIgnoreNoSuchField('encrypted_key', n);
    if (encryptedKey != null) {
      if (encryptedKey.kind() == Kind.bytes) {
        recipientEntry['encrypted_key'] = encryptedKey.asBytes();
      } else {
        recipientEntry['encrypted_key'] = encryptedKey.asString();
      }
    }

    final header = lookupIgnoreNoSuchField('header', n);
    if (header != null) {
      recipientEntry['header'] = _nodeToMapOrList(header);
    }

    if (recipientEntry.isNotEmpty) {
      result['recipients'] = [recipientEntry];
    }
  } else {
    // General JWE: ensure encrypted_key and header are not present at top level
    final encryptedKey = lookupIgnoreNoSuchField('encrypted_key', n);
    if (encryptedKey != null) {
      throw const FormatException('invalid JWE serialization');
    }
    final header = lookupIgnoreNoSuchField('header', n);
    if (header != null) {
      throw const FormatException('invalid JWE serialization');
    }
    result['recipients'] = _nodeToMapOrList(recipients);
  }

  final aad = lookupIgnoreAbsent('aad', n);
  if (aad != null) {
    result['aad'] = aad.kind() == Kind.bytes ? aad.asBytes() : aad.asString();
  }

  final iv = lookupIgnoreAbsent('iv', n);
  if (iv != null) {
    result['iv'] = iv.kind() == Kind.bytes ? iv.asBytes() : iv.asString();
  }

  final protected = lookupIgnoreAbsent('protected', n);
  if (protected != null) {
    result['protected'] =
        protected.kind() == Kind.bytes
            ? protected.asBytes()
            : protected.asString();
  }

  final tag = lookupIgnoreAbsent('tag', n);
  if (tag != null) {
    result['tag'] = tag.kind() == Kind.bytes ? tag.asBytes() : tag.asString();
  }

  final unprotected = lookupIgnoreAbsent('unprotected', n);
  if (unprotected != null) {
    result['unprotected'] = _nodeToMapOrList(unprotected);
  }

  return _buildNodeFromMap(result);
}

Node unflattenJws(Node n) {
  final payload = lookupIgnoreAbsent('payload', n);
  if (payload == null) {
    throw const FormatException("missing mandatory 'payload' field");
  }

  // Validate that payload is a valid CID
  try {
    if (payload.kind() == Kind.bytes) {
      Cid.fromBytes(payload.asBytes());
    } else {
      final payloadString = payload.asString();
      try {
        Cid.decode('u$payloadString');
      } catch (_) {
        final bytes = decodeBase64Url(payloadString);
        Cid.fromBytes(bytes);
      }
    }
  } catch (e) {
    throw FormatException('payload is not a valid CID: $e');
  }

  final result = <String, dynamic>{};
  if (payload.kind() == Kind.bytes) {
    result['payload'] = payload.asBytes();
  } else {
    result['payload'] = payload.asString();
  }

  final signatures = lookupIgnoreAbsent('signatures', n);
  if (signatures == null) {
    // Flattened JWS
    final sigEntry = <String, dynamic>{};
    final header = lookupIgnoreNoSuchField('header', n);
    if (header != null) {
      sigEntry['header'] = _nodeToMapOrList(header);
    }
    final protected = lookupIgnoreNoSuchField('protected', n);
    if (protected != null) {
      sigEntry['protected'] =
          protected.kind() == Kind.bytes
              ? protected.asBytes()
              : protected.asString();
    }
    final signature = lookupIgnoreNoSuchField('signature', n);
    if (signature != null) {
      sigEntry['signature'] =
          signature.kind() == Kind.bytes
              ? signature.asBytes()
              : signature.asString();
    }
    result['signatures'] = [sigEntry];
  } else {
    // General JWS: ensure header, protected, signature are not also at root
    final header = lookupIgnoreNoSuchField('header', n);
    if (header != null) {
      throw const FormatException('invalid JWS serialization');
    }
    final protected = lookupIgnoreNoSuchField('protected', n);
    if (protected != null) {
      throw const FormatException('invalid JWS serialization');
    }
    final signature = lookupIgnoreNoSuchField('signature', n);
    if (signature != null) {
      throw const FormatException('invalid JWS serialization');
    }
    result['signatures'] = _nodeToMapOrList(signatures);
  }

  return _buildNodeFromMap(result);
}

dynamic _nodeToMapOrList(Node node) {
  if (node.kind() == Kind.map) {
    final map = <String, dynamic>{};
    final itr = node.mapIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (k, v) = itr.next();
        map[k.asString()] = _nodeToMapOrList(v);
      }
    }
    return map;
  } else if (node.kind() == Kind.list) {
    final list = <dynamic>[];
    final itr = node.listIterator();
    if (itr != null) {
      while (!itr.done()) {
        final (_, v) = itr.next();
        list.add(_nodeToMapOrList(v));
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

Node _buildNodeFromMap(Map<String, dynamic> map) {
  final nb = prototype.map.newBuilder();
  final ma = nb.beginMap(map.length);
  for (final entry in map.entries) {
    ma.assembleKey().assignString(entry.key);
    _assembleValue(ma.assembleValue(), entry.value);
  }
  ma.finish();
  return nb.build();
}

void _assembleValue(NodeAssembler na, dynamic val) {
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
      _assembleValue(ma.assembleValue(), e.value);
    }
    ma.finish();
  } else if (val is List) {
    final la = na.beginList(val.length);
    for (final item in val) {
      _assembleValue(la.assembleValue(), item);
    }
    la.finish();
  } else if (val is Node) {
    copyNode(val, na);
  }
}

Node parseJose(List<int> jsonBytes) {
  final anyBuilder = prototype.any.newBuilder();
  decodeDagJson(anyBuilder, jsonBytes);
  final anyNode = anyBuilder.build();
  if (isJwe(anyNode)) {
    return unflattenJwe(anyNode);
  } else if (isJws(anyNode)) {
    return unflattenJws(anyNode);
  } else {
    throw const FormatException('invalid JOSE object');
  }
}
