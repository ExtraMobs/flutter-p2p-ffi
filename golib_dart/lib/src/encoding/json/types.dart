part of '../../../encoding/json.dart';

/// `json.RawMessage` (`type RawMessage []byte`).
///
/// ⚠️ `typedef` do `[]byte`, não classe: o g2d dá a um tipo composto
/// nomeado de shim o valor do subjacente (zero value `go.Slice.nil`, campos
/// de struct), e ainda recusa a conversão `json.RawMessage(b)`
/// (`conversao:slice-named-slice`). O codec reconhece o tipo pelo descritor
/// (`json.RawMessage`) de campos, elementos e valores de map; um
/// `RawMessage` guardado numa interface é um `[]byte` comum.
typedef RawMessage = Slice<Golang.Uint8>;

/// O descritor é o do `json.RawMessage` (o opaco que o g2d gera para o tipo
/// de shim, ou um futuro `$rt`)?
bool _isRawMessage(RType t) => t.$str == 'json.RawMessage';

/// Métodos de `json.RawMessage`.
extension RawMessageMethods on Slice<Golang.Uint8> {
  /// `RawMessage.MarshalJSON()`: `null` para o nil; senão os próprios bytes.
  (_Bytes, GoError?) marshalJSON() {
    if (isNil) return (_out('null'.codeUnits), null);
    return (this, null);
  }
}

/// `(*RawMessage).UnmarshalJSON(data)`: `*m = append((*m)[0:0], data...)`.
extension RawMessagePtrMethods on Ptr<Slice<Golang.Uint8>>? {
  GoError? unmarshalJSON(_Bytes data) {
    final m = this;
    if (m == null) {
      return ErrorString(_gs('json.RawMessage: UnmarshalJSON on nil pointer'));
    }
    m.value = m.value.slice(0, 0).appendSlice(data);
    return null;
  }
}

/// `json.Number` (`type Number string`): o literal de número JSON.
final class Number extends Golang.StringBase<Number>
    implements fmt.Stringer, Typed {
  Number([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;

  @override
  Number $wrapStr(Golang.String s) => Number(s);

  @override
  String get $goType => 'json.Number';

  @override
  List<String> get $methods => const ['Float64', 'Int64', 'String'];

  /// Descritor de reflexão (`SHIM_RTYPES`).
  static final RType<Number> $rt = rtNamed<Number>(
    'encoding/json',
    'Number',
    'json.Number',
    () => rtString,
    kind: reflect.kString,
    size: 16,
    align: 8,
    ptrs: true,
    zero: Number.new,
    conv: (v) => Number(v as Golang.String),
    methods: const ['Float64', 'Int64', 'String'],
    ptrMethods: const ['Float64', 'Int64', 'String'],
  );

  @override
  RType get $rtype => $rt;

  /// `Number.String()`.
  @override
  Golang.String string() => _v;

  /// `Number.Float64()`: `strconv.ParseFloat(n, 64)`.
  (Golang.Float64, GoError?) float64() =>
      strconv.parseFloat(_v, Golang.Int(64));

  /// `Number.Int64()`: `strconv.ParseInt(n, 10, 64)`.
  (Golang.Int64, GoError?) int64() =>
      strconv.parseInt(_v, Golang.Int(10), Golang.Int(64));
}

/// `json.Delim` (`type Delim rune`): `[ ] { }` devolvidos por `Token`.
final class Delim extends Golang.Int32Base<Delim>
    implements fmt.Stringer, Typed {
  Delim([int v = 0]) : super(v);
  Delim.from(Golang.IntBase v) : super.from(v);
  Delim.fromBigInt(BigInt v) : super.fromBigInt(v);

  @override
  Delim $make(int v) => Delim(v);

  @override
  String get $goType => 'json.Delim';

  @override
  List<String> get $methods => const ['String'];

  /// Descritor de reflexão (`SHIM_RTYPES`).
  static final RType<Delim> $rt = rtNamed<Delim>(
    'encoding/json',
    'Delim',
    'json.Delim',
    () => rtInt32,
    kind: reflect.kInt32,
    size: 4,
    align: 4,
    zero: Delim.new,
    conv: (v) => Delim.from(v as Golang.IntBase),
    methods: const ['String'],
    ptrMethods: const ['String'],
  );

  @override
  RType get $rtype => $rt;

  /// `Delim.String()`: `string(d)`.
  @override
  Golang.String string() => Golang.String.fromCodePoint(toInt());
}
