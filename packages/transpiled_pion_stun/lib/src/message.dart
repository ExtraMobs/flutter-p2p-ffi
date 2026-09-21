/// Port of `message.go` (pion/stun v3.1.1).
///
/// `io.Writer`/`io.Reader` (`WriteTo`/`ReadFrom`) become `Future`-returning
/// methods over [NetConn] (the same connection abstraction `client.dart`
/// uses; see that file for why `NetConn` from `transpiled_pion_transport_v4`
/// doubles as this package's `Connection`), matching this codebase's
/// idiomatic Dart mapping of Go I/O interfaces to `Future`/`Stream`
/// (AGENTS.md, "variádicos, canais, goroutines ... usam o equivalente Dart
/// mais próximo"). `GobEncode`/`GobDecode` (message.go:101-108) are not
/// ported: they exist only to satisfy Go's `encoding/gob` binary
/// serialization format, which has no Dart counterpart and no consumer in
/// this codebase; both trivially delegated to `MarshalBinary`/
/// `UnmarshalBinary` anyway; [marshalBinary]/[unmarshalBinary] below serve
/// the identical purpose.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

import 'attributes.dart';
import 'errors.dart';
import 'helpers.dart';

/// Port of `magicCookie` (message.go:23).
const int magicCookie = 0x2112A442;

/// Port of `attributeHeaderSize` (message.go:24).
const int attributeHeaderSize = 4;

/// Port of `messageHeaderSize` (message.go:25).
const int messageHeaderSize = 20;

/// Port of `TransactionIDSize` (message.go:28): length of the transaction
/// ID array, in bytes (96 bit).
const int transactionIdSize = 12;

final Random _secureRandom = Random.secure();

/// Port of `NewTransactionID` (message.go:33-37): returns a new random
/// transaction ID using a cryptographically secure source. Not spelled
/// `newTransactionId` (AGENTS.md, "RULE_NO_NEW_X_FUNCTIONS"): Go's function
/// returns a raw `[12]byte`, not an instance of some `TransactionId` type,
/// so there is no class to attach a factory constructor to instead.
Uint8List randomTransactionId() {
  final b = Uint8List(transactionIdSize);
  for (var i = 0; i < b.length; i++) {
    b[i] = _secureRandom.nextInt(256);
  }
  return b;
}

/// Port of `IsMessage` (message.go:41-44): returns true if [b] looks like a
/// STUN message. Useful for multiplexing; does not guarantee decoding will
/// succeed.
bool isMessage(Uint8List b) {
  return b.length >= messageHeaderSize &&
      ByteData.sublistView(b).getUint32(4, Endian.big) == magicCookie;
}

/// Port of `ErrDecodeToNil` (message.go:56): occurs on `Decode(data, nil)`.
/// Not reachable in Dart (there is no nullable-`Message` overload of
/// [decode]); kept only as documentation of the upstream sentinel.
final class DecodeToNilException implements Exception {
  const DecodeToNilException();

  @override
  String toString() => 'attempt to decode to nil message';
}

/// Port of `Decode` (message.go:59-66): decodes a [Message] from [data]
/// into [m].
void decode(Uint8List data, Message m) {
  m.raw = Uint8List.fromList(data);
  m.decode();
}

/// Port of `Message` (message.go:74-80): a single STUN packet.
final class Message implements Setter {
  /// Port of `New` (message.go:47-53): a [Message] with pre-allocated
  /// [raw].
  Message() : raw = Uint8List(messageHeaderSize);

  MessageType type = MessageType(
    method: Method(0),
    messageClass: MessageClass.request,
  );

  /// `len(Raw)` not including header.
  int length = 0;
  Uint8List transactionId = Uint8List(transactionIdSize);
  List<RawAttribute> attributes = <RawAttribute>[];
  Uint8List raw;

  /// Port of `Message.MarshalBinary` (message.go:83-90).
  Uint8List marshalBinary() => Uint8List.fromList(raw);

  /// Port of `Message.UnmarshalBinary` (message.go:93-98).
  void unmarshalBinary(Uint8List data) {
    raw = Uint8List.fromList(data);
    decode();
  }

  /// Port of `Message.AddTo` (message.go:113-118): sets `b.transactionId`
  /// to `transactionId`. Implements [Setter] to aid in crafting responses.
  @override
  void addTo(Message b) {
    b.transactionId = transactionId;
    b.writeTransactionId();
  }

  /// Port of `Message.NewTransactionID` (message.go:122-129): sets
  /// [transactionId] to a random value from a cryptographically secure
  /// source. Duplicates the top-level [randomTransactionId] function's
  /// 3-line body rather than calling it: within this method's own scope, a
  /// bare
  /// call would resolve to this same-named instance method (implicit
  /// `this.`), not the top-level function -- unlike Go's single flat
  /// package namespace, where the method and function can't collide
  /// because Go spells them `Message.NewTransactionID` vs.
  /// `stun.NewTransactionID`.
  void newTransactionId() {
    final b = Uint8List(transactionIdSize);
    for (var i = 0; i < b.length; i++) {
      b[i] = _secureRandom.nextInt(256);
    }
    transactionId = b;
    writeTransactionId();
  }

  /// Port of `Message.String` (message.go:131-139).
  @override
  String toString() {
    final tId = base64Encode(transactionId);
    final aInfo = StringBuffer();
    for (var k = 0; k < attributes.length; k++) {
      aInfo.write('attr$k=${attributes[k].type} ');
    }
    return '$type l=$length attrs=${attributes.length} id=$tId, $aInfo';
  }

  /// Port of `Message.Reset` (message.go:142-146): resets the message,
  /// attributes and underlying buffer length.
  void reset() {
    raw = raw.sublist(0, 0);
    length = 0;
    attributes = <RawAttribute>[];
  }

  /// Port of `Message.grow` (message.go:149-159): ensures the internal
  /// buffer has length [n].
  void grow(int n) {
    if (raw.length >= n) return;
    final grown = Uint8List(n);
    grown.setRange(0, raw.length, raw);
    raw = grown;
  }

  /// Port of `Message.Add` (message.go:165-217): appends a new attribute to
  /// the message. Not goroutine/isolate-safe. `val` is copied to the
  /// internal buffer so it is safe to reuse.
  void add(AttrType attrType, Uint8List val) {
    final allocSize = attributeHeaderSize + val.length;
    final first = messageHeaderSize + length;
    var last = first + allocSize;
    grow(last);
    length += allocSize;

    final buf = ByteData.sublistView(raw, first, last);
    final valueOffset = first + attributeHeaderSize;
    buf.setUint16(0, attrType.value, Endian.big);
    // Go writes `uint16(len(val))` for the TLV length, a truncating
    // conversion; mask instead of letting ByteData.setUint16 throw.
    buf.setUint16(2, val.length & 0xFFFF, Endian.big);
    raw.setRange(valueOffset, valueOffset + val.length, val);

    if (val.length % padding != 0) {
      final bytesToAdd = nearestPaddedValueLength(val.length) - val.length;
      last += bytesToAdd;
      grow(last);
      for (var i = last - bytesToAdd; i < last; i++) {
        raw[i] = 0;
      }
      length += bytesToAdd;
    }
    attributes = List<RawAttribute>.of(attributes)
      ..add(
        RawAttribute(
          type: attrType,
          length: val.length,
          value: Uint8List.sublistView(
            raw,
            valueOffset,
            valueOffset + val.length,
          ),
        ),
      );
    writeLength();
  }

  static bool _attrSliceEqual(List<RawAttribute> a, List<RawAttribute> b) {
    for (final attr in a) {
      var found = false;
      for (final attrB in b) {
        if (attrB.type != attr.type) continue;
        if (attrB.equalTo(attr)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  static bool _attrEqual(List<RawAttribute>? a, List<RawAttribute>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    if (!_attrSliceEqual(a, b)) return false;
    if (!_attrSliceEqual(b, a)) return false;
    return true;
  }

  /// Port of `Message.Equal` (message.go:262-283): returns true if [msg]
  /// equals this message. Ignores [raw].
  bool equalTo(Message? msg) {
    if (msg == null) return false;
    if (type != msg.type) return false;
    if (!_transactionIdEqual(transactionId, msg.transactionId)) return false;
    if (length != msg.length) return false;
    if (!_attrEqual(attributes, msg.attributes)) return false;
    return true;
  }

  static bool _transactionIdEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Port of `Message.WriteLength` (message.go:286-289).
  void writeLength() {
    grow(4);
    // Go writes `uint16(m.Length)`: `Length` is `uint32` in memory but the
    // wire field is 16 bits, so this is a real truncating conversion, not
    // just defensive masking.
    ByteData.sublistView(raw).setUint16(2, length & 0xFFFF, Endian.big);
  }

  /// Port of `Message.WriteHeader` (message.go:292-300).
  void writeHeader() {
    grow(messageHeaderSize);
    writeType();
    writeLength();
    ByteData.sublistView(raw).setUint32(4, magicCookie, Endian.big);
    raw.setRange(8, messageHeaderSize, transactionId);
  }

  /// Port of `Message.WriteTransactionID` (message.go:303-305).
  void writeTransactionId() {
    raw.setRange(8, messageHeaderSize, transactionId);
  }

  /// Port of `Message.WriteAttributes` (message.go:308-315).
  void writeAttributes() {
    final current = attributes;
    attributes = <RawAttribute>[];
    for (final a in current) {
      add(a.type, a.value);
    }
  }

  /// Port of `Message.WriteType` (message.go:318-321).
  void writeType() {
    grow(2);
    ByteData.sublistView(raw).setUint16(0, type.value(), Endian.big);
  }

  /// Port of `Message.SetType` (message.go:324-327).
  void setType(MessageType t) {
    type = t;
    writeType();
  }

  /// Port of `Message.Encode` (message.go:330-335): re-encodes the message
  /// into [raw].
  void encode() {
    raw = raw.sublist(0, 0);
    writeHeader();
    length = 0;
    writeAttributes();
  }

  /// Port of `Message.WriteTo` (message.go:339-343), adapted to this
  /// codebase's `Future`-based [NetConn] (see file-level doc comment).
  Future<int> writeTo(NetConn w) => w.write(raw);

  /// Port of `Message.ReadFrom` (message.go:350-362), adapted to
  /// [NetConn].
  Future<int> readFrom(NetConn r) async {
    final tBuf = Uint8List(max(raw.length, 1500));
    final n = await r.read(tBuf);
    raw = Uint8List.sublistView(tBuf, 0, n);
    decode();
    return n;
  }

  /// Port of `Message.Decode` (message.go:369-431): decodes [raw] into this
  /// message.
  void decode() {
    final buf = raw;
    if (buf.length < messageHeaderSize) {
      throw const UnexpectedHeaderEofException();
    }
    final header = ByteData.sublistView(buf);
    final msgType = header.getUint16(0, Endian.big);
    final size = header.getUint16(2, Endian.big);
    final cookie = header.getUint32(4, Endian.big);
    final fullSize = messageHeaderSize + size;
    if (cookie != magicCookie) {
      throw DecodeException.at(
        'message',
        'cookie',
        '${cookie.toRadixString(16)} is invalid magic cookie '
            '(should be ${magicCookie.toRadixString(16)})',
      );
    }
    if (buf.length < fullSize) {
      throw DecodeException.forAttribute(
        'message',
        'buffer length ${buf.length} is less than $fullSize '
            '(expected message size)',
      );
    }
    type.readValue(msgType);
    length = size;
    transactionId = Uint8List.sublistView(buf, 8, messageHeaderSize);

    final newAttributes = <RawAttribute>[];
    var offset = 0;
    var b = Uint8List.sublistView(buf, messageHeaderSize, fullSize);
    while (offset < size) {
      if (b.length < attributeHeaderSize) {
        throw DecodeException.forAttribute(
          'header',
          'buffer length ${b.length} is less than $attributeHeaderSize '
              '(expected header size)',
        );
      }
      final aHeader = ByteData.sublistView(b);
      final attrTypeValue = compatAttrType(aHeader.getUint16(0, Endian.big));
      final aLength = aHeader.getUint16(2, Endian.big);
      final aBuffLength = nearestPaddedValueLength(aLength);
      b = Uint8List.sublistView(b, attributeHeaderSize);
      offset += attributeHeaderSize;
      if (b.length < aBuffLength) {
        throw DecodeException.forAttribute(
          'value',
          'buffer length ${b.length} is less than $aBuffLength '
              '(expected value size for $attrTypeValue)',
        );
      }
      newAttributes.add(
        RawAttribute(
          type: attrTypeValue,
          length: aLength,
          value: Uint8List.sublistView(b, 0, aLength),
        ),
      );
      offset += aBuffLength;
      b = Uint8List.sublistView(b, aBuffLength);
    }
    attributes = newAttributes;
  }

  /// Port of `Message.Write` (message.go:436-440): decodes the message from
  /// [tBuf], returning the number of bytes consumed. Any thrown exception
  /// is unrecoverable, but the message could be partially decoded.
  int write(Uint8List tBuf) {
    raw = Uint8List.fromList(tBuf);
    decode();
    return tBuf.length;
  }

  /// Port of `Message.CloneTo` (message.go:443-447).
  void cloneTo(Message b) {
    b.raw = Uint8List.fromList(raw);
    b.decode();
  }

  /// Port of `Message.Contains` (message.go:628-636).
  bool contains(AttrType t) {
    for (final a in attributes) {
      if (a.type == t) return true;
    }
    return false;
  }
}

/// Port of `ErrUnexpectedHeaderEOF` (message.go:366).
final class UnexpectedHeaderEofException implements Exception {
  const UnexpectedHeaderEofException();

  @override
  String toString() => 'unexpected EOF: not enough bytes to read header';
}

/// Port of `MessageClass` (message.go:450): the 2-bit class of a STUN
/// Message Type, represented as a byte.
final class MessageClass {
  const MessageClass._(this.value);

  final int value;

  static const MessageClass request = MessageClass._(0x00);
  static const MessageClass indication = MessageClass._(0x01);
  static const MessageClass successResponse = MessageClass._(0x02);
  static const MessageClass errorResponse = MessageClass._(0x03);

  /// Port of `MessageClass.String` (message.go:470-483). Throws
  /// [StateError] for a class value outside 0-3, mirroring Go's
  /// `panic("unknown message class")` for a value that cannot arise from
  /// [MessageType.readValue] (which only ever extracts 2 bits) and can only
  /// happen via direct, off-label construction.
  @override
  String toString() {
    switch (value) {
      case 0x00:
        return 'request';
      case 0x01:
        return 'indication';
      case 0x02:
        return 'success response';
      case 0x03:
        return 'error response';
      default:
        throw StateError('unknown message class');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MessageClass && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Port of `Method` (message.go:486): a 12-bit STUN method, represented as
/// uint16.
final class Method {
  const Method(this.value);

  final int value;

  static const Method binding = Method(0x001);
  static const Method allocate = Method(0x003);
  static const Method refresh = Method(0x004);
  static const Method send = Method(0x006);
  static const Method data = Method(0x007);
  static const Method createPermission = Method(0x008);
  static const Method channelBind = Method(0x009);

  // RFC 6062.
  static const Method connect = Method(0x000a);
  static const Method connectionBind = Method(0x000b);
  static const Method connectionAttempt = Method(0x000c);

  static final Map<Method, String> _names = {
    binding: 'Binding',
    allocate: 'Allocate',
    refresh: 'Refresh',
    send: 'Send',
    data: 'Data',
    createPermission: 'CreatePermission',
    channelBind: 'ChannelBind',
    connect: 'Connect',
    connectionBind: 'ConnectionBind',
    connectionAttempt: 'ConnectionAttempt',
  };

  /// Port of `Method.String` (message.go:523-531).
  @override
  String toString() => _names[this] ?? '0x${value.toRadixString(16)}';

  @override
  bool operator ==(Object other) => other is Method && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

const int _methodABits = 0xf;
const int _methodBBits = 0x70;
const int _methodDBits = 0xf80;
const int _methodBShift = 1;
const int _methodDShift = 2;
const int _firstBit = 0x1;
const int _secondBit = 0x2;
const int _c0Bit = _firstBit;
const int _c1Bit = _secondBit;
const int _classC0Shift = 4;
const int _classC1Shift = 7;

/// Port of `MessageType` (message.go:534-537): the STUN Message Type field.
final class MessageType implements Setter {
  MessageType({required this.method, required this.messageClass});

  Method method;
  MessageClass messageClass;

  /// Port of `MessageType.AddTo` (message.go:540-544).
  @override
  void addTo(Message m) => m.setType(this);

  /// Port of `MessageType.Value` (message.go:573-604).
  int value() {
    final msg = method.value;
    final a = msg & _methodABits;
    final b = msg & _methodBBits;
    final d = msg & _methodDBits;
    final combinedMethod = a + (b << _methodBShift) + (d << _methodDShift);

    final c = messageClass.value;
    final c0 = (c & _c0Bit) << _classC0Shift;
    final c1 = (c & _c1Bit) << _classC1Shift;
    final classBits = c0 + c1;

    return combinedMethod + classBits;
  }

  /// Port of `MessageType.ReadValue` (message.go:607-621).
  void readValue(int v) {
    final c0 = (v >> _classC0Shift) & _c0Bit;
    final c1 = (v >> _classC1Shift) & _c1Bit;
    final classValue = c0 + c1;
    messageClass = MessageClass._(classValue);

    final a = v & _methodABits;
    final b = (v >> _methodBShift) & _methodBBits;
    final d = (v >> _methodDShift) & _methodDBits;
    method = Method(a + b + d);
  }

  /// Port of `MessageType.String` (message.go:623-625).
  @override
  String toString() => '$method $messageClass';

  @override
  bool operator ==(Object other) =>
      other is MessageType &&
      other.method == method &&
      other.messageClass == messageClass;

  @override
  int get hashCode => Object.hash(method, messageClass);
}

// Port of `NewType` (message.go:547-552): not ported as a free `newX`
// function (AGENTS.md, "RULE_NO_NEW_X_FUNCTIONS") -- it does exactly what
// [MessageType]'s own unnamed constructor already does, so callers use
// `MessageType(method: ..., messageClass: ...)` directly instead.

/// Port of `BindingRequest` (message.go:462).
final MessageType bindingRequest = MessageType(
  method: Method.binding,
  messageClass: MessageClass.request,
);

/// Port of `BindingSuccess` (message.go:464).
final MessageType bindingSuccess = MessageType(
  method: Method.binding,
  messageClass: MessageClass.successResponse,
);

/// Port of `BindingError` (message.go:466).
final MessageType bindingError = MessageType(
  method: Method.binding,
  messageClass: MessageClass.errorResponse,
);

/// Port of `transactionIDValueSetter` (message.go:638): private in Go, so
/// private here too (AGENTS.md, "Princípio do Menor Privilégio").
final class _TransactionIdValueSetter implements Setter {
  const _TransactionIdValueSetter(this.value);

  final Uint8List value;

  @override
  void addTo(Message m) {
    m.transactionId = value;
    m.writeTransactionId();
  }
}

/// Port of `NewTransactionIDSetter` (message.go:642-644): returns a new
/// [Setter] that sets the message transaction ID to [value]. Not spelled
/// `newTransactionIdSetter` (AGENTS.md, "RULE_NO_NEW_X_FUNCTIONS" flags any
/// free `newX` function; the underlying type it builds,
/// `_TransactionIdValueSetter`, is intentionally private -- matching Go's
/// own unexported `transactionIDValueSetter` -- so there is no public class
/// to hang a named constructor off of instead).
Setter transactionIdSetter(Uint8List value) => _TransactionIdValueSetter(value);
