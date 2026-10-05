part of '../../net.dart';

/// `net.ParseError`: endereço textual inválido.
final class ParseError extends GoStruct<ParseError> implements Error {
  ParseError({Golang.String? type, Golang.String? text})
    : type = type ?? Golang.String(),
      text = text ?? Golang.String();

  /// `(*ParseError)(nil)` dentro de uma interface.
  static final ParseError $nil = ParseError()..$nilPtr = true;

  /// `Type`: o tipo de string esperado (`IP address`, `CIDR address`).
  Golang.String type;

  /// `Text`: o texto malformado.
  Golang.String text;

  @override
  String get $goType => 'net.ParseError';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Error', 'Temporary', 'Timeout'];
  @override
  ParseError $copy() => ParseError(type: type, text: text);
  @override
  void $set(ParseError o) {
    type = o.type;
    text = o.text;
  }

  @override
  List<Object?> get $fields => [type, text];
  @override
  List<String> get $fieldNames => const ['Type', 'Text'];
  @override
  List<String> get $fieldTypes => const ['string', 'string'];

  /// `Error()`: `invalid <Type>: <Text>`.
  @override
  Golang.String error() {
    final ParseError? e = $nilPtr ? null : this;
    return _gs('invalid ') + e!.type + _gs(': ') + e.text;
  }

  @override
  bool timeout() => false;
  @override
  bool temporary() => false;
}

/// `net.AddrError`: endereço inválido (`address <Addr>: <Err>`).
final class AddrError extends GoStruct<AddrError> implements Error {
  AddrError({Golang.String? err, Golang.String? addr})
    : err = err ?? Golang.String(),
      addr$ = addr ?? Golang.String();

  /// `(*AddrError)(nil)` dentro de uma interface.
  static final AddrError $nil = AddrError()..$nilPtr = true;

  /// `Err`: a descrição.
  Golang.String err;

  /// `Addr`: o endereço.
  Golang.String addr$;

  @override
  String get $goType => 'net.AddrError';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Error', 'Temporary', 'Timeout'];
  @override
  AddrError $copy() => AddrError(err: err, addr: addr$);
  @override
  void $set(AddrError o) {
    err = o.err;
    addr$ = o.addr$;
  }

  @override
  List<Object?> get $fields => [err, addr$];
  @override
  List<String> get $fieldNames => const ['Err', 'Addr'];
  @override
  List<String> get $fieldTypes => const ['string', 'string'];

  /// `Error()`.
  @override
  Golang.String error() {
    if ($nilPtr) return _gs('<nil>');
    var s = err;
    if (addr$.length != 0) s = _gs('address ') + addr$ + _gs(': ') + s;
    return s;
  }

  @override
  bool timeout() => false;
  @override
  bool temporary() => false;
}

/// `net.UnknownNetworkError` (`type UnknownNetworkError string`).
final class UnknownNetworkError extends Golang.StringBase<UnknownNetworkError>
    implements Error {
  UnknownNetworkError([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;
  @override
  UnknownNetworkError $wrapStr(Golang.String s) => UnknownNetworkError(s);
  @override
  String get $goType => 'net.UnknownNetworkError';
  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];

  /// `Error()`: `unknown network <e>`.
  @override
  Golang.String error() => _gs('unknown network ') + _v;
  @override
  bool timeout() => false;
  @override
  bool temporary() => false;
}

/// `net.InvalidAddrError` (`type InvalidAddrError string`).
final class InvalidAddrError extends Golang.StringBase<InvalidAddrError>
    implements Error {
  InvalidAddrError([Golang.String? v]) : _v = v ?? Golang.String();
  final Golang.String _v;

  @override
  Golang.String get $str => _v;
  @override
  InvalidAddrError $wrapStr(Golang.String s) => InvalidAddrError(s);
  @override
  String get $goType => 'net.InvalidAddrError';
  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];

  @override
  Golang.String error() => _v;
  @override
  bool timeout() => false;
  @override
  bool temporary() => false;
}
