// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/record/record.dart
//
// Port of go-libp2p's core/record/record.go: the `Record` interface (a
// payload type that can go inside a signed `Envelope`) plus a registry
// mapping each payload-type codec to the concrete `Record` type that
// should be used to unmarshal it.
//
// Go's registry stores a `reflect.Type` (from a `prototype Record`
// instance) and later `reflect.New`s a blank instance of it. Dart has no
// equivalent of instantiating an arbitrary type from a runtime type
// token, so the registry stores a blank-instance *factory function*
// instead -- callers register `() => MyRecord()` rather than an instance,
// which is called once immediately (to read its `codec()`) and again
// every time that payload type needs to be unmarshaled.
import 'dart:typed_data';

/// A data type that can be used as the payload of an [Envelope]. Equivalent
/// to go-libp2p core/record's `Record` interface.
///
/// Record types may be "registered" as the default for a given Envelope
/// payload type using [registerType]. Once registered, [Envelope.record]
/// creates and unmarshals an instance of that type automatically.
abstract class Record {
  /// The "signature domain" used when signing/verifying this Record type.
  /// Must be the same string for every instance of a given Record type.
  String domain();

  /// A binary identifier for this Record type, ideally a registered
  /// multicodec. Used as the Envelope's payload type.
  Uint8List codec();

  /// Converts this Record instance to bytes, for use as an Envelope
  /// payload.
  Uint8List marshalRecord();

  /// Unmarshals a payload into this Record instance, mutating it in place.
  void unmarshalRecord(Uint8List data);
}

/// Thrown by [unmarshalRecordPayload] when no [Record] type has been
/// [registerType]d for the given payload type. Equivalent to go-libp2p's
/// `ErrPayloadTypeNotRegistered`.
class PayloadTypeNotRegisteredException implements Exception {
  /// Creates the exception.
  const PayloadTypeNotRegisteredException();
  @override
  String toString() => 'payload type is not registered';
}

final Map<String, Record Function()> _payloadTypeRegistry = {};

/// Associates a payload-type codec with a factory that builds a blank
/// instance of a concrete [Record] type, so [Envelope.record] can
/// automatically unmarshal payloads of that type. Equivalent to
/// go-libp2p's `RegisterType` (adapted to Dart's lack of reflection --
/// see this file's top comment).
void registerType(Record Function() factory) {
  final prototype = factory();
  _payloadTypeRegistry[String.fromCharCodes(prototype.codec())] = factory;
}

/// Builds a blank [Record] instance for [payloadType] and unmarshals
/// [payloadBytes] into it. Equivalent to go-libp2p's
/// `unmarshalRecordPayload`.
Record unmarshalRecordPayload(Uint8List payloadType, Uint8List payloadBytes) {
  final rec = _blankRecordForPayloadType(payloadType);
  rec.unmarshalRecord(payloadBytes);
  return rec;
}

Record _blankRecordForPayloadType(Uint8List payloadType) {
  final factory = _payloadTypeRegistry[String.fromCharCodes(payloadType)];
  if (factory == null) {
    throw const PayloadTypeNotRegisteredException();
  }
  return factory();
}
