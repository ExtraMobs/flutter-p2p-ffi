// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../../../dns/dnsmessage.dart';

// Port of golang.org/x/net/dns/dnsmessage/message.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// Go's `GoString()` methods (fmt.GoStringer) produce Go source text meant to
// round-trip through `%#v`/`go generate`-style debug printing. That facility
// has no Dart analogue and no consumer in this port (nothing here ever
// "compiles" the printed string back), so it is deliberately not ported.
// Go's `String()` (fmt.Stringer) IS a portable human-readable representation
// and is kept as `toString()`.
//
// Go's exported sentinel errors used for parser/builder flow control
// (`ErrNotStarted`, `ErrSectionDone`) become typed exceptions
// (`NotStartedException`, `SectionDoneException`) that single-item Parser/
// Builder methods throw and that bulk methods (`allQuestions`, etc.) catch
// internally, mirroring the Go contract exactly. The ~18 unexported leaf
// errors (`errBaseLen`, `errCalcLen`, ...) are never compared by identity
// anywhere in the Go source (only wrapped for their message text via
// `nestedError` and returned), and are not exported, so no Go caller can
// type-switch on them either; they are ported as `FormatException` carrying
// the identical Go message text, chained through nested context with the
// same `"context: message"` joining `nestedError` performs.

/// A Type is the type of a DNS Resource Record.
///
/// Port of `dnsmessage.Type` (message.go:35). Go represents it as a bare
/// `uint16` with package-level `Type<Name>` constants; Dart has no open
/// integer enum, so it is a small value class wrapping the raw code point,
/// with the constants as `Type.<name>` statics (dropping the redundant
/// `Type` prefix already implied by the enclosing class).
final class Type implements Comparable<Type> {
  const Type(this.value);

  final int value;

  static const Type a = Type(1);
  static const Type ns = Type(2);
  static const Type cname = Type(5);
  static const Type soa = Type(6);
  static const Type ptr = Type(12);
  static const Type mx = Type(15);
  static const Type txt = Type(16);
  static const Type aaaa = Type(28);
  static const Type srv = Type(33);
  static const Type opt = Type(41);
  static const Type svcb = Type(64);
  static const Type https = Type(65);

  static const Type wks = Type(11);
  static const Type hinfo = Type(13);
  static const Type minfo = Type(14);
  static const Type axfr = Type(252);
  static const Type all = Type(255);

  static final Map<Type, String> _names = {
    a: 'TypeA',
    ns: 'TypeNS',
    cname: 'TypeCNAME',
    soa: 'TypeSOA',
    ptr: 'TypePTR',
    mx: 'TypeMX',
    txt: 'TypeTXT',
    aaaa: 'TypeAAAA',
    srv: 'TypeSRV',
    opt: 'TypeOPT',
    svcb: 'TypeSVCB',
    https: 'TypeHTTPS',
    wks: 'TypeWKS',
    hinfo: 'TypeHINFO',
    minfo: 'TypeMINFO',
    axfr: 'TypeAXFR',
    all: 'TypeALL',
  };

  @override
  String toString() => _names[this] ?? _printUint16(value);

  @override
  bool operator ==(Object other) => other is Type && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(Type other) => value.compareTo(other.value);
}

/// A Class is a type of network. Port of `dnsmessage.Class` (message.go:97).
final class Class implements Comparable<Class> {
  const Class(this.value);

  final int value;

  static const Class inet = Class(1);
  static const Class csnet = Class(2);
  static const Class chaos = Class(3);
  static const Class hesiod = Class(4);
  static const Class any = Class(255);

  static final Map<Class, String> _names = {
    inet: 'ClassINET',
    csnet: 'ClassCSNET',
    chaos: 'ClassCHAOS',
    hesiod: 'ClassHESIOD',
    any: 'ClassANY',
  };

  @override
  String toString() => _names[this] ?? _printUint16(value);

  @override
  bool operator ==(Object other) => other is Class && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(Class other) => value.compareTo(other.value);
}

/// An OpCode is a DNS operation code. Port of `dnsmessage.OpCode`
/// (message.go:135). Go defines no named constants for it.
final class OpCode implements Comparable<OpCode> {
  const OpCode(this.value);

  final int value;

  @override
  String toString() => _printUint16(value);

  @override
  bool operator ==(Object other) => other is OpCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(OpCode other) => value.compareTo(other.value);
}

/// An RCode is a DNS response status code. Port of `dnsmessage.RCode`
/// (message.go:143).
final class RCode implements Comparable<RCode> {
  const RCode(this.value);

  final int value;

  static const RCode success = RCode(0);
  static const RCode formatError = RCode(1);
  static const RCode serverFailure = RCode(2);
  static const RCode nameError = RCode(3);
  static const RCode notImplemented = RCode(4);
  static const RCode refused = RCode(5);

  static final Map<RCode, String> _names = {
    success: 'RCodeSuccess',
    formatError: 'RCodeFormatError',
    serverFailure: 'RCodeServerFailure',
    nameError: 'RCodeNameError',
    notImplemented: 'RCodeNotImplemented',
    refused: 'RCodeRefused',
  };

  @override
  String toString() => _names[this] ?? _printUint16(value);

  @override
  bool operator ==(Object other) => other is RCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(RCode other) => value.compareTo(other.value);
}

String _printUint16(int i) => (i & 0xFFFF).toString();

/// Port of `dnsmessage.ErrNotStarted` (message.go:266-269): the previous
/// records haven't been appropriately parsed, skipped or finished yet.
final class NotStartedException implements Exception {
  const NotStartedException();

  @override
  String toString() => "parsing/packing of this type isn't available yet";
}

/// Port of `dnsmessage.ErrSectionDone` (message.go:271-273): all records in
/// the section have been parsed or finished.
final class SectionDoneException implements Exception {
  const SectionDoneException();

  @override
  String toString() => 'parsing/packing of this section has completed';
}

const _errBaseLen = 'insufficient data for base length type';
const _errCalcLen = 'insufficient data for calculated length type';
const _errReserved = 'segment prefix is reserved';
const _errTooManyPtr = 'too many pointers (>10)';
const _errInvalidPtr = 'invalid pointer';
const _errInvalidName = 'invalid dns name';
const _errNilResouceBody = 'nil resource body';
const _errResourceLen = 'insufficient data for resource body length';
const _errSegTooLong = 'segment length too long';
const _errNameTooLong = 'name too long';
const _errZeroSegLen = 'zero length segment';
const _errResTooLong = 'resource length too long';
const _errTooManyQuestions = 'too many Questions to pack (>65535)';
const _errTooManyAnswers = 'too many Answers to pack (>65535)';
const _errTooManyAuthorities = 'too many Authorities to pack (>65535)';
const _errTooManyAdditionals = 'too many Additionals to pack (>65535)';
const _errNonCanonicalName =
    'name is not in canonical format (it must end with a .)';
const _errStringTooLong = 'character string exceeds maximum length (255)';
const _errParamOutOfOrder = 'parameter out of order';
const _errTooLongSVCBValue = 'value too long (>65535 bytes)';

/// Port of `nestedError` (message.go:318-329): wraps a lower-level error
/// with a `"context: message"` prefix, matching Go's manual error-wrapping
/// idiom used throughout this package before `fmt.Errorf("%w")` existed.
Never _nest(String context, Object err) {
  final message = err is FormatException ? err.message : err.toString();
  throw FormatException('$context: $message');
}

// `packStartingCap` (message.go:299-304) is a slice-capacity pre-allocation
// hint for Go's `make([]byte, 0, packStartingCap)`. `dart:core`'s `List`
// exposes no equivalent "reserve capacity" API for a growable list (growth
// is managed internally), so there is no faithful Dart target for this
// constant; it is deliberately not ported (no observable behavior depends
// on it).
const _uint16Len = 2;
const _uint32Len = 4;
const _headerLen = 6 * _uint16Len;

/// Header is a representation of a DNS message header.
///
/// Port of `dnsmessage.Header` (message.go:331-343).
final class Header {
  Header({
    this.id = 0,
    this.response = false,
    this.opCode = const OpCode(0),
    this.authoritative = false,
    this.truncated = false,
    this.recursionDesired = false,
    this.recursionAvailable = false,
    this.authenticData = false,
    this.checkingDisabled = false,
    this.rCode = RCode.success,
  });

  int id;
  bool response;
  OpCode opCode;
  bool authoritative;
  bool truncated;
  bool recursionDesired;
  bool recursionAvailable;
  bool authenticData;
  bool checkingDisabled;
  RCode rCode;

  static const _headerBitQR = 1 << 15;
  static const _headerBitAA = 1 << 10;
  static const _headerBitTC = 1 << 9;
  static const _headerBitRD = 1 << 8;
  static const _headerBitRA = 1 << 7;
  static const _headerBitAD = 1 << 5;
  static const _headerBitCD = 1 << 4;

  /// Port of `(*Header).pack` (message.go:345-370).
  (int, int) _pack() {
    final id = this.id;
    var bits = (opCode.value << 11 | rCode.value) & 0xFFFF;
    if (recursionAvailable) bits |= _headerBitRA;
    if (recursionDesired) bits |= _headerBitRD;
    if (truncated) bits |= _headerBitTC;
    if (authoritative) bits |= _headerBitAA;
    if (response) bits |= _headerBitQR;
    if (authenticData) bits |= _headerBitAD;
    if (checkingDisabled) bits |= _headerBitCD;
    return (id, bits & 0xFFFF);
  }
}

/// Message is a representation of a DNS message.
///
/// Port of `dnsmessage.Message` (message.go:387-394).
final class Message {
  Message({
    Header? header,
    List<Question>? questions,
    List<Resource>? answers,
    List<Resource>? authorities,
    List<Resource>? additionals,
  }) : header = header ?? Header(),
       questions = questions ?? <Question>[],
       answers = answers ?? <Resource>[],
       authorities = authorities ?? <Resource>[],
       additionals = additionals ?? <Resource>[];

  Header header;
  List<Question> questions;
  List<Resource> answers;
  List<Resource> authorities;
  List<Resource> additionals;

  /// Unpack parses a full Message. Port of `(*Message).Unpack`
  /// (message.go:1095-1114).
  void unpack(List<int> msg) {
    final p = Parser();
    header = p.start(msg);
    questions = p.allQuestions();
    answers = p.allAnswers();
    authorities = p.allAuthorities();
    additionals = p.allAdditionals();
  }

  /// Pack packs a full Message. Port of `(*Message).Pack`
  /// (message.go:1117-1119).
  Uint8List pack() => appendPack(<int>[]);

  /// AppendPack is like [pack] but appends the full Message to [b] and
  /// returns the extended buffer. Port of `(*Message).AppendPack`
  /// (message.go:1121-1187).
  Uint8List appendPack(List<int> b) {
    if (questions.length > 0xFFFF) {
      throw const FormatException(_errTooManyQuestions);
    }
    if (answers.length > 0xFFFF) {
      throw const FormatException(_errTooManyAnswers);
    }
    if (authorities.length > 0xFFFF) {
      throw const FormatException(_errTooManyAuthorities);
    }
    if (additionals.length > 0xFFFF) {
      throw const FormatException(_errTooManyAdditionals);
    }

    final h = _wireHeader();
    h.questions = questions.length;
    h.answers = answers.length;
    h.authorities = authorities.length;
    h.additionals = additionals.length;

    final compressionOff = b.length;
    final msg = <int>[...b];
    h._pack(msg);

    // RFC 1035 allows (but does not require) compression for packing. RFC
    // 1035 requires unpacking implementations to support compression, so
    // unconditionally enabling it is fine.
    final compression = <String, int>{};

    for (final q in questions) {
      try {
        q._pack(msg, compression, compressionOff);
      } on FormatException catch (e) {
        _nest('packing Question', e);
      }
    }
    for (final a in answers) {
      try {
        a._pack(msg, compression, compressionOff);
      } on FormatException catch (e) {
        _nest('packing Answer', e);
      }
    }
    for (final a in authorities) {
      try {
        a._pack(msg, compression, compressionOff);
      } on FormatException catch (e) {
        _nest('packing Authority', e);
      }
    }
    for (final a in additionals) {
      try {
        a._pack(msg, compression, compressionOff);
      } on FormatException catch (e) {
        _nest('packing Additional', e);
      }
    }

    return Uint8List.fromList(msg);
  }

  _WireHeader _wireHeader() {
    final (id, bits) = header._pack();
    return _WireHeader()
      ..id = id
      ..bits = bits;
  }
}

enum _Section {
  notStarted,
  header,
  questions,
  answers,
  authorities,
  additionals,
  done,
}

const Map<_Section, String> _sectionNames = {
  _Section.header: 'header',
  _Section.questions: 'Question',
  _Section.answers: 'Answer',
  _Section.authorities: 'Authority',
  _Section.additionals: 'Additional',
};

/// header is the wire format for a DNS message header. Port of the
/// unexported `header` struct (message.go:424-432).
final class _WireHeader {
  int id = 0;
  int bits = 0;
  int questions = 0;
  int answers = 0;
  int authorities = 0;
  int additionals = 0;

  int _count(_Section sec) {
    switch (sec) {
      case _Section.questions:
        return questions;
      case _Section.answers:
        return answers;
      case _Section.authorities:
        return authorities;
      case _Section.additionals:
        return additionals;
      default:
        return 0;
    }
  }

  /// Port of `(*header).pack` (message.go:449-456).
  void _pack(List<int> msg) {
    _packUint16(msg, id);
    _packUint16(msg, bits);
    _packUint16(msg, questions);
    _packUint16(msg, answers);
    _packUint16(msg, authorities);
    _packUint16(msg, additionals);
  }

  /// Port of `(*header).unpack` (message.go:458-480).
  int _unpack(List<int> msg, int off) {
    var newOff = off;
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      id = v;
    } on FormatException catch (e) {
      _nest('id', e);
    }
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      bits = v;
    } on FormatException catch (e) {
      _nest('bits', e);
    }
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      questions = v;
    } on FormatException catch (e) {
      _nest('questions', e);
    }
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      answers = v;
    } on FormatException catch (e) {
      _nest('answers', e);
    }
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      authorities = v;
    } on FormatException catch (e) {
      _nest('authorities', e);
    }
    try {
      int v;
      (v, newOff) = _unpackUint16(msg, newOff);
      additionals = v;
    } on FormatException catch (e) {
      _nest('additionals', e);
    }
    return newOff;
  }

  /// Port of `(*header).header` (message.go:482-495).
  Header _header() => Header(
    id: id,
    response: (bits & Header._headerBitQR) != 0,
    opCode: OpCode((bits >> 11) & 0xF),
    authoritative: (bits & Header._headerBitAA) != 0,
    truncated: (bits & Header._headerBitTC) != 0,
    recursionDesired: (bits & Header._headerBitRD) != 0,
    recursionAvailable: (bits & Header._headerBitRA) != 0,
    authenticData: (bits & Header._headerBitAD) != 0,
    checkingDisabled: (bits & Header._headerBitCD) != 0,
    rCode: RCode(bits & 0xF),
  );
}

/// A Resource is a DNS resource record. Port of `dnsmessage.Resource`
/// (message.go:498-501).
final class Resource {
  Resource(this.header, this.body);

  ResourceHeader header;

  /// Go's `Body ResourceBody` is an interface pointer that can be `nil`
  /// (checked explicitly by `pack`, message.go:525-527); kept nullable here
  /// rather than making a null body structurally impossible, to preserve
  /// that same runtime check and its exact error text.
  ResourceBody? body;

  /// Port of `(*Resource).pack` (message.go:524-543).
  void _pack(List<int> msg, Map<String, int> compression, int compressionOff) {
    final b = body;
    if (b == null) throw const FormatException(_errNilResouceBody);
    header.type = b._realType();
    final lenOff = header._pack(msg, compression, compressionOff);
    final preLen = msg.length;
    try {
      b._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('content', e);
    }
    header._fixLen(msg, lenOff, preLen);
  }
}

/// A ResourceBody is a DNS resource record minus the header. Port of the
/// `dnsmessage.ResourceBody` interface (message.go:510-521).
abstract interface class ResourceBody {
  /// pack packs a Resource except for its header.
  void _pack(List<int> msg, Map<String, int> compression, int compressionOff);

  /// realType returns the actual type of the Resource.
  Type _realType();
}

/// A Parser allows incrementally parsing a DNS message.
///
/// Port of `dnsmessage.Parser` (message.go:559-570). Safe to copy (via
/// [copy]) to preserve the parsing state, mirroring that Go value-struct
/// semantics allow `var p2 = p1`.
final class Parser {
  List<int>? _msg;
  final _WireHeader _header = _WireHeader();

  _Section _section = _Section.notStarted;
  int _off = 0;
  int _index = 0;
  bool _resHeaderValid = false;
  int _resHeaderOffset = 0;
  Type _resHeaderType = const Type(0);
  int _resHeaderLength = 0;

  /// Returns an independent copy of the parser's state, mirroring Go's
  /// implicit struct-value copy semantics (`Parser is safe to copy`).
  Parser copy() {
    final p = Parser()
      .._msg = _msg
      .._section = _section
      .._off = _off
      .._index = _index
      .._resHeaderValid = _resHeaderValid
      .._resHeaderOffset = _resHeaderOffset
      .._resHeaderType = _resHeaderType
      .._resHeaderLength = _resHeaderLength;
    p._header
      ..id = _header.id
      ..bits = _header.bits
      ..questions = _header.questions
      ..answers = _header.answers
      ..authorities = _header.authorities
      ..additionals = _header.additionals;
    return p;
  }

  /// Start parses the header and enables the parsing of Questions. Port of
  /// `(*Parser).Start` (message.go:573-584).
  Header start(List<int> msg) {
    _msg = msg;
    try {
      _off = _header._unpack(msg, 0);
    } on FormatException catch (e) {
      _nest('unpacking header', e);
    }
    _section = _Section.questions;
    return _header._header();
  }

  void _checkAdvance(_Section sec) {
    if (_section.index < sec.index) throw const NotStartedException();
    if (_section.index > sec.index) throw const SectionDoneException();
    _resHeaderValid = false;
    if (_index == _header._count(sec)) {
      _index = 0;
      _section = _Section.values[_section.index + 1];
      throw const SectionDoneException();
    }
  }

  Resource _resource(_Section sec) {
    final header = _resourceHeader(sec);
    _resHeaderValid = false;
    final ResourceBody body;
    final int off;
    try {
      (body, off) = _unpackResourceBody(_msg!, _off, header);
    } on FormatException catch (e) {
      _nest('unpacking ${_sectionNames[sec]}', e);
    }
    _off = off;
    _index++;
    return Resource(header, body);
  }

  ResourceHeader _resourceHeader(_Section sec) {
    if (_resHeaderValid) _off = _resHeaderOffset;
    _checkAdvance(sec);
    final hdr = ResourceHeader();
    final off = hdr._unpack(_msg!, _off);
    _resHeaderValid = true;
    _resHeaderOffset = off;
    _resHeaderType = hdr.type;
    _resHeaderLength = hdr.length;
    _off = off;
    return hdr;
  }

  void _skipResource(_Section sec) {
    if (_resHeaderValid && _section == sec) {
      final newOff = _off + _resHeaderLength;
      if (newOff > _msg!.length) throw const FormatException(_errResourceLen);
      _off = newOff;
      _resHeaderValid = false;
      _index++;
      return;
    }
    _checkAdvance(sec);
    try {
      _off = _skipResourceBytes(_msg!, _off);
    } on FormatException catch (e) {
      _nest('skipping: ${_sectionNames[sec]}', e);
    }
    _index++;
  }

  /// Question parses a single Question. Port of `(*Parser).Question`
  /// (message.go:663-683).
  Question question() {
    _checkAdvance(_Section.questions);
    final name = Name();
    var off = 0;
    try {
      off = name._unpack(_msg!, _off);
    } on FormatException catch (e) {
      _nest('unpacking Question.Name', e);
    }
    Type typ;
    try {
      (typ, off) = _unpackType(_msg!, off);
    } on FormatException catch (e) {
      _nest('unpacking Question.Type', e);
    }
    Class cls;
    try {
      (cls, off) = _unpackClass(_msg!, off);
    } on FormatException catch (e) {
      _nest('unpacking Question.Class', e);
    }
    _off = off;
    _index++;
    return Question(name, typ, cls);
  }

  /// AllQuestions parses all Questions. Port of `(*Parser).AllQuestions`
  /// (message.go:686-704).
  List<Question> allQuestions() {
    final qs = <Question>[];
    while (true) {
      try {
        qs.add(question());
      } on SectionDoneException {
        return qs;
      }
    }
  }

  /// SkipQuestion skips a single Question. Port of `(*Parser).SkipQuestion`
  /// (message.go:707-724).
  void skipQuestion() {
    _checkAdvance(_Section.questions);
    var off = 0;
    try {
      off = _skipName(_msg!, _off);
    } on FormatException catch (e) {
      _nest('skipping Question Name', e);
    }
    try {
      off = _skipType(_msg!, off);
    } on FormatException catch (e) {
      _nest('skipping Question Type', e);
    }
    try {
      off = _skipClass(_msg!, off);
    } on FormatException catch (e) {
      _nest('skipping Question Class', e);
    }
    _off = off;
    _index++;
  }

  /// SkipAllQuestions skips all Questions. Port of
  /// `(*Parser).SkipAllQuestions` (message.go:727-735).
  void skipAllQuestions() {
    while (true) {
      try {
        skipQuestion();
      } on SectionDoneException {
        return;
      }
    }
  }

  /// AnswerHeader parses a single Answer ResourceHeader. Port of
  /// `(*Parser).AnswerHeader` (message.go:738-740).
  ResourceHeader answerHeader() => _resourceHeader(_Section.answers);

  /// Answer parses a single Answer Resource. Port of `(*Parser).Answer`
  /// (message.go:743-745).
  Resource answer() => _resource(_Section.answers);

  /// AllAnswers parses all Answer Resources. Port of `(*Parser).AllAnswers`
  /// (message.go:748-769).
  List<Resource> allAnswers() {
    final as = <Resource>[];
    while (true) {
      try {
        as.add(answer());
      } on SectionDoneException {
        return as;
      }
    }
  }

  /// SkipAnswer skips a single Answer Resource. Port of
  /// `(*Parser).SkipAnswer` (message.go:775-777).
  void skipAnswer() => _skipResource(_Section.answers);

  /// SkipAllAnswers skips all Answer Resources. Port of
  /// `(*Parser).SkipAllAnswers` (message.go:780-788).
  void skipAllAnswers() {
    while (true) {
      try {
        skipAnswer();
      } on SectionDoneException {
        return;
      }
    }
  }

  /// AuthorityHeader parses a single Authority ResourceHeader. Port of
  /// `(*Parser).AuthorityHeader` (message.go:791-793).
  ResourceHeader authorityHeader() => _resourceHeader(_Section.authorities);

  /// Authority parses a single Authority Resource. Port of
  /// `(*Parser).Authority` (message.go:796-798).
  Resource authority() => _resource(_Section.authorities);

  /// AllAuthorities parses all Authority Resources. Port of
  /// `(*Parser).AllAuthorities` (message.go:801-822).
  List<Resource> allAuthorities() {
    final as = <Resource>[];
    while (true) {
      try {
        as.add(authority());
      } on SectionDoneException {
        return as;
      }
    }
  }

  /// SkipAuthority skips a single Authority Resource. Port of
  /// `(*Parser).SkipAuthority` (message.go:828-830).
  void skipAuthority() => _skipResource(_Section.authorities);

  /// SkipAllAuthorities skips all Authority Resources. Port of
  /// `(*Parser).SkipAllAuthorities` (message.go:833-841).
  void skipAllAuthorities() {
    while (true) {
      try {
        skipAuthority();
      } on SectionDoneException {
        return;
      }
    }
  }

  /// AdditionalHeader parses a single Additional ResourceHeader. Port of
  /// `(*Parser).AdditionalHeader` (message.go:844-846).
  ResourceHeader additionalHeader() => _resourceHeader(_Section.additionals);

  /// Additional parses a single Additional Resource. Port of
  /// `(*Parser).Additional` (message.go:849-851).
  Resource additional() => _resource(_Section.additionals);

  /// AllAdditionals parses all Additional Resources. Port of
  /// `(*Parser).AllAdditionals` (message.go:854-875).
  List<Resource> allAdditionals() {
    final as = <Resource>[];
    while (true) {
      try {
        as.add(additional());
      } on SectionDoneException {
        return as;
      }
    }
  }

  /// SkipAdditional skips a single Additional Resource. Port of
  /// `(*Parser).SkipAdditional` (message.go:881-883).
  void skipAdditional() => _skipResource(_Section.additionals);

  /// SkipAllAdditionals skips all Additional Resources. Port of
  /// `(*Parser).SkipAllAdditionals` (message.go:886-894).
  void skipAllAdditionals() {
    while (true) {
      try {
        skipAdditional();
      } on SectionDoneException {
        return;
      }
    }
  }

  void _requireHeader(Type want) {
    if (!_resHeaderValid || _resHeaderType != want) {
      throw const NotStartedException();
    }
  }

  void _advancePastResource() {
    _off += _resHeaderLength;
    _resHeaderValid = false;
    _index++;
  }

  /// CNAMEResource parses a single CNAMEResource. Port of
  /// `(*Parser).CNAMEResource` (message.go:900-912).
  CNAMEResource cnameResource() {
    _requireHeader(Type.cname);
    final r = _unpackCNAMEResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// MXResource parses a single MXResource. Port of
  /// `(*Parser).MXResource` (message.go:918-930).
  MXResource mxResource() {
    _requireHeader(Type.mx);
    final r = _unpackMXResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// NSResource parses a single NSResource. Port of
  /// `(*Parser).NSResource` (message.go:936-948).
  NSResource nsResource() {
    _requireHeader(Type.ns);
    final r = _unpackNSResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// PTRResource parses a single PTRResource. Port of
  /// `(*Parser).PTRResource` (message.go:954-966).
  PTRResource ptrResource() {
    _requireHeader(Type.ptr);
    final r = _unpackPTRResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// SOAResource parses a single SOAResource. Port of
  /// `(*Parser).SOAResource` (message.go:972-984).
  SOAResource soaResource() {
    _requireHeader(Type.soa);
    final r = _unpackSOAResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// TXTResource parses a single TXTResource. Port of
  /// `(*Parser).TXTResource` (message.go:990-1002).
  TXTResource txtResource() {
    _requireHeader(Type.txt);
    final r = _unpackTXTResource(_msg!, _off, _resHeaderLength);
    _advancePastResource();
    return r;
  }

  /// SRVResource parses a single SRVResource. Port of
  /// `(*Parser).SRVResource` (message.go:1008-1020).
  SRVResource srvResource() {
    _requireHeader(Type.srv);
    final r = _unpackSRVResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// AResource parses a single AResource. Port of
  /// `(*Parser).AResource` (message.go:1026-1038).
  AResource aResource() {
    _requireHeader(Type.a);
    final r = _unpackAResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// AAAAResource parses a single AAAAResource. Port of
  /// `(*Parser).AAAAResource` (message.go:1044-1056).
  AAAAResource aaaaResource() {
    _requireHeader(Type.aaaa);
    final r = _unpackAAAAResource(_msg!, _off);
    _advancePastResource();
    return r;
  }

  /// OPTResource parses a single OPTResource. Port of
  /// `(*Parser).OPTResource` (message.go:1062-1074).
  OPTResource optResource() {
    _requireHeader(Type.opt);
    final r = _unpackOPTResource(_msg!, _off, _resHeaderLength);
    _advancePastResource();
    return r;
  }

  /// UnknownResource parses a single UnknownResource. Port of
  /// `(*Parser).UnknownResource` (message.go:1080-1092).
  UnknownResource unknownResource() {
    if (!_resHeaderValid) throw const NotStartedException();
    final r = _unpackUnknownResource(
      _resHeaderType,
      _msg!,
      _off,
      _resHeaderLength,
    );
    _advancePastResource();
    return r;
  }

  /// genericSVCBResource parses a single Resource Record compatible with
  /// SVCB. Port of `(*Parser).genericSVCBResource` (svcb.go:262-274).
  SVCBResource _genericSVCBResource(Type svcbType) {
    _requireHeader(svcbType);
    final r = _unpackSVCBResource(_msg!, _off, _resHeaderLength);
    _advancePastResource();
    return r;
  }

  /// SVCBResource parses a single SVCBResource. Port of
  /// `(*Parser).SVCBResource` (svcb.go:280-282).
  SVCBResource svcbResource() => _genericSVCBResource(Type.svcb);

  /// HTTPSResource parses a single HTTPSResource. Port of
  /// `(*Parser).HTTPSResource` (svcb.go:288-294).
  HTTPSResource httpsResource() =>
      HTTPSResource(_genericSVCBResource(Type.https));
}

/// A Builder allows incrementally packing a DNS message.
///
/// Port of `dnsmessage.Builder` (message.go:1234-1251).
final class Builder {
  Builder(List<int>? buf, Header h) : _msg = <int>[...?buf] {
    _start = _msg.length;
    final (id, bits) = h._pack();
    _header.id = id;
    _header.bits = bits;
    _msg.addAll(List<int>.filled(_headerLen, 0));
    _section = _Section.header;
  }

  final List<int> _msg;
  _Section _section = _Section.notStarted;
  final _WireHeader _header = _WireHeader();
  late final int _start;
  Map<String, int>? _compression;

  /// EnableCompression enables compression in the Builder. Port of
  /// `(*Builder).EnableCompression` (message.go:1286-1288).
  void enableCompression() {
    _compression = <String, int>{};
  }

  void _startCheck(_Section s) {
    if (_section.index <= _Section.notStarted.index) {
      throw const NotStartedException();
    }
    if (_section.index > s.index) throw const SectionDoneException();
  }

  /// StartQuestions prepares the builder for packing Questions. Port of
  /// `(*Builder).StartQuestions` (message.go:1301-1307).
  void startQuestions() {
    _startCheck(_Section.questions);
    _section = _Section.questions;
  }

  /// StartAnswers prepares the builder for packing Answers. Port of
  /// `(*Builder).StartAnswers` (message.go:1310-1316).
  void startAnswers() {
    _startCheck(_Section.answers);
    _section = _Section.answers;
  }

  /// StartAuthorities prepares the builder for packing Authorities. Port of
  /// `(*Builder).StartAuthorities` (message.go:1319-1325).
  void startAuthorities() {
    _startCheck(_Section.authorities);
    _section = _Section.authorities;
  }

  /// StartAdditionals prepares the builder for packing Additionals. Port of
  /// `(*Builder).StartAdditionals` (message.go:1328-1334).
  void startAdditionals() {
    _startCheck(_Section.additionals);
    _section = _Section.additionals;
  }

  void _incrementSectionCount() {
    switch (_section) {
      case _Section.questions:
        if (_header.questions == 0xFFFF) {
          throw const FormatException(_errTooManyQuestions);
        }
        _header.questions++;
      case _Section.answers:
        if (_header.answers == 0xFFFF) {
          throw const FormatException(_errTooManyAnswers);
        }
        _header.answers++;
      case _Section.authorities:
        if (_header.authorities == 0xFFFF) {
          throw const FormatException(_errTooManyAuthorities);
        }
        _header.authorities++;
      case _Section.additionals:
        if (_header.additionals == 0xFFFF) {
          throw const FormatException(_errTooManyAdditionals);
        }
        _header.additionals++;
      default:
    }
  }

  /// Question adds a single Question. Port of `(*Builder).Question`
  /// (message.go:1361-1377).
  void question(Question q) {
    if (_section.index < _Section.questions.index) {
      throw const NotStartedException();
    }
    if (_section.index > _Section.questions.index) {
      throw const SectionDoneException();
    }
    q._pack(_msg, _compression, _start);
    _incrementSectionCount();
  }

  void _checkResourceSection() {
    if (_section.index < _Section.answers.index) {
      throw const NotStartedException();
    }
    if (_section.index > _Section.additionals.index) {
      throw const SectionDoneException();
    }
  }

  // Go sets `h.Type = r.realType()` individually in every concrete
  // `Builder.XResource` method (message.go:1390 etc.), but NOT inside the
  // shared `genericSVCBResource` (svcb.go:297-317) -- that one trusts the
  // caller (`SVCBResource`/`HTTPSResource`, svcb.go:320-329) to have set
  // `h.Type` already, because both share the same `SVCBResource` body type
  // but need different header types (TypeSVCB vs TypeHTTPS). This shared
  // helper mirrors that: it never derives `h.type` from `r` itself: every
  // caller must set `h.type` before calling it.
  void _addResource(
    ResourceHeader h,
    ResourceBody r,
    String label,
    void Function(List<int> msg, Map<String, int>? compression, int start) pack,
  ) {
    _checkResourceSection();
    final lenOff = h._pack(_msg, _compression, _start);
    final preLen = _msg.length;
    try {
      pack(_msg, _compression, _start);
    } on FormatException catch (e) {
      _nest('$label body', e);
    }
    h._fixLen(_msg, lenOff, preLen);
    _incrementSectionCount();
  }

  /// CNAMEResource adds a single CNAMEResource. Port of
  /// `(*Builder).CNAMEResource` (message.go:1390-1411).
  void cnameResource(ResourceHeader h, CNAMEResource r) {
    h.type = r._realType();
    _addResource(h, r, 'CNAMEResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// MXResource adds a single MXResource. Port of `(*Builder).MXResource`
  /// (message.go:1414-1435).
  void mxResource(ResourceHeader h, MXResource r) {
    h.type = r._realType();
    _addResource(h, r, 'MXResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// NSResource adds a single NSResource. Port of `(*Builder).NSResource`
  /// (message.go:1438-1459).
  void nsResource(ResourceHeader h, NSResource r) {
    h.type = r._realType();
    _addResource(h, r, 'NSResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// PTRResource adds a single PTRResource. Port of `(*Builder).PTRResource`
  /// (message.go:1462-1483).
  void ptrResource(ResourceHeader h, PTRResource r) {
    h.type = r._realType();
    _addResource(h, r, 'PTRResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// SOAResource adds a single SOAResource. Port of `(*Builder).SOAResource`
  /// (message.go:1486-1507).
  void soaResource(ResourceHeader h, SOAResource r) {
    h.type = r._realType();
    _addResource(h, r, 'SOAResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// TXTResource adds a single TXTResource. Port of `(*Builder).TXTResource`
  /// (message.go:1510-1531).
  void txtResource(ResourceHeader h, TXTResource r) {
    h.type = r._realType();
    _addResource(h, r, 'TXTResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// SRVResource adds a single SRVResource. Port of `(*Builder).SRVResource`
  /// (message.go:1534-1555).
  void srvResource(ResourceHeader h, SRVResource r) {
    h.type = r._realType();
    _addResource(h, r, 'SRVResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// AResource adds a single AResource. Port of `(*Builder).AResource`
  /// (message.go:1558-1579).
  void aResource(ResourceHeader h, AResource r) {
    h.type = r._realType();
    _addResource(h, r, 'AResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// AAAAResource adds a single AAAAResource. Port of
  /// `(*Builder).AAAAResource` (message.go:1582-1603).
  void aaaaResource(ResourceHeader h, AAAAResource r) {
    h.type = r._realType();
    _addResource(h, r, 'AAAAResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// OPTResource adds a single OPTResource. Port of `(*Builder).OPTResource`
  /// (message.go:1606-1627).
  void optResource(ResourceHeader h, OPTResource r) {
    h.type = r._realType();
    _addResource(h, r, 'OPTResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// UnknownResource adds a single UnknownResource. Port of
  /// `(*Builder).UnknownResource` (message.go:1630-1651).
  void unknownResource(ResourceHeader h, UnknownResource r) {
    h.type = r._realType();
    _addResource(h, r, 'UnknownResource', (msg, c, s) => r._pack(msg, c, s));
  }

  /// genericSVCBResource is the generic implementation for adding SVCB-like
  /// resources. Port of `(*Builder).genericSVCBResource` (svcb.go:297-317).
  void _genericSVCBResource(ResourceHeader h, SVCBResource r) =>
      _addResource(h, r, 'ResourceBody', (msg, c, s) => r._pack(msg, c, s));

  /// SVCBResource adds a single SVCBResource. Port of
  /// `(*Builder).SVCBResource` (svcb.go:320-323).
  void svcbResource(ResourceHeader h, SVCBResource r) {
    h.type = r._realType();
    _genericSVCBResource(h, r);
  }

  /// HTTPSResource adds a single HTTPSResource. Port of
  /// `(*Builder).HTTPSResource` (svcb.go:326-329).
  void httpsResource(ResourceHeader h, HTTPSResource r) {
    h.type = r._realType();
    _genericSVCBResource(h, r.svcbResource);
  }

  /// Finish ends message building and generates a binary message. Port of
  /// `(*Builder).Finish` (message.go:1654-1662).
  Uint8List finish() {
    if (_section.index < _Section.header.index) {
      throw const NotStartedException();
    }
    _section = _Section.done;
    final headerBytes = <int>[];
    _header._pack(headerBytes);
    for (var i = 0; i < headerBytes.length; i++) {
      _msg[_start + i] = headerBytes[i];
    }
    return Uint8List.fromList(_msg);
  }
}

/// A ResourceHeader is the header of a DNS resource record.
///
/// Port of `dnsmessage.ResourceHeader` (message.go:1666-1688).
final class ResourceHeader {
  ResourceHeader({
    Name? name,
    this.type = const Type(0),
    this.klass = const Class(0),
    this.ttl = 0,
    this.length = 0,
  }) : name = name ?? Name();

  Name name;
  Type type;
  Class klass;
  int ttl;
  int length;

  /// Port of `(*ResourceHeader).pack` (message.go:1703-1714). Returns the
  /// offset where the Length field was packed (`lenOff`).
  int _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    try {
      name._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('Name', e);
    }
    _packType(msg, type);
    _packClass(msg, klass);
    _packUint32(msg, ttl);
    final lenOff = msg.length;
    _packUint16(msg, length);
    return lenOff;
  }

  int _unpack(List<int> msg, int off) {
    var newOff = off;
    try {
      newOff = name._unpack(msg, newOff);
    } on FormatException catch (e) {
      _nest('Name', e);
    }
    try {
      final (t, o) = _unpackType(msg, newOff);
      type = t;
      newOff = o;
    } on FormatException catch (e) {
      _nest('Type', e);
    }
    try {
      final (c, o) = _unpackClass(msg, newOff);
      klass = c;
      newOff = o;
    } on FormatException catch (e) {
      _nest('Class', e);
    }
    try {
      final (t, o) = _unpackUint32(msg, newOff);
      ttl = t;
      newOff = o;
    } on FormatException catch (e) {
      _nest('TTL', e);
    }
    try {
      final (l, o) = _unpackUint16(msg, newOff);
      length = l;
      newOff = o;
    } on FormatException catch (e) {
      _nest('Length', e);
    }
    return newOff;
  }

  /// fixLen updates a packed ResourceHeader to include the length of the
  /// ResourceBody. Port of `(*ResourceHeader).fixLen` (message.go:1743-1754).
  void _fixLen(List<int> msg, int lenOff, int preLen) {
    final conLen = msg.length - preLen;
    if (conLen > 0xFFFF) throw const FormatException(_errResTooLong);
    msg[lenOff] = (conLen >> 8) & 0xFF;
    msg[lenOff + 1] = conLen & 0xFF;
    length = conLen;
  }

  static const _edns0Version = 0;
  static const _edns0DNSSECOK = 0x00008000;
  static const _ednsVersionMask = 0x00ff0000;
  static const _edns0DNSSECOKMask = 0x00ff8000;

  /// SetEDNS0 configures h for EDNS(0). Port of
  /// `(*ResourceHeader).SetEDNS0` (message.go:1768-1777).
  void setEDNS0(int udpPayloadLen, RCode extRCode, bool dnssecOK) {
    name = Name()
      ..data[0] = '.'.codeUnitAt(0)
      ..length = 1; // RFC 6891 section 6.1.2
    type = Type.opt;
    klass = Class(udpPayloadLen);
    ttl = Golang.Uint32(extRCode.value >> 4 << 24).toBigInt().toInt();
    if (dnssecOK) ttl |= _edns0DNSSECOK;
  }

  /// DNSSECAllowed reports whether the DNSSEC OK bit is set. Port of
  /// `(*ResourceHeader).DNSSECAllowed` (message.go:1780-1782).
  bool dnssecAllowed() => ttl & _edns0DNSSECOKMask == _edns0DNSSECOK;

  /// ExtendedRCode returns an extended RCode. Port of
  /// `(*ResourceHeader).ExtendedRCode` (message.go:1787-1792).
  RCode extendedRCode(RCode rcode) {
    if (ttl & _ednsVersionMask == _edns0Version) {
      return RCode((((ttl >> 24) << 4) | rcode.value) & 0xFFFF);
    }
    return rcode;
  }
}

/// Port of `skipResource` (message.go:1794-1816).
int _skipResourceBytes(List<int> msg, int off) {
  int newOff;
  try {
    newOff = _skipName(msg, off);
  } on FormatException catch (e) {
    _nest('Name', e);
  }
  try {
    newOff = _skipType(msg, newOff);
  } on FormatException catch (e) {
    _nest('Type', e);
  }
  try {
    newOff = _skipClass(msg, newOff);
  } on FormatException catch (e) {
    _nest('Class', e);
  }
  try {
    newOff = _skipUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('TTL', e);
  }
  final int length;
  try {
    (length, newOff) = _unpackUint16(msg, newOff);
  } on FormatException catch (e) {
    _nest('Length', e);
  }
  newOff += length;
  if (newOff > msg.length) throw const FormatException(_errResourceLen);
  return newOff;
}

// --- wire primitives (message.go:1818-1927) ---

void _packUint16(List<int> msg, int field) {
  msg.add((field >> 8) & 0xFF);
  msg.add(field & 0xFF);
}

(int, int) _unpackUint16(List<int> msg, int off) {
  if (off + _uint16Len > msg.length) throw const FormatException(_errBaseLen);
  return (msg[off] << 8 | msg[off + 1], off + _uint16Len);
}

int _skipUint16(List<int> msg, int off) {
  if (off + _uint16Len > msg.length) throw const FormatException(_errBaseLen);
  return off + _uint16Len;
}

void _packType(List<int> msg, Type field) => _packUint16(msg, field.value);

(Type, int) _unpackType(List<int> msg, int off) {
  final (t, o) = _unpackUint16(msg, off);
  return (Type(t), o);
}

int _skipType(List<int> msg, int off) => _skipUint16(msg, off);

void _packClass(List<int> msg, Class field) => _packUint16(msg, field.value);

(Class, int) _unpackClass(List<int> msg, int off) {
  final (c, o) = _unpackUint16(msg, off);
  return (Class(c), o);
}

int _skipClass(List<int> msg, int off) => _skipUint16(msg, off);

void _packUint32(List<int> msg, int field) {
  msg.add((field >> 24) & 0xFF);
  msg.add((field >> 16) & 0xFF);
  msg.add((field >> 8) & 0xFF);
  msg.add(field & 0xFF);
}

(int, int) _unpackUint32(List<int> msg, int off) {
  if (off + _uint32Len > msg.length) throw const FormatException(_errBaseLen);
  final v =
      (msg[off] << 24) |
      (msg[off + 1] << 16) |
      (msg[off + 2] << 8) |
      msg[off + 3];
  return (Golang.Uint32(v).toBigInt().toInt(), off + _uint32Len);
}

int _skipUint32(List<int> msg, int off) {
  if (off + _uint32Len > msg.length) throw const FormatException(_errBaseLen);
  return off + _uint32Len;
}

void _packText(List<int> msg, List<int> field) {
  final l = field.length;
  if (l > 255) throw const FormatException(_errStringTooLong);
  msg.add(l);
  msg.addAll(field);
}

(List<int>, int) _unpackText(List<int> msg, int off) {
  if (off >= msg.length) throw const FormatException(_errBaseLen);
  final beginOff = off + 1;
  final endOff = beginOff + msg[off];
  if (endOff > msg.length) throw const FormatException(_errCalcLen);
  return (msg.sublist(beginOff, endOff), endOff);
}

void _packBytes(List<int> msg, List<int> field) => msg.addAll(field);

int _unpackBytes(List<int> msg, int off, Uint8List field) {
  final newOff = off + field.length;
  if (newOff > msg.length) throw const FormatException(_errBaseLen);
  for (var i = 0; i < field.length; i++) {
    field[i] = msg[off + i];
  }
  return newOff;
}

const _nonEncodedNameMax = 254;

/// A Name is a non-encoded and non-escaped domain name.
///
/// Port of `dnsmessage.Name` (message.go:1933-1936). Go exports both
/// `Data` ([255]byte) and `Length` (uint8) as plain mutable struct fields
/// (see `SetEDNS0`'s struct literal), so this port keeps them as public
/// mutable fields rather than encapsulating them.
final class Name {
  Name() : data = Uint8List(255), length = 0;

  Uint8List data;
  int length;

  /// NewName creates a new Name from a string. Port of `dnsmessage.NewName`
  /// (message.go:1939-1946). Go's `(Name, error)` becomes a factory that
  /// throws [FormatException].
  factory Name.parse(String name) {
    final bytes = Uint8List.fromList(name.codeUnits);
    if (bytes.length > 255) throw const FormatException(_errCalcLen);
    final n = Name();
    n.data.setRange(0, bytes.length, bytes);
    n.length = bytes.length;
    return n;
  }

  /// MustNewName creates a new Name from a string and throws on error. Port
  /// of `dnsmessage.MustNewName` (message.go:1949-1955).
  factory Name.mustParse(String name) {
    try {
      return Name.parse(name);
    } on FormatException catch (e) {
      throw StateError('creating name: ${e.message}');
    }
  }

  @override
  String toString() => String.fromCharCodes(data.sublist(0, length));

  /// Port of `(*Name).pack` (message.go:1976-2045).
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    if (length > _nonEncodedNameMax) {
      throw const FormatException(_errNameTooLong);
    }

    if (length == 0 || data[length - 1] != 0x2e /* . */ ) {
      throw const FormatException(_errNonCanonicalName);
    }

    if (data[0] == 0x2e && length == 1) {
      msg.add(0);
      return;
    }

    String? nameAsStr;
    var begin = 0;
    for (var i = 0; i < length; i++) {
      if (data[i] == 0x2e) {
        if (i - begin >= 1 << 6) {
          throw const FormatException(_errSegTooLong);
        }
        if (i - begin == 0) {
          throw const FormatException(_errZeroSegLen);
        }
        msg.add(i - begin);
        for (var j = begin; j < i; j++) {
          msg.add(data[j]);
        }
        begin = i + 1;
        continue;
      }

      if ((i == 0 || data[i - 1] == 0x2e) && compression != null) {
        final suffix = String.fromCharCodes(data.sublist(i, length));
        final ptr = compression[suffix];
        if (ptr != null) {
          msg.add((ptr >> 8) | 0xC0);
          msg.add(ptr & 0xFF);
          return;
        }
        final newPtr = msg.length - compressionOff;
        if (newPtr <= (0xFFFF >> 2)) {
          nameAsStr ??= String.fromCharCodes(data.sublist(0, length));
          compression[nameAsStr.substring(i)] = newPtr;
        }
      }
    }
    msg.add(0);
  }

  /// Port of `(*Name).unpack` (message.go:2048-2123).
  int _unpack(List<int> msg, int off) {
    var currOff = off;
    var newOff = off;
    var ptr = 0;
    final name = <int>[];

    while (true) {
      if (currOff >= msg.length) throw const FormatException(_errBaseLen);
      final c = msg[currOff];
      currOff++;
      final top = c & 0xC0;
      if (top == 0x00) {
        if (c == 0x00) break;
        final endOff = currOff + c;
        if (endOff > msg.length) throw const FormatException(_errCalcLen);
        for (var i = currOff; i < endOff; i++) {
          if (msg[i] == 0x2e) throw const FormatException(_errInvalidName);
        }
        if (name.length + (endOff - currOff) >= _nonEncodedNameMax) {
          throw const FormatException(_errNameTooLong);
        }
        name.addAll(msg.sublist(currOff, endOff));
        name.add(0x2e);
        currOff = endOff;
      } else if (top == 0xC0) {
        if (currOff >= msg.length) throw const FormatException(_errInvalidPtr);
        final c1 = msg[currOff];
        currOff++;
        if (ptr == 0) newOff = currOff;
        ptr++;
        if (ptr > 10) throw const FormatException(_errTooManyPtr);
        currOff = (c ^ 0xC0) << 8 | c1;
      } else {
        throw const FormatException(_errReserved);
      }
    }
    if (name.isEmpty) name.add(0x2e);
    data = Uint8List(255)..setRange(0, name.length, name);
    length = name.length;
    if (ptr == 0) newOff = currOff;
    return newOff;
  }
}

/// Port of `skipName` (message.go:2125-2164).
int _skipName(List<int> msg, int off) {
  var newOff = off;
  while (true) {
    if (newOff >= msg.length) throw const FormatException(_errBaseLen);
    final c = msg[newOff];
    newOff++;
    final top = c & 0xC0;
    if (top == 0x00) {
      if (c == 0x00) break;
      newOff += c;
      if (newOff > msg.length) throw const FormatException(_errCalcLen);
    } else if (top == 0xC0) {
      newOff++;
      break;
    } else {
      throw const FormatException(_errReserved);
    }
  }
  return newOff;
}

/// A Question is a DNS query. Port of `dnsmessage.Question`
/// (message.go:2167-2171).
final class Question {
  Question(this.name, this.type, this.klass);

  Name name;
  Type type;
  Class klass;

  /// Port of `(*Question).pack` (message.go:2174-2181).
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    try {
      name._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('Name', e);
    }
    _packType(msg, type);
    _packClass(msg, klass);
  }
}

/// Port of `unpackResourceBody` (message.go:2191-2268). Go assigns `name`
/// unconditionally right after each unpack call regardless of whether that
/// call errored (the `err != nil` check happens only after the whole
/// switch), so the label is available for the wrapped error message even on
/// failure. This port sets `name` before attempting the unpack in each
/// branch to preserve that ordering under Dart's throw-based control flow.
(ResourceBody, int) _unpackResourceBody(
  List<int> msg,
  int off,
  ResourceHeader hdr,
) {
  ResourceBody r;
  String name;
  if (hdr.type == Type.a) {
    name = 'A';
  } else if (hdr.type == Type.ns) {
    name = 'NS';
  } else if (hdr.type == Type.cname) {
    name = 'CNAME';
  } else if (hdr.type == Type.soa) {
    name = 'SOA';
  } else if (hdr.type == Type.ptr) {
    name = 'PTR';
  } else if (hdr.type == Type.mx) {
    name = 'MX';
  } else if (hdr.type == Type.txt) {
    name = 'TXT';
  } else if (hdr.type == Type.aaaa) {
    name = 'AAAA';
  } else if (hdr.type == Type.srv) {
    name = 'SRV';
  } else if (hdr.type == Type.svcb) {
    name = 'SVCB';
  } else if (hdr.type == Type.https) {
    name = 'HTTPS';
  } else if (hdr.type == Type.opt) {
    name = 'OPT';
  } else {
    name = 'Unknown';
  }
  try {
    if (hdr.type == Type.a) {
      r = _unpackAResource(msg, off);
    } else if (hdr.type == Type.ns) {
      r = _unpackNSResource(msg, off);
    } else if (hdr.type == Type.cname) {
      r = _unpackCNAMEResource(msg, off);
    } else if (hdr.type == Type.soa) {
      r = _unpackSOAResource(msg, off);
    } else if (hdr.type == Type.ptr) {
      r = _unpackPTRResource(msg, off);
    } else if (hdr.type == Type.mx) {
      r = _unpackMXResource(msg, off);
    } else if (hdr.type == Type.txt) {
      r = _unpackTXTResource(msg, off, hdr.length);
    } else if (hdr.type == Type.aaaa) {
      r = _unpackAAAAResource(msg, off);
    } else if (hdr.type == Type.srv) {
      r = _unpackSRVResource(msg, off);
    } else if (hdr.type == Type.svcb) {
      r = _unpackSVCBResource(msg, off, hdr.length);
    } else if (hdr.type == Type.https) {
      r = HTTPSResource(_unpackSVCBResource(msg, off, hdr.length));
    } else if (hdr.type == Type.opt) {
      r = _unpackOPTResource(msg, off, hdr.length);
    } else {
      r = _unpackUnknownResource(hdr.type, msg, off, hdr.length);
    }
  } on FormatException catch (e) {
    _nest('$name record', e);
  }
  return (r, off + hdr.length);
}

/// A CNAMEResource is a CNAME Resource record. Port of
/// `dnsmessage.CNAMEResource` (message.go:2270-2273).
final class CNAMEResource implements ResourceBody {
  CNAMEResource(this.cname);

  Name cname;

  @override
  Type _realType() => Type.cname;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => cname._pack(msg, compression, compressionOff);
}

CNAMEResource _unpackCNAMEResource(List<int> msg, int off) {
  final cname = Name();
  cname._unpack(msg, off);
  return CNAMEResource(cname);
}

/// An MXResource is an MX Resource record. Port of `dnsmessage.MXResource`
/// (message.go:2297-2301).
final class MXResource implements ResourceBody {
  MXResource(this.pref, this.mx);

  int pref;
  Name mx;

  @override
  Type _realType() => Type.mx;

  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    _packUint16(msg, pref);
    try {
      mx._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('MXResource.MX', e);
    }
  }
}

MXResource _unpackMXResource(List<int> msg, int off) {
  final int pref;
  int newOff;
  try {
    (pref, newOff) = _unpackUint16(msg, off);
  } on FormatException catch (e) {
    _nest('Pref', e);
  }
  final mx = Name();
  try {
    mx._unpack(msg, newOff);
  } on FormatException catch (e) {
    _nest('MX', e);
  }
  return MXResource(pref, mx);
}

/// An NSResource is an NS Resource record. Port of `dnsmessage.NSResource`
/// (message.go:2337-2340).
final class NSResource implements ResourceBody {
  NSResource(this.ns);

  Name ns;

  @override
  Type _realType() => Type.ns;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => ns._pack(msg, compression, compressionOff);
}

NSResource _unpackNSResource(List<int> msg, int off) {
  final ns = Name();
  ns._unpack(msg, off);
  return NSResource(ns);
}

/// A PTRResource is a PTR Resource record. Port of `dnsmessage.PTRResource`
/// (message.go:2364-2367).
final class PTRResource implements ResourceBody {
  PTRResource(this.ptr);

  Name ptr;

  @override
  Type _realType() => Type.ptr;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => ptr._pack(msg, compression, compressionOff);
}

PTRResource _unpackPTRResource(List<int> msg, int off) {
  final ptr = Name();
  ptr._unpack(msg, off);
  return PTRResource(ptr);
}

/// An SOAResource is an SOA Resource record. Port of `dnsmessage.SOAResource`
/// (message.go:2392-2404).
final class SOAResource implements ResourceBody {
  SOAResource(
    this.ns,
    this.mbox,
    this.serial,
    this.refresh,
    this.retry,
    this.expire,
    this.minTTL,
  );

  Name ns;
  Name mbox;
  int serial;
  int refresh;
  int retry;
  int expire;

  /// MinTTL the is the default TTL of Resources records which did not
  /// contain a TTL value and the TTL of negative responses. (RFC 2308
  /// Section 4)
  int minTTL;

  @override
  Type _realType() => Type.soa;

  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    try {
      ns._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('SOAResource.NS', e);
    }
    try {
      mbox._pack(msg, compression, compressionOff);
    } on FormatException catch (e) {
      _nest('SOAResource.MBox', e);
    }
    _packUint32(msg, serial);
    _packUint32(msg, refresh);
    _packUint32(msg, retry);
    _packUint32(msg, expire);
    _packUint32(msg, minTTL);
  }
}

SOAResource _unpackSOAResource(List<int> msg, int off) {
  final ns = Name();
  int newOff;
  try {
    newOff = ns._unpack(msg, off);
  } on FormatException catch (e) {
    _nest('NS', e);
  }
  final mbox = Name();
  try {
    newOff = mbox._unpack(msg, newOff);
  } on FormatException catch (e) {
    _nest('MBox', e);
  }
  final int serial, refresh, retry, expire, minTTL;
  try {
    (serial, newOff) = _unpackUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('Serial', e);
  }
  try {
    (refresh, newOff) = _unpackUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('Refresh', e);
  }
  try {
    (retry, newOff) = _unpackUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('Retry', e);
  }
  try {
    (expire, newOff) = _unpackUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('Expire', e);
  }
  try {
    (minTTL, newOff) = _unpackUint32(msg, newOff);
  } on FormatException catch (e) {
    _nest('MinTTL', e);
  }
  return SOAResource(ns, mbox, serial, refresh, retry, expire, minTTL);
}

/// A TXTResource is a TXT Resource record. Port of `dnsmessage.TXTResource`
/// (message.go:2474-2476).
final class TXTResource implements ResourceBody {
  TXTResource(this.txt);

  List<String> txt;

  @override
  Type _realType() => Type.txt;

  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    for (final s in txt) {
      _packText(msg, s.codeUnits);
    }
  }
}

TXTResource _unpackTXTResource(List<int> msg, int off, int length) {
  final txts = <String>[];
  var n = 0;
  while (n < length) {
    final List<int> t;
    try {
      (t, off) = _unpackText(msg, off);
    } on FormatException catch (e) {
      _nest('text', e);
    }
    if (length - n < t.length + 1) throw const FormatException(_errCalcLen);
    n += t.length + 1;
    txts.add(String.fromCharCodes(t));
  }
  return TXTResource(txts);
}

/// An SRVResource is an SRV Resource record. Port of `dnsmessage.SRVResource`
/// (message.go:2527-2532).
final class SRVResource implements ResourceBody {
  SRVResource(this.priority, this.weight, this.port, this.target);

  int priority;
  int weight;
  int port;

  /// Not compressed as per RFC 2782.
  Name target;

  @override
  Type _realType() => Type.srv;

  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    _packUint16(msg, priority);
    _packUint16(msg, weight);
    _packUint16(msg, port);
    try {
      target._pack(msg, null, compressionOff);
    } on FormatException catch (e) {
      _nest('SRVResource.Target', e);
    }
  }
}

SRVResource _unpackSRVResource(List<int> msg, int off) {
  final int priority, weight, port;
  try {
    (priority, off) = _unpackUint16(msg, off);
  } on FormatException catch (e) {
    _nest('Priority', e);
  }
  try {
    (weight, off) = _unpackUint16(msg, off);
  } on FormatException catch (e) {
    _nest('Weight', e);
  }
  try {
    (port, off) = _unpackUint16(msg, off);
  } on FormatException catch (e) {
    _nest('Port', e);
  }
  final target = Name();
  try {
    target._unpack(msg, off);
  } on FormatException catch (e) {
    _nest('Target', e);
  }
  return SRVResource(priority, weight, port, target);
}

/// An AResource is an A Resource record. Port of `dnsmessage.AResource`
/// (message.go:2580-2583).
final class AResource implements ResourceBody {
  AResource(this.a);

  Uint8List a;

  @override
  Type _realType() => Type.a;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => _packBytes(msg, a);
}

AResource _unpackAResource(List<int> msg, int off) {
  final a = Uint8List(4);
  _unpackBytes(msg, off, a);
  return AResource(a);
}

/// An AAAAResource is an AAAA Resource record. Port of
/// `dnsmessage.AAAAResource` (message.go:2608-2611).
final class AAAAResource implements ResourceBody {
  AAAAResource(this.aaaa);

  Uint8List aaaa;

  @override
  Type _realType() => Type.aaaa;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => _packBytes(msg, aaaa);
}

AAAAResource _unpackAAAAResource(List<int> msg, int off) {
  final aaaa = Uint8List(16);
  _unpackBytes(msg, off, aaaa);
  return AAAAResource(aaaa);
}

/// An OPTResource is an OPT pseudo Resource record.
///
/// The pseudo resource record is part of the extension mechanisms for DNS
/// as defined in RFC 6891. Port of `dnsmessage.OPTResource`
/// (message.go:2640-2642).
final class OPTResource implements ResourceBody {
  OPTResource(this.options);

  List<Option> options;

  @override
  Type _realType() => Type.opt;

  @override
  void _pack(List<int> msg, Map<String, int>? compression, int compressionOff) {
    for (final opt in options) {
      _packUint16(msg, opt.code);
      _packUint16(msg, opt.data.length);
      _packBytes(msg, opt.data);
    }
  }
}

/// An Option represents a DNS message option within OPTResource.
///
/// Port of `dnsmessage.Option` (message.go:2648-2651).
final class Option {
  Option(this.code, this.data);

  /// option code
  int code;
  Uint8List data;
}

OPTResource _unpackOPTResource(List<int> msg, int off, int length) {
  final opts = <Option>[];
  final oldOff = off;
  while (off < oldOff + length) {
    final int code, l;
    try {
      (code, off) = _unpackUint16(msg, off);
    } on FormatException catch (e) {
      _nest('Code', e);
    }
    try {
      (l, off) = _unpackUint16(msg, off);
    } on FormatException catch (e) {
      _nest('Data', e);
    }
    final data = Uint8List(l);
    if (off + l > msg.length) throw const FormatException(_errCalcLen);
    data.setRange(0, l, msg, off);
    off += l;
    opts.add(Option(code, data));
  }
  return OPTResource(opts);
}

/// An UnknownResource is a catch-all container for unknown record types.
///
/// Port of `dnsmessage.UnknownResource` (message.go:2712-2715).
final class UnknownResource implements ResourceBody {
  UnknownResource(this.type, this.data);

  Type type;
  Uint8List data;

  @override
  Type _realType() => type;

  @override
  void _pack(
    List<int> msg,
    Map<String, int>? compression,
    int compressionOff,
  ) => _packBytes(msg, data);
}

UnknownResource _unpackUnknownResource(
  Type recordType,
  List<int> msg,
  int off,
  int length,
) {
  final data = Uint8List(length);
  _unpackBytes(msg, off, data);
  return UnknownResource(recordType, data);
}
