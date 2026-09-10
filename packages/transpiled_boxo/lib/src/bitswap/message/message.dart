// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/boxo/bitswap/message.

import 'dart:typed_data';

// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_block_format/transpiled_block_format.dart'
    as block_format;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

import '../client/wantlist/wantlist.dart' as wantlist;
import 'pb/message.dart' as pb;

/// Maximum message size in bytes from go-libp2p network.MessageSizeMax (4 MiB).
const int messageSizeMax = 1 << 22;

/// Reader abstracts an input stream of bytes, equivalent to Go's io.Reader.
abstract interface class Reader {
  /// Reads up to [p.length] bytes into [p]. Returns the number of bytes read,
  /// or 0 when at EOF.
  int read(List<int> p);
}

/// Writer abstracts an output stream of bytes, equivalent to Go's io.Writer.
abstract interface class Writer {
  /// Writes all bytes in [p].
  void write(List<int> p);
}

/// ByteReader implements [Reader] over an existing byte list.
class ByteReader implements Reader {
  ByteReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  @override
  int read(List<int> p) {
    if (_offset >= _bytes.length) return 0;
    final available = _bytes.length - _offset;
    final toRead = p.length < available ? p.length : available;
    p.setRange(0, toRead, _bytes, _offset);
    _offset += toRead;
    return toRead;
  }
}

/// Buffer is a byte buffer implementing both [Reader] and [Writer],
/// equivalent to Go's bytes.Buffer.
class Buffer implements Reader, Writer {
  Buffer([List<int>? initial]) {
    if (initial != null) {
      _buf.addAll(initial);
    }
  }

  final List<int> _buf = <int>[];
  int _readOffset = 0;

  @override
  int read(List<int> p) {
    if (_readOffset >= _buf.length) return 0;
    final available = _buf.length - _readOffset;
    final toRead = p.length < available ? p.length : available;
    p.setRange(0, toRead, _buf.sublist(_readOffset, _readOffset + toRead));
    _readOffset += toRead;
    return toRead;
  }

  @override
  void write(List<int> p) {
    _buf.addAll(p);
  }

  /// Number of unread bytes.
  int get length => _buf.length - _readOffset;

  /// Returns unread bytes as a Uint8List.
  Uint8List toBytes() => Uint8List.fromList(_buf.sublist(_readOffset));

  /// Returns unread bytes as a Uint8List, equivalent to Go's Buffer.Bytes().
  Uint8List bytes() => toBytes();
}

/// MsgReader is an interface for reading length-delimited messages,
/// equivalent to Go's msgio.Reader.
abstract interface class MsgReader {
  Uint8List readMsg();
  void releaseMsg(Uint8List msg);
}

/// VarintReader implements [MsgReader] reading uvarint-framed messages,
/// equivalent to Go's msgio.NewVarintReaderSize.
class VarintReader implements MsgReader {
  VarintReader(this.reader, [this.maxSize = messageSizeMax]);

  final Reader reader;
  final int maxSize;

  @override
  Uint8List readMsg() {
    var value = Golang.Uint64();
    var shift = 0;
    var done = false;
    final oneByte = Uint8List(1);

    for (var i = 0; i < 10; i++) {
      final n = reader.read(oneByte);
      if (n <= 0) {
        if (i == 0) {
          throw const FormatException('EOF reading varint length');
        }
        throw errUnderflow;
      }
      final b = oneByte[0];
      if ((i == 8 && b >= 128) || i >= 9) {
        throw errOverflow;
      }
      if (b < 128) {
        if (b == 0 && shift > 0) {
          throw errNotMinimal;
        }
        value = value | (Golang.Uint64(b) << shift);
        done = true;
        break;
      }
      value = value | (Golang.Uint64(b & 127) << shift);
      shift += 7;
    }

    if (!done) {
      throw errUnderflow;
    }

    final length = Golang.Int64.fromUint64(value).toIntExact();
    if (length < 0 || length > maxSize) {
      throw FormatException(
        'message size ($length bytes) exceeds maximum ($maxSize bytes)',
      );
    }

    final msg = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final slice = Uint8List.sublistView(msg, offset);
      final n = reader.read(slice);
      if (n <= 0) {
        throw const FormatException('unexpected EOF reading message payload');
      }
      offset += n;
    }

    return msg;
  }

  @override
  void releaseMsg(Uint8List msg) {}
}

/// BlockPresence represents a HAVE / DONT_HAVE for a given Cid.
class BlockPresence {
  BlockPresence(this.cid, this.type);

  final Cid cid;
  final pb.BlockPresenceType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockPresence && cid == other.cid && type == other.type;

  @override
  int get hashCode => Object.hash(cid, type);

  @override
  String toString() => 'BlockPresence($cid, $type)';
}

/// Entry is a wantlist entry in a Bitswap message, with flags indicating:
/// - whether message is a cancel
/// - whether requester wants a DONT_HAVE message
/// - whether requester wants a HAVE message (instead of the block)
class Entry {
  Entry({
    Cid? cid,
    int? priority,
    pb.WantType? wantType,
    wantlist.Entry? entry,
    this.cancel = false,
    this.sendDontHave = false,
  })  : cid = cid ?? entry!.cid,
        priority = priority ?? entry!.priority,
        wantType = wantType ?? entry!.wantType;

  factory Entry.fromWantlistEntry(
    wantlist.Entry entry, {
    bool cancel = false,
    bool sendDontHave = false,
  }) =>
      Entry(
        cid: entry.cid,
        priority: entry.priority,
        wantType: entry.wantType,
        cancel: cancel,
        sendDontHave: sendDontHave,
      );

  Cid cid;
  int priority;
  pb.WantType wantType;
  bool cancel;
  bool sendDontHave;

  wantlist.Entry get entry => wantlist.Entry(
        cid: cid,
        priority: priority,
        wantType: wantType,
      );

  int size() => toPb().size();

  pb.Entry toPb() => pb.Entry(
        block: cid.toBytes(),
        priority: priority,
        cancel: cancel,
        wantType: wantType,
        sendDontHave: sendDontHave,
      );

  Entry clone() => Entry(
        cid: cid,
        priority: priority,
        wantType: wantType,
        cancel: cancel,
        sendDontHave: sendDontHave,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entry &&
          cid == other.cid &&
          priority == other.priority &&
          wantType == other.wantType &&
          cancel == other.cancel &&
          sendDontHave == other.sendDontHave;

  @override
  int get hashCode =>
      Object.hash(cid, priority, wantType, cancel, sendDontHave);

  @override
  String toString() =>
      'Entry($cid, priority: $priority, wantType: $wantType, cancel: $cancel, sendDontHave: $sendDontHave)';
}

/// Exportable is an interface for structures that can be encoded in a bitswap protobuf.
abstract interface class Exportable {
  pb.Message toProtoV0();
  pb.Message toProtoV1();
  void toNetV0(Object w);
  void toNetV1(Object w);
}

/// BitSwapMessage is the basic interface for interacting, building, encoding,
/// and decoding messages sent on the Bitswap protocol.
abstract interface class BitSwapMessage implements Exportable {
  factory BitSwapMessage([bool full]) = Impl;
  factory BitSwapMessage.fromProto(pb.Message pbm) => _newMessageFromProto(pbm);

  /// Decodes raw protobuf bytes into a [BitSwapMessage].
  static BitSwapMessage fromBytes(Uint8List bytes) =>
      BitSwapMessage.fromProto(pb.Message.decode(bytes));

  List<Entry> fillWantlist(List<Entry> out);
  List<Entry> wantlist();
  List<block_format.Block> blocks();
  List<BlockPresence> blockPresences();
  List<Cid> haves();
  List<Cid> dontHaves();
  int pendingBytes();

  int addEntry(
    Cid key,
    int priority,
    pb.WantType wantType,
    bool sendDontHave,
  );

  int cancel(Cid key);
  void remove(Cid key);
  bool empty();
  int size();
  bool full();

  void addBlock(block_format.Block block);
  void addBlockPresence(Cid cid, pb.BlockPresenceType type);
  void addHave(Cid cid);
  void addDontHave(Cid cid);
  void setPendingBytes(int pendingBytes);

  Map<String, dynamic> loggable();
  void reset(bool full);
  BitSwapMessage clone();
}

/// Impl is the canonical implementation of [BitSwapMessage], equivalent to Go's `impl`.
class Impl implements BitSwapMessage {
  Impl([this._full = false]);

  bool _full;
  final Map<Cid, Entry> _wantlist = <Cid, Entry>{};
  final Map<Cid, block_format.Block> _blocks = <Cid, block_format.Block>{};
  final Map<Cid, pb.BlockPresenceType> _blockPresences =
      <Cid, pb.BlockPresenceType>{};
  int _pendingBytes = 0;

  @override
  bool full() => _full;

  @override
  bool empty() =>
      _blocks.isEmpty && _wantlist.isEmpty && _blockPresences.isEmpty;

  @override
  List<Entry> fillWantlist(List<Entry> out) {
    out.clear();
    for (final e in _wantlist.values) {
      out.add(e.clone());
    }
    return out;
  }

  @override
  List<Entry> wantlist() =>
      _wantlist.values.map((e) => e.clone()).toList();

  @override
  List<block_format.Block> blocks() => _blocks.values.toList();

  @override
  List<BlockPresence> blockPresences() => _blockPresences.entries
      .map((e) => BlockPresence(e.key, e.value))
      .toList();

  @override
  List<Cid> haves() => _getBlockPresenceByType(pb.BlockPresenceType.have);

  @override
  List<Cid> dontHaves() =>
      _getBlockPresenceByType(pb.BlockPresenceType.dontHave);

  List<Cid> _getBlockPresenceByType(pb.BlockPresenceType t) {
    final cids = <Cid>[];
    for (final entry in _blockPresences.entries) {
      if (entry.value == t) {
        cids.add(entry.key);
      }
    }
    return cids;
  }

  @override
  int pendingBytes() => _pendingBytes;

  @override
  void setPendingBytes(int pendingBytes) {
    _pendingBytes = pendingBytes;
  }

  @override
  void remove(Cid key) {
    _wantlist.remove(key);
  }

  @override
  int cancel(Cid key) =>
      _addEntry(key, 0, true, pb.WantType.block, false);

  @override
  int addEntry(
    Cid key,
    int priority,
    pb.WantType wantType,
    bool sendDontHave,
  ) =>
      _addEntry(key, priority, false, wantType, sendDontHave);

  int _addEntry(
    Cid c,
    int priority,
    bool cancel,
    pb.WantType wantType,
    bool sendDontHave,
  ) {
    final existing = _wantlist[c];
    if (existing != null) {
      if (existing.wantType == wantType) {
        existing.priority = priority;
      }
      if (cancel) {
        existing.cancel = cancel;
      }
      if (sendDontHave) {
        existing.sendDontHave = sendDontHave;
      }
      if (wantType == pb.WantType.block &&
          existing.wantType == pb.WantType.have) {
        existing.wantType = wantType;
      }
      _wantlist[c] = existing;
      return 0;
    }

    final entry = Entry(
      cid: c,
      priority: priority,
      wantType: wantType,
      cancel: cancel,
      sendDontHave: sendDontHave,
    );
    _wantlist[c] = entry;
    return entry.size();
  }

  /// Direct raw entry insertion for internal / protobuf decoding use.
  void addEntryRaw(
    Cid c,
    int priority,
    bool cancel,
    pb.WantType wantType,
    bool sendDontHave,
  ) {
    _addEntry(c, priority, cancel, wantType, sendDontHave);
  }

  @override
  void addBlock(block_format.Block b) {
    _blockPresences.remove(b.cid());
    _blocks[b.cid()] = b;
  }

  @override
  void addBlockPresence(Cid cid, pb.BlockPresenceType type) {
    if (_blocks.containsKey(cid)) {
      return;
    }
    _blockPresences[cid] = type;
  }

  @override
  void addHave(Cid cid) =>
      addBlockPresence(cid, pb.BlockPresenceType.have);

  @override
  void addDontHave(Cid cid) =>
      addBlockPresence(cid, pb.BlockPresenceType.dontHave);

  @override
  int size() {
    var s = 0;
    for (final block in _blocks.values) {
      s += block.rawData().length;
    }
    for (final c in _blockPresences.keys) {
      s += blockPresenceSize(c);
    }
    for (final e in _wantlist.values) {
      s += e.size();
    }
    return s;
  }

  @override
  pb.Message toProtoV0() {
    final pbm = pb.Message(
      wantlist: pb.Wantlist(
        entries: _wantlist.values.map((e) => e.toPb()).toList(),
        full: _full,
      ),
      blocks: _blocks.values.map((b) => b.rawData()).toList(),
    );
    return pbm;
  }

  @override
  pb.Message toProtoV1() {
    final pbm = pb.Message(
      wantlist: pb.Wantlist(
        entries: _wantlist.values.map((e) => e.toPb()).toList(),
        full: _full,
      ),
      payload: _blocks.values
          .map(
            (b) => pb.Block(
              data: b.rawData(),
              prefix: b.cid().prefix.bytes(),
            ),
          )
          .toList(),
      blockPresences: _blockPresences.entries
          .map((e) => pb.BlockPresence(cid: e.key.toBytes(), type: e.value))
          .toList(),
      pendingBytes: _pendingBytes,
    );
    return pbm;
  }

  @override
  void toNetV0(Object w) => _writeTo(w, toProtoV0());

  @override
  void toNetV1(Object w) => _writeTo(w, toProtoV1());

  @override
  Map<String, dynamic> loggable() => <String, dynamic>{
        'blocks': _blocks.values.map((v) => v.cid().toString()).toList(),
        'wants': wantlist(),
      };

  @override
  void reset(bool full) {
    _full = full;
    _wantlist.clear();
    _blocks.clear();
    _blockPresences.clear();
    _pendingBytes = 0;
  }

  @override
  BitSwapMessage clone() {
    final cl = Impl(_full);
    for (final e in _wantlist.entries) {
      cl._wantlist[e.key] = e.value.clone();
    }
    cl._blocks.addAll(_blocks);
    cl._blockPresences.addAll(_blockPresences);
    cl._pendingBytes = _pendingBytes;
    return cl;
  }
}

/// Returns the size in bytes of a BlockPresence entry in protobuf.
int blockPresenceSize(Cid c) => pb.BlockPresence(
      cid: c.toBytes(),
      type: pb.BlockPresenceType.have,
    ).size();

/// Creates a block from payload bytes and Cid prefix.
block_format.Block wantlistBlock(
  Uint8List bs, [
  Cid? c,
  Prefix? prefix,
]) {
  final Prefix pref;
  if (prefix != null) {
    pref = prefix;
  } else if (c != null) {
    pref = c.prefix;
  } else {
    throw ArgumentError('either prefix or cid must be provided');
  }

  final blockCid = pref.sum(bs);
  if (c != null) {
    if (blockCid != c) {
      throw const block_format.WrongHashException();
    }
  }
  return block_format.BasicBlock.withCid(bs, blockCid);
}

BitSwapMessage _newMessageFromProto(pb.Message pbm) {
  final m = Impl(pbm.wantlist != null && pbm.wantlist!.full);

  final wl = pbm.wantlist;
  if (wl != null) {
    for (final e in wl.entries) {
      if (e.block.isEmpty) {
        throw const FormatException('missing cid');
      }
      final c = Cid.fromBytes(e.block);
      m.addEntryRaw(c, e.priority, e.cancel, e.wantType, e.sendDontHave);
    }
  }

  for (final d in pbm.blocks) {
    final b = block_format.BasicBlock.fromData(d);
    m.addBlock(b);
  }

  for (final b in pbm.payload) {
    final pref = Prefix.fromBytes(b.prefix);
    final blk = wantlistBlock(b.data, null, pref);
    m.addBlock(blk);
  }

  for (final bi in pbm.blockPresences) {
    if (bi.cid.isEmpty) {
      throw const FormatException('missing cid');
    }
    final c = Cid.fromBytes(bi.cid);
    m.addBlockPresence(c, bi.type);
  }

  m.setPendingBytes(pbm.pendingBytes);
  return m;
}

/// Generates a new [BitSwapMessage] from incoming data on a reader,
/// equivalent to Go's `FromNet(r io.Reader)`.
(BitSwapMessage, int) fromNet(Object r) {
  final MsgReader reader;
  if (r is MsgReader) {
    reader = r;
  } else if (r is Reader) {
    reader = VarintReader(r, messageSizeMax);
  } else if (r is Uint8List) {
    reader = VarintReader(ByteReader(r), messageSizeMax);
  } else if (r is List<int>) {
    reader = VarintReader(ByteReader(Uint8List.fromList(r)), messageSizeMax);
  } else if (r is BytesBuilder) {
    reader = VarintReader(ByteReader(r.toBytes()), messageSizeMax);
  } else {
    throw ArgumentError('Unsupported reader type: ${r.runtimeType}');
  }
  return fromMsgReader(reader);
}

/// Generates a new [BitSwapMessage] from a [MsgReader],
/// equivalent to Go's `FromMsgReader(r msgio.Reader)`.
(BitSwapMessage, int) fromMsgReader(MsgReader r) {
  final msg = r.readMsg();
  final pbm = pb.Message.decode(msg);
  r.releaseMsg(msg);
  final m = BitSwapMessage.fromProto(pbm);
  return (m, msg.length);
}

void _writeTo(Object w, pb.Message m) {
  final msgBytes = m.encode();
  final lenBytes = toUvarint(Golang.Uint64(msgBytes.length));
  final frame = Uint8List(lenBytes.length + msgBytes.length)
    ..setRange(0, lenBytes.length, lenBytes)
    ..setRange(lenBytes.length, lenBytes.length + msgBytes.length, msgBytes);

  if (w is Writer) {
    w.write(frame);
  } else if (w is BytesBuilder) {
    w.add(frame);
  } else if (w is Sink<List<int>>) {
    w.add(frame);
  } else if (w is List<int>) {
    w.addAll(frame);
  } else {
    try {
      (w as dynamic).write(frame);
    } catch (_) {
      try {
        (w as dynamic).add(frame);
      } catch (_) {
        throw ArgumentError('Unsupported writer type: ${w.runtimeType}');
      }
    }
  }
}
