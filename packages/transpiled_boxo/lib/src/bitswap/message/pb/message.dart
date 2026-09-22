// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/boxo/bitswap/message/pb.

import 'dart:typed_data';

// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_protobuf/protowire.dart' as protobuf;

/// WantType represents whether the client wants the block or just a HAVE.
/// Equivalent to protobuf `Message.Wantlist.WantType`.
enum WantType {
  block(0),
  have(1);

  const WantType(this.value);

  final int value;

  /// Protocol wire value.
  int get code => value;

  static WantType fromValue(int val) => switch (val) {
    0 => WantType.block,
    1 => WantType.have,
    _ => WantType.block,
  };
}

/// BlockPresenceType represents HAVE or DONT_HAVE.
/// Equivalent to protobuf `Message.BlockPresenceType`.
enum BlockPresenceType {
  have(0),
  dontHave(1);

  const BlockPresenceType(this.value);

  final int value;

  /// Protocol wire value.
  int get code => value;

  static BlockPresenceType fromValue(int val) => switch (val) {
    0 => BlockPresenceType.have,
    1 => BlockPresenceType.dontHave,
    _ => BlockPresenceType.have,
  };
}

/// Entry is a single wantlist entry in the Bitswap protobuf message.
/// Equivalent to `Message_Wantlist_Entry`.
class Entry {
  Entry({
    Uint8List? block,
    this.priority = 0,
    this.cancel = false,
    this.wantType = WantType.block,
    this.sendDontHave = false,
  }) : block = block ?? Uint8List(0);

  Uint8List block;
  int priority;
  bool cancel;
  WantType wantType;
  bool sendDontHave;

  Uint8List getBlock() => block;
  int getPriority() => priority;
  bool getCancel() => cancel;
  WantType getWantType() => wantType;
  bool getSendDontHave() => sendDontHave;

  int size() {
    var s = 0;
    if (block.isNotEmpty) {
      s += protobuf.sizeTag(1) + protobuf.sizeBytes(block.length);
    }
    if (priority != 0) {
      s +=
          protobuf.sizeTag(2) +
          protobuf.sizeVarint(
            Golang.Uint64.fromBigInt(Golang.Int32(priority).toBigInt()),
          );
    }
    if (cancel) {
      s += protobuf.sizeTag(3) + protobuf.sizeVarint(Golang.Uint64(1));
    }
    if (wantType != WantType.block) {
      s +=
          protobuf.sizeTag(4) +
          protobuf.sizeVarint(Golang.Uint64(wantType.value));
    }
    if (sendDontHave) {
      s += protobuf.sizeTag(5) + protobuf.sizeVarint(Golang.Uint64(1));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (block.isNotEmpty) {
      protobuf.appendTag(buf, 1, 2);
      protobuf.appendBytes(buf, block);
    }
    if (priority != 0) {
      protobuf.appendTag(buf, 2, 0);
      protobuf.appendVarint(
        buf,
        Golang.Uint64.fromBigInt(Golang.Int32(priority).toBigInt()),
      );
    }
    if (cancel) {
      protobuf.appendTag(buf, 3, 0);
      protobuf.appendVarint(buf, Golang.Uint64(1));
    }
    if (wantType != WantType.block) {
      protobuf.appendTag(buf, 4, 0);
      protobuf.appendVarint(buf, Golang.Uint64(wantType.value));
    }
    if (sendDontHave) {
      protobuf.appendTag(buf, 5, 0);
      protobuf.appendVarint(buf, Golang.Uint64(1));
    }
    return Uint8List.fromList(buf);
  }

  static Entry decode(Uint8List b) {
    var block = Uint8List(0);
    var priority = 0;
    var cancel = false;
    var wantType = WantType.block;
    var sendDontHave = false;

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = protobuf.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw protobuf.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          block = val!;
          p += consumed;
        case 2:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          priority = val.toBigInt().toSigned(32).toInt();
          p += consumed;
        case 3:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          cancel = val != Golang.Uint64(0);
          p += consumed;
        case 4:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          wantType = WantType.fromValue(val.toBigInt().toSigned(32).toInt());
          p += consumed;
        case 5:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          sendDontHave = val != Golang.Uint64(0);
          p += consumed;
        default:
          p = _skipField(b, p, type);
      }
    }

    return Entry(
      block: block,
      priority: priority,
      cancel: cancel,
      wantType: wantType,
      sendDontHave: sendDontHave,
    );
  }
}

/// Wantlist represents the wantlist inside a Bitswap message.
/// Equivalent to `Message_Wantlist`.
class Wantlist {
  Wantlist({List<Entry>? entries, this.full = false})
    : entries = entries ?? <Entry>[];

  List<Entry> entries;
  bool full;

  List<Entry> getEntries() => entries;
  bool getFull() => full;

  int size() {
    var s = 0;
    for (final e in entries) {
      final esize = e.size();
      s += protobuf.sizeTag(1) + protobuf.sizeBytes(esize);
    }
    if (full) {
      s += protobuf.sizeTag(2) + protobuf.sizeVarint(Golang.Uint64(1));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    for (final e in entries) {
      final eBytes = e.encode();
      protobuf.appendTag(buf, 1, 2);
      protobuf.appendBytes(buf, eBytes);
    }
    if (full) {
      protobuf.appendTag(buf, 2, 0);
      protobuf.appendVarint(buf, Golang.Uint64(1));
    }
    return Uint8List.fromList(buf);
  }

  static Wantlist decode(Uint8List b) {
    final entries = <Entry>[];
    var full = false;

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = protobuf.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw protobuf.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          entries.add(Entry.decode(val!));
          p += consumed;
        case 2:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          full = val != Golang.Uint64(0);
          p += consumed;
        default:
          p = _skipField(b, p, type);
      }
    }

    return Wantlist(entries: entries, full: full);
  }
}

/// Block represents a block payload with CID prefix in bitswap 1.1.0+.
/// Equivalent to `Message_Block`.
class Block {
  Block({Uint8List? prefix, Uint8List? data})
    : prefix = prefix ?? Uint8List(0),
      data = data ?? Uint8List(0);

  Uint8List prefix;
  Uint8List data;

  Uint8List getPrefix() => prefix;
  Uint8List getData() => data;

  int size() {
    var s = 0;
    if (prefix.isNotEmpty) {
      s += protobuf.sizeTag(1) + protobuf.sizeBytes(prefix.length);
    }
    if (data.isNotEmpty) {
      s += protobuf.sizeTag(2) + protobuf.sizeBytes(data.length);
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (prefix.isNotEmpty) {
      protobuf.appendTag(buf, 1, 2);
      protobuf.appendBytes(buf, prefix);
    }
    if (data.isNotEmpty) {
      protobuf.appendTag(buf, 2, 2);
      protobuf.appendBytes(buf, data);
    }
    return Uint8List.fromList(buf);
  }

  static Block decode(Uint8List b) {
    var prefix = Uint8List(0);
    var data = Uint8List(0);

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = protobuf.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw protobuf.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          prefix = val!;
          p += consumed;
        case 2:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          data = val!;
          p += consumed;
        default:
          p = _skipField(b, p, type);
      }
    }

    return Block(prefix: prefix, data: data);
  }
}

/// BlockPresence represents HAVE or DONT_HAVE for a given CID.
/// Equivalent to `Message_BlockPresence`.
class BlockPresence {
  BlockPresence({Uint8List? cid, this.type = BlockPresenceType.have})
    : cid = cid ?? Uint8List(0);

  Uint8List cid;
  BlockPresenceType type;

  Uint8List getCid() => cid;
  BlockPresenceType getType() => type;

  int size() {
    var s = 0;
    if (cid.isNotEmpty) {
      s += protobuf.sizeTag(1) + protobuf.sizeBytes(cid.length);
    }
    if (type != BlockPresenceType.have) {
      s += protobuf.sizeTag(2) + protobuf.sizeVarint(Golang.Uint64(type.value));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (cid.isNotEmpty) {
      protobuf.appendTag(buf, 1, 2);
      protobuf.appendBytes(buf, cid);
    }
    if (type != BlockPresenceType.have) {
      protobuf.appendTag(buf, 2, 0);
      protobuf.appendVarint(buf, Golang.Uint64(type.value));
    }
    return Uint8List.fromList(buf);
  }

  static BlockPresence decode(Uint8List b) {
    var cid = Uint8List(0);
    var type = BlockPresenceType.have;

    var p = 0;
    while (p < b.length) {
      final (num, typeWire, n) = protobuf.consumeTag(
        Uint8List.sublistView(b, p),
      );
      if (n < 0) throw protobuf.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (typeWire != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          cid = val!;
          p += consumed;
        case 2:
          if (typeWire != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          type = BlockPresenceType.fromValue(
            val.toBigInt().toSigned(32).toInt(),
          );
          p += consumed;
        default:
          p = _skipField(b, p, typeWire);
      }
    }

    return BlockPresence(cid: cid, type: type);
  }
}

/// Message is the top-level Bitswap protobuf message.
/// Equivalent to `pb.Message`.
class Message {
  Message({
    this.wantlist,
    List<Uint8List>? blocks,
    List<Block>? payload,
    List<BlockPresence>? blockPresences,
    this.pendingBytes = 0,
  }) : blocks = blocks ?? <Uint8List>[],
       payload = payload ?? <Block>[],
       blockPresences = blockPresences ?? <BlockPresence>[];

  Wantlist? wantlist;
  List<Uint8List> blocks;
  List<Block> payload;
  List<BlockPresence> blockPresences;
  int pendingBytes;

  Wantlist? getWantlist() => wantlist;
  List<Uint8List> getBlocks() => blocks;
  List<Block> getPayload() => payload;
  List<BlockPresence> getBlockPresences() => blockPresences;
  int getPendingBytes() => pendingBytes;

  int size() {
    var s = 0;
    if (wantlist != null) {
      final wlSize = wantlist!.size();
      s += protobuf.sizeTag(1) + protobuf.sizeBytes(wlSize);
    }
    for (final blk in blocks) {
      s += protobuf.sizeTag(2) + protobuf.sizeBytes(blk.length);
    }
    for (final p in payload) {
      final pSize = p.size();
      s += protobuf.sizeTag(3) + protobuf.sizeBytes(pSize);
    }
    for (final bp in blockPresences) {
      final bpSize = bp.size();
      s += protobuf.sizeTag(4) + protobuf.sizeBytes(bpSize);
    }
    if (pendingBytes != 0) {
      s +=
          protobuf.sizeTag(5) +
          protobuf.sizeVarint(
            Golang.Uint64.fromBigInt(Golang.Int32(pendingBytes).toBigInt()),
          );
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (wantlist != null) {
      final wlBytes = wantlist!.encode();
      protobuf.appendTag(buf, 1, 2);
      protobuf.appendBytes(buf, wlBytes);
    }
    for (final blk in blocks) {
      protobuf.appendTag(buf, 2, 2);
      protobuf.appendBytes(buf, blk);
    }
    for (final p in payload) {
      final pBytes = p.encode();
      protobuf.appendTag(buf, 3, 2);
      protobuf.appendBytes(buf, pBytes);
    }
    for (final bp in blockPresences) {
      final bpBytes = bp.encode();
      protobuf.appendTag(buf, 4, 2);
      protobuf.appendBytes(buf, bpBytes);
    }
    if (pendingBytes != 0) {
      protobuf.appendTag(buf, 5, 0);
      protobuf.appendVarint(
        buf,
        Golang.Uint64.fromBigInt(Golang.Int32(pendingBytes).toBigInt()),
      );
    }
    return Uint8List.fromList(buf);
  }

  static Message decode(Uint8List b) {
    Wantlist? wantlist;
    final blocks = <Uint8List>[];
    final payload = <Block>[];
    final blockPresences = <BlockPresence>[];
    var pendingBytes = 0;

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = protobuf.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw protobuf.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          wantlist = Wantlist.decode(val!);
          p += consumed;
        case 2:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          blocks.add(val!);
          p += consumed;
        case 3:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          payload.add(Block.decode(val!));
          p += consumed;
        case 4:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeBytes(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          blockPresences.add(BlockPresence.decode(val!));
          p += consumed;
        case 5:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = protobuf.consumeVarint(
            Uint8List.sublistView(b, p),
          );
          if (consumed < 0) throw protobuf.parseError(consumed)!;
          pendingBytes = val.toBigInt().toSigned(32).toInt();
          p += consumed;
        default:
          p = _skipField(b, p, type);
      }
    }

    return Message(
      wantlist: wantlist,
      blocks: blocks,
      payload: payload,
      blockPresences: blockPresences,
      pendingBytes: pendingBytes,
    );
  }
}

int _skipField(Uint8List b, int offset, int wireType) {
  switch (wireType) {
    case 0:
      final (_, n) = protobuf.consumeVarint(Uint8List.sublistView(b, offset));
      if (n < 0) throw protobuf.parseError(n)!;
      return offset + n;
    case 1:
      final (_, n) = protobuf.consumeFixed64(Uint8List.sublistView(b, offset));
      if (n < 0) throw const FormatException('unexpected EOF');
      return offset + n;
    case 2:
      final (_, n) = protobuf.consumeBytes(Uint8List.sublistView(b, offset));
      if (n < 0) throw protobuf.parseError(n)!;
      return offset + n;
    case 5:
      final (_, n) = protobuf.consumeFixed32(Uint8List.sublistView(b, offset));
      if (n < 0) throw const FormatException('unexpected EOF');
      return offset + n;
    default:
      throw FormatException('cannot parse reserved wire type $wireType');
  }
}
