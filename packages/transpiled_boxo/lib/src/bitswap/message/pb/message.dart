// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/boxo/bitswap/message/pb.

import 'dart:typed_data';

// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_protobuf/protowire.dart' as wire;

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
      s += wire.sizeTag(1) + wire.sizeBytes(block.length);
    }
    if (priority != 0) {
      s += wire.sizeTag(2) +
          wire.sizeVarint(
            Golang.Uint64.fromBigInt(Golang.Int32(priority).toBigInt()),
          );
    }
    if (cancel) {
      s += wire.sizeTag(3) + wire.sizeVarint(Golang.Uint64(1));
    }
    if (wantType != WantType.block) {
      s += wire.sizeTag(4) + wire.sizeVarint(Golang.Uint64(wantType.value));
    }
    if (sendDontHave) {
      s += wire.sizeTag(5) + wire.sizeVarint(Golang.Uint64(1));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (block.isNotEmpty) {
      wire.appendTag(buf, 1, 2);
      wire.appendBytes(buf, block);
    }
    if (priority != 0) {
      wire.appendTag(buf, 2, 0);
      wire.appendVarint(
        buf,
        Golang.Uint64.fromBigInt(Golang.Int32(priority).toBigInt()),
      );
    }
    if (cancel) {
      wire.appendTag(buf, 3, 0);
      wire.appendVarint(buf, Golang.Uint64(1));
    }
    if (wantType != WantType.block) {
      wire.appendTag(buf, 4, 0);
      wire.appendVarint(buf, Golang.Uint64(wantType.value));
    }
    if (sendDontHave) {
      wire.appendTag(buf, 5, 0);
      wire.appendVarint(buf, Golang.Uint64(1));
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
      final (num, type, n) = wire.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw wire.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          block = val!;
          p += consumed;
        case 2:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          priority = val.toBigInt().toSigned(32).toInt();
          p += consumed;
        case 3:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          cancel = val != Golang.Uint64(0);
          p += consumed;
        case 4:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          wantType = WantType.fromValue(val.toBigInt().toSigned(32).toInt());
          p += consumed;
        case 5:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
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
  Wantlist({
    List<Entry>? entries,
    this.full = false,
  }) : entries = entries ?? <Entry>[];

  List<Entry> entries;
  bool full;

  List<Entry> getEntries() => entries;
  bool getFull() => full;

  int size() {
    var s = 0;
    for (final e in entries) {
      final esize = e.size();
      s += wire.sizeTag(1) + wire.sizeBytes(esize);
    }
    if (full) {
      s += wire.sizeTag(2) + wire.sizeVarint(Golang.Uint64(1));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    for (final e in entries) {
      final eBytes = e.encode();
      wire.appendTag(buf, 1, 2);
      wire.appendBytes(buf, eBytes);
    }
    if (full) {
      wire.appendTag(buf, 2, 0);
      wire.appendVarint(buf, Golang.Uint64(1));
    }
    return Uint8List.fromList(buf);
  }

  static Wantlist decode(Uint8List b) {
    final entries = <Entry>[];
    var full = false;

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = wire.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw wire.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          entries.add(Entry.decode(val!));
          p += consumed;
        case 2:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
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
  Block({
    Uint8List? prefix,
    Uint8List? data,
  })  : prefix = prefix ?? Uint8List(0),
        data = data ?? Uint8List(0);

  Uint8List prefix;
  Uint8List data;

  Uint8List getPrefix() => prefix;
  Uint8List getData() => data;

  int size() {
    var s = 0;
    if (prefix.isNotEmpty) {
      s += wire.sizeTag(1) + wire.sizeBytes(prefix.length);
    }
    if (data.isNotEmpty) {
      s += wire.sizeTag(2) + wire.sizeBytes(data.length);
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (prefix.isNotEmpty) {
      wire.appendTag(buf, 1, 2);
      wire.appendBytes(buf, prefix);
    }
    if (data.isNotEmpty) {
      wire.appendTag(buf, 2, 2);
      wire.appendBytes(buf, data);
    }
    return Uint8List.fromList(buf);
  }

  static Block decode(Uint8List b) {
    var prefix = Uint8List(0);
    var data = Uint8List(0);

    var p = 0;
    while (p < b.length) {
      final (num, type, n) = wire.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw wire.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          prefix = val!;
          p += consumed;
        case 2:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
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
  BlockPresence({
    Uint8List? cid,
    this.type = BlockPresenceType.have,
  }) : cid = cid ?? Uint8List(0);

  Uint8List cid;
  BlockPresenceType type;

  Uint8List getCid() => cid;
  BlockPresenceType getType() => type;

  int size() {
    var s = 0;
    if (cid.isNotEmpty) {
      s += wire.sizeTag(1) + wire.sizeBytes(cid.length);
    }
    if (type != BlockPresenceType.have) {
      s += wire.sizeTag(2) + wire.sizeVarint(Golang.Uint64(type.value));
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (cid.isNotEmpty) {
      wire.appendTag(buf, 1, 2);
      wire.appendBytes(buf, cid);
    }
    if (type != BlockPresenceType.have) {
      wire.appendTag(buf, 2, 0);
      wire.appendVarint(buf, Golang.Uint64(type.value));
    }
    return Uint8List.fromList(buf);
  }

  static BlockPresence decode(Uint8List b) {
    var cid = Uint8List(0);
    var type = BlockPresenceType.have;

    var p = 0;
    while (p < b.length) {
      final (num, typeWire, n) = wire.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw wire.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (typeWire != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          cid = val!;
          p += consumed;
        case 2:
          if (typeWire != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
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
  })  : blocks = blocks ?? <Uint8List>[],
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
      s += wire.sizeTag(1) + wire.sizeBytes(wlSize);
    }
    for (final blk in blocks) {
      s += wire.sizeTag(2) + wire.sizeBytes(blk.length);
    }
    for (final p in payload) {
      final pSize = p.size();
      s += wire.sizeTag(3) + wire.sizeBytes(pSize);
    }
    for (final bp in blockPresences) {
      final bpSize = bp.size();
      s += wire.sizeTag(4) + wire.sizeBytes(bpSize);
    }
    if (pendingBytes != 0) {
      s += wire.sizeTag(5) +
          wire.sizeVarint(
            Golang.Uint64.fromBigInt(Golang.Int32(pendingBytes).toBigInt()),
          );
    }
    return s;
  }

  Uint8List encode() {
    final buf = <int>[];
    if (wantlist != null) {
      final wlBytes = wantlist!.encode();
      wire.appendTag(buf, 1, 2);
      wire.appendBytes(buf, wlBytes);
    }
    for (final blk in blocks) {
      wire.appendTag(buf, 2, 2);
      wire.appendBytes(buf, blk);
    }
    for (final p in payload) {
      final pBytes = p.encode();
      wire.appendTag(buf, 3, 2);
      wire.appendBytes(buf, pBytes);
    }
    for (final bp in blockPresences) {
      final bpBytes = bp.encode();
      wire.appendTag(buf, 4, 2);
      wire.appendBytes(buf, bpBytes);
    }
    if (pendingBytes != 0) {
      wire.appendTag(buf, 5, 0);
      wire.appendVarint(
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
      final (num, type, n) = wire.consumeTag(Uint8List.sublistView(b, p));
      if (n < 0) throw wire.parseError(n)!;
      p += n;
      switch (num) {
        case 1:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          wantlist = Wantlist.decode(val!);
          p += consumed;
        case 2:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          blocks.add(val!);
          p += consumed;
        case 3:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          payload.add(Block.decode(val!));
          p += consumed;
        case 4:
          if (type != 2) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeBytes(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
          blockPresences.add(BlockPresence.decode(val!));
          p += consumed;
        case 5:
          if (type != 0) throw const FormatException('invalid wire type');
          final (val, consumed) = wire.consumeVarint(Uint8List.sublistView(b, p));
          if (consumed < 0) throw wire.parseError(consumed)!;
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
      final (_, n) = wire.consumeVarint(Uint8List.sublistView(b, offset));
      if (n < 0) throw wire.parseError(n)!;
      return offset + n;
    case 1:
      final (_, n) = wire.consumeFixed64(Uint8List.sublistView(b, offset));
      if (n < 0) throw const FormatException('unexpected EOF');
      return offset + n;
    case 2:
      final (_, n) = wire.consumeBytes(Uint8List.sublistView(b, offset));
      if (n < 0) throw wire.parseError(n)!;
      return offset + n;
    case 5:
      final (_, n) = wire.consumeFixed32(Uint8List.sublistView(b, offset));
      if (n < 0) throw const FormatException('unexpected EOF');
      return offset + n;
    default:
      throw FormatException('cannot parse reserved wire type $wireType');
  }
}
