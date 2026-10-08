/// Shim parcial do pacote Go `net/textproto` (Go 1.26): porta fiel de
/// `header.go` (`MIMEHeader`), de `CanonicalMIMEHeaderKey` e auxiliares de
/// `reader.go`, e de `TrimString`/`TrimBytes`, `Error` e `ProtocolError` de
/// `textproto.go`.
///
/// `MIMEHeader` tem a forma que o g2d gera para um tipo nomeado sobre map
/// (`SHIM_NAMED_CLASSES` em `g2d/config.py`): subclasse de [GoMap] com
/// `super.alias` e a vista `MIMEHeader$Ptr` para `*MIMEHeader`.
///
/// ⚠️ `Reader`, `Writer`, `Conn`, `Pipeline`, `NewConn`, `Dial` e
/// `ReadMIMEHeader` ficam de fora (precisam de `bufio`): viram
/// `shim-simbolo:net/textproto.*`.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' as fmt;

typedef _Bytes = Slice<Golang.Uint8>;

const _strElem = Elem<Golang.String>(
  16,
  Golang.String.new,
  pointers: true,
);

/// `textproto.MIMEHeader` (`type MIMEHeader map[string][]string`).
final class MIMEHeader extends GoMap<Golang.String, Slice<Golang.String>>
    implements Golang.GoTyped {
  MIMEHeader(GoMap<Golang.String, Slice<Golang.String>> v) : super.alias(v);

  @override
  String get $goType => 'textproto.MIMEHeader';
  @override
  List<String> get $methods => _mimeHeaderMethods;

  /// `Add(key, value)`: acrescenta value aos valores da chave canônica.
  void add(Golang.String key, Golang.String value) {
    key = canonicalMIMEHeaderKey(key);
    this[key] = this[key].append([value]);
  }

  /// `Set(key, value)`: troca os valores da chave canônica por `[value]`.
  void set(Golang.String key, Golang.String value) {
    this[canonicalMIMEHeaderKey(key)] = Slice.of([value], _strElem);
  }

  /// `Get(key)`: o primeiro valor da chave canônica, ou "".
  Golang.String get(Golang.String key) {
    if (isNil) return Golang.String();
    final v = this[canonicalMIMEHeaderKey(key)];
    if (v.length == 0) return Golang.String();
    return v[0];
  }

  /// `Values(key)`: todos os valores da chave canônica (o próprio slice).
  Slice<Golang.String> values(Golang.String key) {
    if (isNil) return Slice.nil(_strElem);
    return this[canonicalMIMEHeaderKey(key)];
  }

  /// `Del(key)`: apaga a chave canônica.
  void del(Golang.String key) => delete(canonicalMIMEHeaderKey(key));
}

const _mimeHeaderMethods = ['Add', 'Del', 'Get', 'Set', 'Values'];

/// `*textproto.MIMEHeader`: vista sobre qualquer ponteiro para o valor.
final class MIMEHeader$Ptr extends PtrView<MIMEHeader> {
  MIMEHeader$Ptr(super.$p);

  /// `(*MIMEHeader)(nil)` dentro de uma interface.
  static final MIMEHeader$Ptr $nil = MIMEHeader$Ptr(
    const NilPtr<MIMEHeader>(),
  );

  @override
  String get $goType => '*textproto.MIMEHeader';
  @override
  List<String> get $methods => _mimeHeaderMethods;

  void add(Golang.String p0, Golang.String p1) => $p.value.add(p0, p1);
  void set(Golang.String p0, Golang.String p1) => $p.value.set(p0, p1);
  Golang.String get(Golang.String p0) => $p.value.get(p0);
  Slice<Golang.String> values(Golang.String p0) => $p.value.values(p0);
  void del(Golang.String p0) => $p.value.del(p0);
}

/// `textproto.Error`: resposta de erro numérica de um servidor.
final class Error extends GoStruct<Error> implements GoError {
  Error({Golang.Int? code, Golang.String? msg})
    : code = code ?? Golang.Int(),
      msg = msg ?? Golang.String();

  /// `(*Error)(nil)` dentro de uma interface.
  static final Error $nil = Error()..$nilPtr = true;

  /// `Code`.
  Golang.Int code;

  /// `Msg`.
  Golang.String msg;

  @override
  String get $goType => 'textproto.Error';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Error'];
  @override
  Error $copy() => Error(code: code, msg: msg);
  @override
  void $set(Error o) {
    code = o.code;
    msg = o.msg;
  }

  @override
  List<Object?> get $fields => [code, msg];
  @override
  List<String> get $fieldNames => const ['Code', 'Msg'];
  @override
  List<String> get $fieldTypes => const ['int', 'string'];

  /// `Error()`: `fmt.Sprintf("%03d %q", e.Code, e.Msg)`.
  @override
  Golang.String error() {
    final Error? e = $nilPtr ? null : this;
    return fmt.sprintf(
      Golang.String.fromDart('%03d %q'),
      Slice.of([e!.code, e.msg], const Elem<Object?>(16, zeroNull)),
    );
  }
}

/// `textproto.ProtocolError` (`type ProtocolError string`): violação de
/// protocolo, como uma resposta inválida.
final class ProtocolError extends Golang.StringBase<ProtocolError>
    implements GoError, Golang.GoTyped {
  ProtocolError([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;
  @override
  ProtocolError $wrapStr(Golang.String s) => ProtocolError(s);
  @override
  String get $goType => 'textproto.ProtocolError';
  @override
  List<String> get $methods => const ['Error'];

  /// `Error()`: a própria string.
  @override
  Golang.String error() => _v;
}

/// `TrimString(s)`: s sem espaço ASCII (` `, `\t`, `\n`, `\r`) nas pontas.
Golang.String trimString(Golang.String s) {
  var i = 0, j = s.length;
  while (i < j && _isASCIISpace(s[i])) {
    i++;
  }
  while (i < j && _isASCIISpace(s[j - 1])) {
    j--;
  }
  return s.slice(i, j);
}

/// `TrimBytes(b)`: como [trimString], sobre o mesmo array.
_Bytes trimBytes(_Bytes b) {
  var i = 0, j = b.length;
  while (i < j && _isASCIISpace(b[i].toInt())) {
    i++;
  }
  while (i < j && _isASCIISpace(b[j - 1].toInt())) {
    j--;
  }
  // `b[i:j]` com `i == j == 0` de um nil continua nil, como no Go.
  return b.isNil ? b : b.slice(i, j);
}

bool _isASCIISpace(int b) => b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d;

/// `CanonicalMIMEHeaderKey(s)`: forma canônica da chave (`accept-encoding`
/// → `Accept-Encoding`); s inválida (espaço ou byte fora de token) volta
/// inalterada.
Golang.String canonicalMIMEHeaderKey(Golang.String s) {
  var upper = true;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (!_validHeaderFieldByte(c)) return s;
    if ((upper && 0x61 <= c && c <= 0x7a) ||
        (!upper && 0x41 <= c && c <= 0x5a)) {
      return _canonicalMIMEHeaderKey(s.toBytes()).$1;
    }
    upper = c == 0x2d;
  }
  return s;
}

/// `validHeaderFieldByte(c)`: c é `tchar` do RFC 7230.
bool _validHeaderFieldByte(int c) =>
    c < 0x80 && _tchar.codeUnits.contains(c) ||
    (0x30 <= c && c <= 0x39) ||
    (0x61 <= c && c <= 0x7a) ||
    (0x41 <= c && c <= 0x5a);

const _tchar = "!#\$%&'*+-.^_`|~";

/// `canonicalMIMEHeaderKey(a)`: muda a no lugar; ok diz se só há bytes de
/// token e espaços.
// ponytail: sem a tabela `commonHeader` do Go; ela só interna strings
// (mesmo valor), o que não se observa no Dart.
(Golang.String, bool) _canonicalMIMEHeaderKey(Uint8List a) {
  if (a.isEmpty) return (Golang.String(), false);
  var noCanon = false;
  for (final c in a) {
    if (_validHeaderFieldByte(c)) continue;
    if (c == 0x20) {
      noCanon = true;
      continue;
    }
    return (Golang.String.fromBytes(a), false);
  }
  if (noCanon) return (Golang.String.fromBytes(a), true);
  var upper = true;
  for (var i = 0; i < a.length; i++) {
    var c = a[i];
    if (upper && 0x61 <= c && c <= 0x7a) {
      c -= 0x20;
    } else if (!upper && 0x41 <= c && c <= 0x5a) {
      c += 0x20;
    }
    a[i] = c;
    upper = c == 0x2d;
  }
  return (Golang.String.fromBytes(a), true);
}
