// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';
// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';
import 'package:transpiled_protobuf/protowire.dart' as wire;

/// Decodes DAG-PB bytes into [a], corresponding to Go's `DecodeBytes`.
void decodeBytes(NodeAssembler a, Uint8List b) {
  var p = 0, data = false, links = false, open = false;
  ListAssembler? ls;
  final m = a.beginMap(2);
  while (p < b.length) {
    final t = wire.consumeTag(Uint8List.sublistView(b, p));
    if (t.$3 < 0) throw wire.parseError(t.$3)!;
    p += t.$3;
    if (t.$2 != 2) {
      _bad('protobuf: (PBNode) invalid wireType, expected 2, got ${t.$2}');
    }
    switch (t.$1) {
      case 1:
        if (data) _bad('protobuf: (PBNode) duplicate Data section');
        final x = _bytes(b, p);
        p = x.$2;
        if (open) {
          ls!.finish();
          open = false;
        }
        m.assembleEntry('Data').assignBytes(x.$1);
        data = true;
      case 2:
        final x = _bytes(b, p);
        p = x.$2;
        if (!open) {
          if (links) _bad('protobuf: (PBNode) duplicate Links section');
          ls = m.assembleEntry('Links').beginList(0);
          open = true;
          links = true;
        }
        _link(ls!.assembleValue(), x.$1);
      default:
        _bad(
          'protobuf: (PBNode) invalid fieldNumber, expected 1 or 2, got ${t.$1}',
        );
    }
  }
  if (open) {
    ls!.finish();
  } else if (!links) {
    m.assembleEntry('Links').beginList(0).finish();
  }
  m.finish();
}

/// Decodes an input byte sequence, corresponding to Go's `Decode`.
void decode(NodeAssembler a, Iterable<int> b) =>
    decodeBytes(a, Uint8List.fromList(b.toList()));

/// Writes encoded DAG-PB to [w] without closing the caller-owned sink.
void encode(Node n, Sink<List<int>> w) => w.add(appendEncode(Uint8List(0), n));

/// Returns [p] followed by encoded [n], corresponding to Go's `AppendEncode`.
Uint8List appendEncode(Uint8List p, Node n) {
  _checkFields(n, const {'Links', 'Data'});
  final o = <int>[...p],
      l = n.lookupByString('Links'),
      e = <({int i, List<int> hash, String? name, int? size})>[];
  final it = l.listIterator()!;
  while (!it.done()) {
    final x = it.next();
    _checkFields(x.$2, const {'Hash', 'Name', 'Tsize'});
    final link = x.$2.lookupByString('Hash').asLink();
    if (link is! CidLink) {
      _bad('invalid DAG-PB form (link must have a Hash)');
    }
    final name = _opt(x.$2, 'Name')?.asString();
    final size = _opt(x.$2, 'Tsize')?.asInt();
    if (size != null && size < 0) {
      _bad('Link has negative Tsize value [$size]');
    }
    e.add((i: x.$1, hash: link.binary(), name: name, size: size));
  }
  e.sort((a, b) {
    final c = _cmp(a.name ?? '', b.name ?? '');
    return c != 0 ? c : a.i - b.i;
  });
  for (final z in e) {
    final name = z.name == null ? null : Golang.String.fromDart(z.name!);
    var size = wire.sizeTag(2) + wire.sizeBytes(z.hash.length);
    if (name != null) {
      size += wire.sizeTag(2) + wire.sizeBytes(name.length);
    }
    if (z.size != null) {
      size += wire.sizeTag(3) + wire.sizeVarint(Golang.Uint64(z.size!));
    }
    wire.appendTag(o, 2, 2);
    wire.appendVarint(o, Golang.Uint64(size));
    wire.appendTag(o, 1, 2);
    wire.appendBytes(o, z.hash);
    if (name != null) {
      wire.appendTag(o, 2, 2);
      wire.appendString(o, name);
    }
    if (z.size != null) {
      wire.appendTag(o, 3, 0);
      wire.appendVarint(o, Golang.Uint64(z.size!));
    }
  }
  final d = _opt(n, 'Data');
  if (d != null) {
    wire.appendTag(o, 1, 2);
    wire.appendBytes(o, d.asBytes());
  }
  return Uint8List.fromList(o);
}

void _link(NodeAssembler a, Uint8List b) {
  var p = 0, hash = false, name = false, tsize = false;
  final m = a.beginMap(3);
  while (p < b.length) {
    final t = wire.consumeTag(Uint8List.sublistView(b, p));
    if (t.$3 < 0) throw wire.parseError(t.$3)!;
    p += t.$3;
    final f = t.$1, w = t.$2;
    if (f < 1 || f > 3) {
      _bad(
        'protobuf: (PBLink) invalid fieldNumber, expected 1, 2 or 3, got $f',
      );
    }
    final field = const ['Hash', 'Name', 'Tsize'][f - 1];
    if ([hash, name, tsize][f - 1]) {
      _bad('protobuf: (PBLink) duplicate $field section');
    }
    if (f == 1 && name) {
      _bad('protobuf: (PBLink) invalid order, found Name before Hash');
    }
    if (f < 3 && tsize) {
      _bad('protobuf: (PBLink) invalid order, found Tsize before $field');
    }
    if (w != (f == 3 ? 0 : 2)) {
      _bad('protobuf: (PBLink) wrong wireType ($w) for $field');
    }
    if (f == 3) {
      final x = _v(b, p);
      p = x.$2;
      // Go converts the decoded uint64 to int64 before AssignInt.
      // _v applies the explicit shared Int64 conversion and exactness check.
      m.assembleEntry('Tsize').assignInt(x.$1);
      tsize = true;
    } else {
      final x = _bytes(b, p);
      p = x.$2;
      if (f == 1) {
        final Cid cid;
        try {
          cid = Cid.fromBytes(x.$1);
        } catch (_) {
          _bad('invalid Hash Cid');
        }
        m.assembleEntry('Hash').assignLink(CidLink(cid));
        hash = true;
      } else {
        m.assembleEntry('Name').assignString(utf8.decode(x.$1));
        name = true;
      }
    }
  }
  if (!hash) _bad('invalid Hash field found in link, expected Cid');
  m.finish();
}

Node? _opt(Node n, String k) {
  try {
    final v = n.lookupByString(k);
    return v.isAbsent() ? null : v;
  } catch (e) {
    if (e is NotExistsException) return null;
    rethrow;
  }
}

void _checkFields(Node node, Set<String> allowed) {
  if (node.kind() != Kind.map) _bad('DAG-PB requires a map');
  final iterator = node.mapIterator()!;
  while (!iterator.done()) {
    final entry = iterator.next();
    if (!allowed.contains(entry.$1.asString())) {
      _bad('invalid DAG-PB field: ${entry.$1.asString()}');
    }
  }
}

int _cmp(String a, String b) {
  final x = utf8.encode(a), y = utf8.encode(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return x.length - y.length;
}

(int, int) _v(Uint8List b, int p) {
  final (v, n) = wire.consumeVarint(Uint8List.sublistView(b, p));
  if (n < 0) throw wire.parseError(n)!;
  final native = Golang.Int64.fromUint64(v).toIntExact();
  return (native, p + n);
}

(Uint8List, int) _bytes(Uint8List b, int p) {
  final (value, n) = wire.consumeBytes(Uint8List.sublistView(b, p));
  if (n < 0) throw wire.parseError(n)!;
  return (value!, p + n);
}

Never _bad(String s) => throw FormatException(s);
