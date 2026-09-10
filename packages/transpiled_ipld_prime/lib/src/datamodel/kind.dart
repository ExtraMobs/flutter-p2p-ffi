// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/kind.dart
//
// Port of go-ipld-prime's datamodel/kind.go.
/// The primitive kind of an IPLD Data Model value. Equivalent to
/// go-ipld-prime's `Kind` (a `uint8` there, whose values are ASCII codes
/// for a mnemonic character -- kept here as a `code` field for the same
/// reason: it's convenient for diagnostics/debugging).
enum Kind {
  /// No kind (the zero value). Equivalent to go-ipld-prime's `Kind_Invalid`.
  invalid(0),

  /// Equivalent to go-ipld-prime's `Kind_Map`.
  map(0x7B), // '{'
  /// Equivalent to go-ipld-prime's `Kind_List`.
  list(0x5B), // '['
  /// Equivalent to go-ipld-prime's `Kind_Null`.
  null_(0x30), // '0'
  /// Equivalent to go-ipld-prime's `Kind_Bool`.
  bool_(0x62), // 'b'
  /// Equivalent to go-ipld-prime's `Kind_Int`.
  int_(0x69), // 'i'
  /// Equivalent to go-ipld-prime's `Kind_Float`.
  float(0x66), // 'f'
  /// Equivalent to go-ipld-prime's `Kind_String`.
  string(0x73), // 's'
  /// Equivalent to go-ipld-prime's `Kind_Bytes`.
  bytes(0x78), // 'x'
  /// Equivalent to go-ipld-prime's `Kind_Link`.
  link(0x2F); // '/'

  const Kind(this.code);

  /// The ASCII code this kind's mnemonic character maps to.
  final int code;

  @override
  String toString() => switch (this) {
    Kind.invalid => 'INVALID',
    Kind.map => 'map',
    Kind.list => 'list',
    Kind.null_ => 'null',
    Kind.bool_ => 'bool',
    Kind.int_ => 'int',
    Kind.float => 'float',
    Kind.string => 'string',
    Kind.bytes => 'bytes',
    Kind.link => 'link',
  };
}

/// A named set of [Kind] values, mainly used in error messages. Equivalent
/// to go-ipld-prime's `KindSet`.
class KindSet {
  /// Creates a kind set from [kinds].
  const KindSet(this.kinds);

  /// The kinds in this set.
  final List<Kind> kinds;

  /// Equivalent to go-ipld-prime's `KindSet_Recursive`.
  static const recursive = KindSet([Kind.map, Kind.list]);

  /// Equivalent to go-ipld-prime's `KindSet_Scalar`.
  static const scalar = KindSet([
    Kind.null_,
    Kind.bool_,
    Kind.int_,
    Kind.float,
    Kind.string,
    Kind.bytes,
    Kind.link,
  ]);

  /// Equivalent to go-ipld-prime's `KindSet_JustMap`.
  static const justMap = KindSet([Kind.map]);

  /// Equivalent to go-ipld-prime's `KindSet_JustList`.
  static const justList = KindSet([Kind.list]);

  /// Equivalent to go-ipld-prime's `KindSet_JustNull`.
  static const justNull = KindSet([Kind.null_]);

  /// Equivalent to go-ipld-prime's `KindSet_JustBool`.
  static const justBool = KindSet([Kind.bool_]);

  /// Equivalent to go-ipld-prime's `KindSet_JustInt`.
  static const justInt = KindSet([Kind.int_]);

  /// Equivalent to go-ipld-prime's `KindSet_JustFloat`.
  static const justFloat = KindSet([Kind.float]);

  /// Equivalent to go-ipld-prime's `KindSet_JustString`.
  static const justString = KindSet([Kind.string]);

  /// Equivalent to go-ipld-prime's `KindSet_JustBytes`.
  static const justBytes = KindSet([Kind.bytes]);

  /// Equivalent to go-ipld-prime's `KindSet_JustLink`.
  static const justLink = KindSet([Kind.link]);

  /// Whether [kind] is a member of this set.
  bool contains(Kind kind) => kinds.contains(kind);

  @override
  String toString() {
    if (kinds.isEmpty) return '<empty KindSet>';
    return kinds.map((k) => k.toString()).join(' or ');
  }
}
