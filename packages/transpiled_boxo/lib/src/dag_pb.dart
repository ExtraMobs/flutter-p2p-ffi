// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';
import 'dart:convert';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_codec_dagpb/transpiled_go_codec_dagpb.dart'
    as codec;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart' as ipld;
import 'package:transpiled_varint/transpiled_varint.dart';

List<int> _field(int number, List<int> value) => <int>[
  (number << 3) | 2,
  ...encodeVarint(value.length),
  ...value,
];

List<int> _varintField(int number, int value) => <int>[
  number << 3,
  ...encodeVarint(value),
];

/// A DAG-PB link using the complete binary Cid stored by Boxo.
class DagPbLink {
  DagPbLink({required this.hash, this.name = '', this.tsize = 0});

  factory DagPbLink.fromCid(Cid cid, {String name = '', int? tsize}) =>
      DagPbLink(hash: cid.toBytes(), name: name, tsize: tsize ?? 0);

  final Uint8List hash;
  final String name;
  final int tsize;

  factory DagPbLink.fromBytes(Uint8List bytes) {
    Uint8List hash = Uint8List(0);
    var name = '';
    var tsize = 0;
    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLength) = readVarint(bytes, offset);
      offset += tagLength;
      final field = tag >> 3;
      if ((tag & 7) == 2) {
        final (length, lengthLength) = readVarint(bytes, offset);
        offset += lengthLength;
        if (offset + length > bytes.length)
          throw const FormatException('truncated DAG-PB link');
        final value = bytes.sublist(offset, offset + length);
        offset += length;
        if (field == 1) hash = Uint8List.fromList(value);
        if (field == 2) name = utf8.decode(value);
      } else if ((tag & 7) == 0) {
        final (value, valueLength) = readVarint(bytes, offset);
        offset += valueLength;
        if (field == 3) tsize = value;
      } else {
        throw const FormatException('invalid DAG-PB link wire type');
      }
    }
    return DagPbLink(hash: hash, name: name, tsize: tsize);
  }

  Uint8List toBytes() {
    final out = <int>[..._field(1, hash)];
    // merkledag.GetPBNode initializes both pointers even for zero values.
    out.addAll(_field(2, utf8.encode(name)));
    out.addAll(_varintField(3, tsize));
    return Uint8List.fromList(out);
  }
}

/// A DAG-PB node in the canonical dag-pb order used by Boxo.
class DagPbNode {
  DagPbNode({
    List<int> data = const <int>[],
    Iterable<DagPbLink> links = const [],
  }) : data = Uint8List.fromList(data),
       links = List.unmodifiable(links);

  final Uint8List data;
  final List<DagPbLink> links;

  factory DagPbNode.fromBytes(Uint8List bytes) {
    final builder = ipld.AnyBuilder();
    codec.decodeBytes(builder, bytes);
    final node = builder.build();
    ipld.Node? optional(ipld.Node source, String key) {
      try {
        final value = source.lookupByString(key);
        return value.isAbsent() ? null : value;
      } on ipld.NotExistsException {
        return null;
      }
    }

    final data = optional(node, 'Data')?.asBytes() ?? Uint8List(0);
    final links = <DagPbLink>[];
    final encodedLinks = node.lookupByString('Links');
    for (var i = 0; i < encodedLinks.length(); i++) {
      final link = encodedLinks.lookupByIndex(i);
      final cidLink = link.lookupByString('Hash').asLink() as ipld.CidLink;
      links.add(
        DagPbLink.fromCid(
          cidLink.cid,
          name: optional(link, 'Name')?.asString() ?? '',
          tsize: optional(link, 'Tsize')?.asInt() ?? 0,
        ),
      );
    }
    return DagPbNode(data: data, links: links);
  }

  Uint8List toBytes() {
    return codec.appendEncode(
      Uint8List(0),
      ipld.PlainMap({
        'Links': ipld.PlainList([
          for (final link in links)
            ipld.PlainMap({
              'Hash': ipld.PlainLink(ipld.CidLink(Cid.fromBytes(link.hash))),
              'Name': ipld.PlainString(link.name),
              'Tsize': ipld.PlainInt(link.tsize),
            }),
        ]),
        if (data.isNotEmpty) 'Data': ipld.PlainBytes(data),
      }),
    );
  }
}

