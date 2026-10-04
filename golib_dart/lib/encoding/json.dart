/// Shim do pacote Go `encoding/json`: porta do `encoding/json` v1 do Go
/// 1.26 (`encode.go`, `decode.go`, `scanner.go`, `stream.go`, `indent.go`,
/// `fold.go`, `tags.go`) sobre o shim `reflect` (descritores estáticos do
/// g2d, decisão D1): o g2d liga os descritores em todo grafo que importa
/// `encoding/json` (`REFLECT_PKGS`).
///
/// Mesmas regras do Go: campos (tag `json`, `-`, `omitempty`, `omitzero`,
/// `string`, embutidos e o campo dominante por profundidade/tag), mapas com
/// chaves ordenadas, `[]byte` em base64, escape HTML, UTF-8 inválido como
/// `�`, cortes `'e'`/`'f'` dos floats, `Marshaler`/`TextMarshaler` (e
/// os `Unmarshaler`) no valor e, se endereçável, no ponteiro, detecção de
/// ciclo depois de 1000 níveis, e as mensagens de erro exatas.
///
/// I/O (D2): `Encoder`/`Decoder` só guardam o `io.Writer`/`io.Reader`
/// (`WRAPPING_SHIM_CALLS`); `Encode`/`Decode`/`Token`/`More` são métodos de
/// tipo do shim e, como todo tipo concreto do shim, síncronos: sobre um
/// leitor/escritor que suspende de fato caem no `fatal` `g2d:` do
/// `go.syncOfAsync` (nunca num resultado errado).
///
/// ⚠️ Limites (ver `docs/mapping-spec.md`):
/// - `RawMessage` é `typedef` de `[]byte` (o g2d ainda não converte para
///   tipo composto nomeado de shim): como campo, elemento ou valor de map
///   (descritor `json.RawMessage`) é fiel; dentro de uma interface (`any`)
///   ou como alvo direto (`Marshal(raw)`, `Unmarshal(b, &raw)`) vira
///   `[]byte`;
/// - `Unmarshaler`/`TextUnmarshaler`/`Marshaler` de receptor ponteiro num
///   tipo nomeado que não é struct, alcançado pelo endereço de um campo,
///   elemento ou chave (o `*N` do reflect não é a classe `N$Ptr`): panic
///   explícito;
/// - tipos de shim sem descritor (`big.Int`...; `time.Time` tem): panic
///   explícito do reflect ao listar os campos ou ao gravar.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../bytes.dart' as bytes;
import '../encoding.dart' as encoding;
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' as fmt;
import '../io.dart' as io;
import '../reflect.dart' as reflect;
import '../strconv.dart' as strconv;
import '../unicode.dart' as unicode;

part '../src/encoding/json/types.dart';
part '../src/encoding/json/errors.dart';
part '../src/encoding/json/scanner.dart';
part '../src/encoding/json/indent.dart';
part '../src/encoding/json/encode.dart';
part '../src/encoding/json/encode_scalar.dart';
part '../src/encoding/json/encode_compound.dart';
part '../src/encoding/json/ifaces.dart';
part '../src/encoding/json/encode_string.dart';
part '../src/encoding/json/fields.dart';
part '../src/encoding/json/decode.dart';
part '../src/encoding/json/decode_compound.dart';
part '../src/encoding/json/decode_indirect.dart';
part '../src/encoding/json/decode_literal.dart';
part '../src/encoding/json/decode_any.dart';
part '../src/encoding/json/unquote.dart';
part '../src/encoding/json/stream.dart';
part '../src/encoding/json/token.dart';
part '../src/encoding/json/base64.dart';

typedef _Bytes = Slice<Golang.Uint8>;

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

_Bytes _nilBytes() => Slice<Golang.Uint8>.nil(_byteElem);

/// Os bytes de um `[]byte` (cópia).
Uint8List _in(_Bytes s) {
  final out = Uint8List(s.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = s[i].toInt();
  }
  return out;
}

List<Golang.Uint8> _u8(List<int> b) => [for (final x in b) Golang.Uint8(x)];

/// `append([]byte(nil), b...)`: o `cap` cresce como o `append` do Go.
_Bytes _out(List<int> b) => _nilBytes().append(_u8(b));

Golang.String _gs(String s) => Golang.String.fromDart(s);

/// Texto Go (bytes) de uma string Dart só ASCII ou de bytes.
Golang.String _gsb(List<int> b) =>
    Golang.String.fromBytes(b is Uint8List ? b : Uint8List.fromList(b));

/// `%q` do Go sobre bytes/string: `strconv.Quote`.
String _q(List<int> b) => strconv.quote(_gsb(b)).toString();

/// `json.Marshaler`.
abstract interface class Marshaler {
  (_Bytes, GoError?) marshalJSON();
}

/// `json.Unmarshaler`.
abstract interface class Unmarshaler {
  GoError? unmarshalJSON(_Bytes data);
}

/// `json.Token` (`type Token any`).
typedef Token = Object?;

/// `json.Marshal(v)`.
(_Bytes, GoError?) marshal(Object? v) {
  final e = _EncodeState();
  final err = e.marshal(v, _optEscapeHTML);
  if (err != null) return (_nilBytes(), err);
  return (_out(e.buf), null);
}

/// `json.MarshalIndent(v, prefix, indent)`.
(_Bytes, GoError?) marshalIndent(
  Object? v,
  Golang.String prefix,
  Golang.String indent,
) {
  final e = _EncodeState();
  final err = e.marshal(v, _optEscapeHTML);
  if (err != null) return (_nilBytes(), err);
  final dst = <int>[];
  final err2 = _appendIndent(dst, e.buf, prefix.toBytes(), indent.toBytes());
  if (err2 != null) return (_nilBytes(), err2);
  final n = e.buf.length;
  final b2 = Slice<Golang.Uint8>.make(0, _indentGrowthFactor * n, _byteElem);
  return (b2.append(_u8(dst)), null);
}

/// `json.Unmarshal(data, v)`.
GoError? unmarshal(_Bytes data, Object? v) {
  final d = _DecodeState();
  final b = _in(data);
  final err = _checkValid(b, d.scan);
  if (err != null) return err;
  d.init(b, data);
  return d.unmarshal(v);
}

/// `json.Valid(data)`.
bool valid(_Bytes data) => _checkValid(_in(data), _Scanner()) == null;

/// `json.Compact(dst, src)`.
GoError? compact(bytes.Buffer? dst, _Bytes src) {
  dst!.grow(Golang.Int(src.length));
  final b = <int>[];
  final err = _appendCompact(b, _in(src), false);
  dst.write(_out(b));
  return err;
}

/// `json.Indent(dst, src, prefix, indent)`.
GoError? indent(
  bytes.Buffer? dst,
  _Bytes src,
  Golang.String prefix,
  Golang.String indent,
) {
  dst!.grow(Golang.Int(_indentGrowthFactor * src.length));
  final b = <int>[];
  final err = _appendIndent(b, _in(src), prefix.toBytes(), indent.toBytes());
  dst.write(_out(b));
  return err;
}

/// `json.HTMLEscape(dst, src)`.
void htmlEscape(bytes.Buffer? dst, _Bytes src) {
  dst!.grow(Golang.Int(src.length));
  final b = <int>[];
  _appendHTMLEscape(b, _in(src));
  dst.write(_out(b));
}
