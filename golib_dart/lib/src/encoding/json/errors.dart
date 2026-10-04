part of '../../../encoding/json.dart';

// Os erros do pacote, como structs de shim (`*json.SyntaxError` é o objeto,
// como o `*T` de uma struct gerada): type assertion, `errors.As` e acesso a
// campo funcionam como no Go. Mensagens exatas do Go 1.26.

/// `*json.SyntaxError`.
final class SyntaxError extends GoStruct<SyntaxError> implements GoError {
  SyntaxError({Golang.Int64? offset})
    : _msg = '',
      offset = offset ?? Golang.Int64();
  SyntaxError._(this._msg, int offset) : offset = Golang.Int64(offset);

  static final SyntaxError $nil = SyntaxError()..$nilPtr = true;

  String _msg;

  /// `Offset`: o erro ocorreu depois de ler `Offset` bytes.
  Golang.Int64 offset;

  @override
  Golang.String error() => _gs(_msg);

  @override
  String get $goType => 'json.SyntaxError';

  @override
  List<String> get $ptrMethods => const ['Error'];

  @override
  SyntaxError $copy() => SyntaxError._(_msg, 0)..offset = offset;

  @override
  void $set(SyntaxError o) {
    _msg = o._msg;
    offset = o.offset;
  }

  @override
  List<Object?> get $fields => [_gs(_msg), offset];

  @override
  List<String> get $fieldNames => const ['msg', 'Offset'];

  @override
  List<String> get $fieldTypes => const ['string', 'int64'];
}

/// `*json.UnmarshalTypeError`.
final class UnmarshalTypeError extends GoStruct<UnmarshalTypeError>
    implements GoError {
  UnmarshalTypeError({
    Golang.String? value,
    this.type,
    Golang.Int64? offset,
    Golang.String? struct,
    Golang.String? field,
  }) : value$ = value ?? Golang.String(),
       offset = offset ?? Golang.Int64(),
       struct = struct ?? Golang.String(),
       field = field ?? Golang.String();

  static final UnmarshalTypeError $nil = UnmarshalTypeError()..$nilPtr = true;

  /// `Value`: descrição do valor JSON (`"bool"`, `"array"`, `"number -5"`).
  Golang.String value$;

  /// `Type`: o tipo Go que não pôde recebê-lo.
  RType? type;

  /// `Offset`.
  Golang.Int64 offset;

  /// `Struct`: nome da struct que contém o campo.
  Golang.String struct;

  /// `Field`: o caminho do campo a partir da raiz.
  Golang.String field;

  @override
  Golang.String error() {
    if (struct.length != 0 || field.length != 0) {
      return _gs('json: cannot unmarshal ') +
          value$ +
          _gs(' into Go struct field ') +
          struct +
          _gs('.') +
          field +
          _gs(' of type ${type!.$str}');
    }
    return _gs('json: cannot unmarshal ') +
        value$ +
        _gs(' into Go value of type ${type!.$str}');
  }

  @override
  String get $goType => 'json.UnmarshalTypeError';

  @override
  List<String> get $ptrMethods => const ['Error'];

  @override
  UnmarshalTypeError $copy() => UnmarshalTypeError(
    value: value$,
    type: type,
    offset: offset,
    struct: struct,
    field: field,
  );

  @override
  void $set(UnmarshalTypeError o) {
    value$ = o.value$;
    type = o.type;
    offset = o.offset;
    struct = o.struct;
    field = o.field;
  }

  @override
  List<Object?> get $fields => [value$, type, offset, struct, field];

  @override
  List<String> get $fieldNames => const [
    'Value',
    'Type',
    'Offset',
    'Struct',
    'Field',
  ];

  @override
  List<String> get $fieldTypes => const [
    'string',
    'reflect.Type',
    'int64',
    'string',
    'string',
  ];
}

/// `*json.InvalidUnmarshalError`: alvo do `Unmarshal` nil ou não ponteiro.
final class InvalidUnmarshalError extends GoStruct<InvalidUnmarshalError>
    implements GoError {
  InvalidUnmarshalError({this.type});

  static final InvalidUnmarshalError $nil = InvalidUnmarshalError()
    ..$nilPtr = true;

  /// `Type`.
  RType? type;

  @override
  Golang.String error() {
    final t = type;
    if (t == null) return _gs('json: Unmarshal(nil)');
    if (t.$kind != reflect.kPointer) {
      return _gs('json: Unmarshal(non-pointer ${t.$str})');
    }
    return _gs('json: Unmarshal(nil ${t.$str})');
  }

  @override
  String get $goType => 'json.InvalidUnmarshalError';

  @override
  List<String> get $ptrMethods => const ['Error'];

  @override
  InvalidUnmarshalError $copy() => InvalidUnmarshalError(type: type);

  @override
  void $set(InvalidUnmarshalError o) => type = o.type;

  @override
  List<Object?> get $fields => [type];

  @override
  List<String> get $fieldNames => const ['Type'];

  @override
  List<String> get $fieldTypes => const ['reflect.Type'];
}

/// `*json.UnsupportedTypeError`.
final class UnsupportedTypeError extends GoStruct<UnsupportedTypeError>
    implements GoError {
  UnsupportedTypeError({this.type});

  static final UnsupportedTypeError $nil = UnsupportedTypeError()
    ..$nilPtr = true;

  /// `Type`.
  RType? type;

  @override
  Golang.String error() => _gs('json: unsupported type: ${type!.$str}');

  @override
  String get $goType => 'json.UnsupportedTypeError';

  @override
  List<String> get $ptrMethods => const ['Error'];

  @override
  UnsupportedTypeError $copy() => UnsupportedTypeError(type: type);

  @override
  void $set(UnsupportedTypeError o) => type = o.type;

  @override
  List<Object?> get $fields => [type];

  @override
  List<String> get $fieldNames => const ['Type'];

  @override
  List<String> get $fieldTypes => const ['reflect.Type'];
}

/// `*json.UnsupportedValueError` (NaN/Inf, ciclo).
final class UnsupportedValueError extends GoStruct<UnsupportedValueError>
    implements GoError {
  UnsupportedValueError({reflect.Value? value, Golang.String? str})
    : value$ = value ?? reflect.Value(),
      str = str ?? Golang.String();

  static final UnsupportedValueError $nil = UnsupportedValueError()
    ..$nilPtr = true;

  /// `Value`.
  reflect.Value value$;

  /// `Str`.
  Golang.String str;

  @override
  Golang.String error() => _gs('json: unsupported value: ') + str;

  @override
  String get $goType => 'json.UnsupportedValueError';

  @override
  List<String> get $ptrMethods => const ['Error'];

  @override
  UnsupportedValueError $copy() =>
      UnsupportedValueError(value: value$.$copy(), str: str);

  @override
  void $set(UnsupportedValueError o) {
    value$.$set(o.value$);
    str = o.str;
  }

  @override
  List<Object?> get $fields => [value$, str];

  @override
  List<String> get $fieldNames => const ['Value', 'Str'];

  @override
  List<String> get $fieldTypes => const ['reflect.Value', 'string'];
}

/// `*json.MarshalerError`: erro devolvido por `MarshalJSON`/`MarshalText`.
final class MarshalerError extends GoStruct<MarshalerError>
    implements GoError, Unwrapper {
  MarshalerError({this.type, this.err}) : _sourceFunc = '';
  MarshalerError._(this.type, this.err, this._sourceFunc);

  static final MarshalerError $nil = MarshalerError()..$nilPtr = true;

  /// `Type`.
  RType? type;

  /// `Err`.
  GoError? err;

  String _sourceFunc;

  @override
  Golang.String error() {
    final src = _sourceFunc.isEmpty ? 'MarshalJSON' : _sourceFunc;
    return _gs('json: error calling $src for type ${type!.$str}: ') +
        err!.error();
  }

  /// `Unwrap() error`.
  @override
  GoError? unwrap() => err;

  @override
  String get $goType => 'json.MarshalerError';

  @override
  List<String> get $ptrMethods => const ['Error', 'Unwrap'];

  @override
  MarshalerError $copy() => MarshalerError._(type, err, _sourceFunc);

  @override
  void $set(MarshalerError o) {
    type = o.type;
    err = o.err;
    _sourceFunc = o._sourceFunc;
  }

  @override
  List<Object?> get $fields => [type, err, _gs(_sourceFunc)];

  @override
  List<String> get $fieldNames => const ['Type', 'Err', 'sourceFunc'];

  @override
  List<String> get $fieldTypes => const ['reflect.Type', 'error', 'string'];
}

/// O `jsonError` do Go: panic interno do codificador, recuperado no
/// `marshal` e devolvido como erro.
final class _JsonError implements Exception {
  _JsonError(this.err);
  final GoError err;
}

/// `fmt.Errorf` sem `%w`: `*errors.errorString`.
GoError _errorf(String msg) => ErrorString(_gs(msg));
