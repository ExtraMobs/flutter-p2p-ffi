// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/validator.dart
//
// Port of go-libp2p-record's validator.go: the `Validator` interface DHT
// record validators implement, plus `NamespacedValidator`, which
// dispatches to a sub-validator by the key's namespace (the `$namespace`
// in a `/$namespace/$path` key, see `util.dart`'s `splitKey`).
import 'dart:typed_data';

import 'util.dart';

/// Thrown when a key's namespace has no registered [Validator] in a
/// [NamespacedValidator]. Equivalent to go-libp2p-record's
/// `ErrInvalidRecordType`.
class InvalidRecordTypeException implements Exception {
  /// Creates the exception.
  const InvalidRecordTypeException();
  @override
  String toString() => 'invalid record keytype';
}

/// Thrown by a subsystem when it fails because it found a better record
/// than the one it was given. Equivalent to go-libp2p-record's
/// `ErrBetterRecord`.
class BetterRecordException implements Exception {
  /// Creates the exception carrying the better [key]/[value] pair found.
  const BetterRecordException({required this.key, required this.value});

  /// The key associated with the record.
  final String key;

  /// The best value found, according to the record's validator.
  final Uint8List value;

  @override
  String toString() => 'found better value for "$key"';
}

/// Validates and selects among DHT records. Equivalent to
/// go-libp2p-record's `Validator` interface.
abstract class Validator {
  /// Validates [value] for [key], throwing if it's invalid (e.g. expired,
  /// signed by the wrong key).
  void validate(String key, Uint8List value);

  /// Selects the index of the best record among [values] for [key] (e.g.
  /// the newest). Decisions must be stable.
  int select(String key, List<Uint8List> values);
}

/// A [Validator] that delegates to sub-validators by namespace (the
/// `$namespace` in a `/$namespace/$path` key). Equivalent to
/// go-libp2p-record's `NamespacedValidator`.
class NamespacedValidator implements Validator {
  /// Creates a namespaced validator dispatching to [validators] by key
  /// namespace.
  NamespacedValidator(Map<String, Validator> validators)
    : _validators = Map.of(validators);

  final Map<String, Validator> _validators;

  /// The sub-validator responsible for [key], or `null` if [key]'s
  /// namespace has none registered. Equivalent to go-libp2p-record's
  /// `NamespacedValidator.ValidatorByKey`.
  Validator? validatorByKey(String key) {
    try {
      final (namespace, _) = splitKey(key);
      return _validators[namespace];
    } on InvalidRecordTypeException {
      return null;
    }
  }

  @override
  void validate(String key, Uint8List value) {
    final validator = validatorByKey(key);
    if (validator == null) throw const InvalidRecordTypeException();
    validator.validate(key, value);
  }

  @override
  int select(String key, List<Uint8List> values) {
    if (values.isEmpty) {
      throw ArgumentError("can't select from no values");
    }
    final validator = validatorByKey(key);
    if (validator == null) throw const InvalidRecordTypeException();
    return validator.select(key, values);
  }
}
