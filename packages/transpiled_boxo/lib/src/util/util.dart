// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';
import 'dart:typed_data';

import 'package:transpiled_base58/transpiled_base58.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

/// The default IPFS hash function (multihash SHA2-256 code).
const String defaultIpfsHash = 'sha2-256';

/// Global debug switch used by block validation.
bool debug = false;

/// Indicates that an operation has no implementation.
final Exception errNotImplemented = Exception('error: not implemented yet');

/// Indicates that an operation exceeded its deadline.
final Exception errTimeout = Exception('error: call timed out');

/// Indicates that a search returned an incomplete result.
final Exception errSearchIncomplete = Exception('error: search incomplete');

/// Returns the non-panicking cast error and prints a stack trace.
Exception errCast() {
  stderr.writeln(StackTrace.current);
  return Exception('cast error');
}

/// Converts paths to absolute paths using the current working directory.
List<String> expandPathnames(Iterable<String> paths) =>
    paths.map((path) => File(path).absolute.path).toList();

/// Reads an environment variable as a boolean.
bool getenvBool(String name) {
  final value = Platform.environment[name]?.toLowerCase();
  return value == 'true' || value == 't' || value == '1';
}

/// Splits [subject] at its first [separator].
List<String> partition(String subject, String separator) {
  final i = subject.indexOf(separator);
  return i < 0
      ? [subject, '', '']
      : [
          subject.substring(0, i),
          separator,
          subject.substring(i + separator.length),
        ];
}

/// Splits [subject] at its last [separator].
List<String> rPartition(String subject, String separator) {
  final i = subject.lastIndexOf(separator);
  return i < 0
      ? [subject, '', '']
      : [
          subject.substring(0, i),
          separator,
          subject.substring(i + separator.length),
        ];
}

/// Computes the default SHA2-256 multihash.
DecodedMultihash hash(Uint8List data) => MultihashUtils.sum(defaultIpfsHash, data);

/// Returns whether [value] is a valid base58 multihash.
bool isValidHash(String value) {
  try {
    final bytes = Base58().base58Decode(value);
    if (bytes.isEmpty) return false;
    MultihashUtils.decode(bytes);
    return true;
  } on Object {
    return false;
  }
}

/// XORs [a] with [b], preserving the length of [a].
Uint8List xor(Uint8List a, Uint8List b) {
  if (b.length < a.length) throw RangeError('second operand is too short');
  return Uint8List.fromList(List.generate(a.length, (i) => a[i] ^ b[i]));
}
