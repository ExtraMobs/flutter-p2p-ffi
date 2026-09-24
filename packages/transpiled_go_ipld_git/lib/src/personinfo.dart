// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of github.com/ipfs/go-ipld-git/personinfo.go.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

/// PersonInfo matches the IPLD Schema type "PersonInfo" for git author/committer/tagger.
final class PersonInfo {
  const PersonInfo({
    required this.name,
    required this.email,
    required this.date,
    required this.timezone,
  });

  final String name;
  final String email;
  final String date;
  final String timezone;

  /// Returns the formatted git identity string `name <email> date timezone`.
  String gitString() {
    final sb = StringBuffer();
    if (name.isNotEmpty) {
      sb.write('$name ');
    }
    sb.write('<$email>');
    if (date.isNotEmpty) {
      sb.write(' $date');
    }
    if (timezone.isNotEmpty) {
      sb.write(' $timezone');
    }
    return sb.toString();
  }

  /// Converts this PersonInfo to an IPLD Node representation.
  Node toNode() => PlainMap({
        'name': PlainString(name),
        'email': PlainString(email),
        'date': PlainString(date),
        'timezone': PlainString(timezone),
      });

  /// Factory from an IPLD Node.
  factory PersonInfo.fromNode(Node n) {
    String getStr(String key) {
      try {
        final val = n.lookupByString(key);
        return val.isAbsent() ? '' : val.asString();
      } catch (_) {
        return '';
      }
    }

    return PersonInfo(
      name: getStr('name'),
      email: getStr('email'),
      date: getStr('date'),
      timezone: getStr('timezone'),
    );
  }
}

/// Parses a person info line (e.g. `author Name <email> 123456 +0100`).
PersonInfo parsePersonInfo(Uint8List line) {
  final text = utf8.decode(line).trim();
  final parts = text.split(' ');
  if (parts.length < 3) {
    throw FormatException('incorrectly formatted person info line: "$text"');
  }

  // Skip the prefix (e.g. "author", "committer", "tagger")
  var at = 1;
  var name = '';
  while (at < parts.length) {
    final part = parts[at];
    if (part.isNotEmpty) {
      if (part.startsWith('<')) break;
      name += (name.isEmpty ? '' : ' ') + part;
    } else if (name.isNotEmpty) {
      name += ' ';
    }
    at++;
  }

  if (at >= parts.length) {
    throw FormatException('invalid personInfo, missing email: "$text"');
  }

  var email = '';
  while (at < parts.length) {
    var part = parts[at];
    if (part.startsWith('<')) {
      part = part.substring(1);
    }
    at++;
    if (part.endsWith('>')) {
      email += (email.isEmpty ? '' : ' ') + part.substring(0, part.length - 1);
      break;
    }
    email += (email.isEmpty ? '' : ' ') + part;
  }

  var date = '';
  if (at < parts.length) {
    date = parts[at++];
  }

  var timezone = '';
  if (at < parts.length) {
    timezone = parts[at++];
  }

  return PersonInfo(
    name: name,
    email: email,
    date: date,
    timezone: timezone,
  );
}
