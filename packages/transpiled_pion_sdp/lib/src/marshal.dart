// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 marshal.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// Upstream builds the marshaled document by appending onto a pre-sized
// `[]byte` (the `marshaller` type, sized via `MarshalSize()` to avoid
// reallocation) and has every field type implement a `marshalInto(b []byte)
// []byte` function for that purpose. A Dart `StringBuffer` already grows
// without a pre-sizing hint, and every value type in this package already
// has a `toString()` that reproduces exactly what `marshalInto` would
// produce, so this port writes straight to a `StringBuffer` via `toString()`
// instead of porting the byte-buffer-with-capacity-hint machinery -- same
// output, no `marshalInto`/`marshaller` type needed.

/// `$type=` and CRLF size. Port of the `lineBaseSize` constant
/// (marshal.go:127).
const int _lineBaseSize = 4;

/// Byte length of [s]'s UTF-8 encoding -- the Dart equivalent of Go's
/// `len(string)`, which counts bytes, not the UTF-16 code units Dart's own
/// `String.length` counts.
int _utf8Length(String s) => utf8.encode(s).length;

/// Port of `lenUint` (marshal.go:219): the number of decimal digits needed
/// to print [i].
int _lenUint(Golang.Uint64 i) {
  if (i == Golang.Uint64()) {
    return 1;
  }
  var count = 0;
  var value = i;
  final ten = Golang.Uint64(10);
  while (value != Golang.Uint64()) {
    value = value ~/ ten;
    count++;
  }
  return count;
}

/// Port of `lenInt` (marshal.go:232).
int _lenInt(int i) {
  if (i < 0) {
    return _lenUint(Golang.Uint64(-i)) + 1;
  }
  return _lenUint(Golang.Uint64(i));
}

/// Marshalling (`Marshal`/`MarshalSize`) for [SessionDescription]. Port of
/// marshal.go:40-208. Added via extension for the same reason as
/// [SessionDescriptionCodecs] in util.dart.
extension SessionDescriptionMarshal on SessionDescription {
  /// Serializes this session description to SDP text. Port of
  /// `SessionDescription.Marshal` (marshal.go:40).
  ///
  /// https://tools.ietf.org/html/rfc4566#section-5
  String marshal() {
    final buffer = StringBuffer();

    void addKeyValue(String key, Object value) {
      buffer
        ..write(key)
        ..write(value)
        ..write('\r\n');
    }

    addKeyValue('v=', version.value);
    addKeyValue('o=', origin);
    addKeyValue('s=', sessionName.value);

    if (sessionInformation != null) {
      addKeyValue('i=', sessionInformation!.value);
    }

    if (uri != null) {
      addKeyValue('u=', uri!);
    }

    if (emailAddress != null) {
      addKeyValue('e=', emailAddress!.value);
    }

    if (phoneNumber != null) {
      addKeyValue('p=', phoneNumber!.value);
    }

    if (connectionInformation != null) {
      addKeyValue('c=', connectionInformation!);
    }

    for (final b in bandwidth) {
      addKeyValue('b=', b);
    }

    for (final td in timeDescriptions) {
      addKeyValue('t=', td.timing);
      for (final r in td.repeatTimes) {
        addKeyValue('r=', r);
      }
    }

    if (timeZones.isNotEmpty) {
      buffer.write('z=');
      for (var i = 0; i < timeZones.length; i++) {
        if (i > 0) {
          buffer.write(' ');
        }
        buffer.write(timeZones[i]);
      }
      buffer.write('\r\n');
    }

    if (encryptionKey != null) {
      addKeyValue('k=', encryptionKey!.value);
    }

    for (final a in attributes) {
      addKeyValue('a=', a);
    }

    for (final md in mediaDescriptions) {
      addKeyValue('m=', md.mediaName);

      if (md.mediaTitle != null) {
        addKeyValue('i=', md.mediaTitle!.value);
      }

      if (md.connectionInformation != null) {
        addKeyValue('c=', md.connectionInformation!);
      }

      for (final b in md.bandwidth) {
        addKeyValue('b=', b);
      }

      if (md.encryptionKey != null) {
        addKeyValue('k=', md.encryptionKey!.value);
      }

      for (final a in md.attributes) {
        addKeyValue('a=', a);
      }
    }

    return buffer.toString();
  }

  /// Returns the size of this session description once marshaled. Port of
  /// `SessionDescription.MarshalSize` (marshal.go:130).
  int marshalSize() {
    var size = _lineBaseSize + version._marshalSize();
    size += _lineBaseSize + origin._marshalSize();
    size += _lineBaseSize + sessionName._marshalSize();

    if (sessionInformation != null) {
      size += _lineBaseSize + sessionInformation!._marshalSize();
    }

    if (uri != null) {
      size += _lineBaseSize + _utf8Length(uri.toString());
    }

    if (emailAddress != null) {
      size += _lineBaseSize + emailAddress!._marshalSize();
    }

    if (phoneNumber != null) {
      size += _lineBaseSize + phoneNumber!._marshalSize();
    }

    if (connectionInformation != null) {
      size += _lineBaseSize + connectionInformation!._marshalSize();
    }

    for (final b in bandwidth) {
      size += _lineBaseSize + b._marshalSize();
    }

    for (final td in timeDescriptions) {
      size += _lineBaseSize + td.timing._marshalSize();
      for (final r in td.repeatTimes) {
        size += _lineBaseSize + r._marshalSize();
      }
    }

    if (timeZones.isNotEmpty) {
      size += _lineBaseSize;
      for (var i = 0; i < timeZones.length; i++) {
        if (i > 0) {
          size++;
        }
        size += timeZones[i]._marshalSize();
      }
    }

    if (encryptionKey != null) {
      size += _lineBaseSize + encryptionKey!._marshalSize();
    }

    for (final a in attributes) {
      size += _lineBaseSize + a._marshalSize();
    }

    for (final md in mediaDescriptions) {
      size += _lineBaseSize + md.mediaName._marshalSize();
      if (md.mediaTitle != null) {
        size += _lineBaseSize + md.mediaTitle!._marshalSize();
      }
      if (md.connectionInformation != null) {
        size += _lineBaseSize + md.connectionInformation!._marshalSize();
      }
      for (final b in md.bandwidth) {
        size += _lineBaseSize + b._marshalSize();
      }
      if (md.encryptionKey != null) {
        size += _lineBaseSize + md.encryptionKey!._marshalSize();
      }
      for (final a in md.attributes) {
        size += _lineBaseSize + a._marshalSize();
      }
    }

    return size;
  }
}
