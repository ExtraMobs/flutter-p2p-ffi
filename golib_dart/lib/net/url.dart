/// Shim do pacote Go `net/url`: porta inteira de `net/url/url.go` e
/// `encoding_table.go` do Go 1.26.5, sobre os bytes das strings.
///
/// `Values` tem a forma que o g2d gera para um tipo nomeado sobre map
/// (`SHIM_NAMED_CLASSES` em `g2d/config.py`): subclasse de [GoMap] com
/// `super.alias` e a vista `Values$Ptr` para `*Values`. `URL`, `Userinfo` e
/// `Error` são structs de shim ([GoStruct]); `EscapeError` e
/// `InvalidHostError` são nomeados sobre string.
///
/// ⚠️ GODEBUG fixo nos padrões do Go 1.26.5 (`internal/godebugs/table.go`):
/// `urlstrictcolons` estrito (`http://a:b:80` é erro) e `urlmaxqueryparams`
/// no limite padrão de 10000 parâmetros; a variável de ambiente `GODEBUG` e
/// a diretiva `//go:debug` não são lidas.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' as fmt show sprintf, errorf, Stringer;
import '../net/netip.dart' as netip;
import '../path.dart' as pathpkg;
import '../slices.dart' as slices;
import '../strconv.dart' as strconv;
import '../strings.dart' as strings;

part '../src/net/url/escape.dart';
part '../src/net/url/parse.dart';
part '../src/net/url/url.dart';
part '../src/net/url/userinfo.dart';
part '../src/net/url/values.dart';

Golang.String _gs(String s) => Golang.String.fromDart(s);

GoError _errNew(String s) => ErrorString(_gs(s));

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);

const _anyElem = Elem<Object?>(16, zeroNull, pointers: true);

/// `url.Error`: a operação e a URL que causaram o erro.
final class Error extends GoStruct<Error>
    implements NetError, Unwrapper, Golang.GoTyped {
  Error({Golang.String? op, Golang.String? url, this.err})
    : op = op ?? Golang.String(),
      url = url ?? Golang.String();

  /// `(*Error)(nil)` dentro de uma interface.
  static final Error $nil = Error()..$nilPtr = true;

  /// `Op`.
  Golang.String op;

  /// `URL`.
  Golang.String url;

  /// `Err`.
  GoError? err;

  @override
  String get $goType => 'url.Error';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const [
    'Error',
    'Temporary',
    'Timeout',
    'Unwrap',
  ];
  @override
  Error $copy() => Error(op: op, url: url, err: err);
  @override
  void $set(Error o) {
    op = o.op;
    url = o.url;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [op, url, dynField(err)];
  @override
  List<String> get $fieldNames => const ['Op', 'URL', 'Err'];
  @override
  List<String> get $fieldTypes => const ['string', 'string', 'error'];

  Error get _self {
    if ($nilPtr) nilDeref();
    return this;
  }

  /// `Unwrap()`.
  @override
  GoError? unwrap() => _self.err;

  /// `Error()`: `fmt.Sprintf("%s %q: %s", e.Op, e.URL, e.Err)`.
  @override
  Golang.String error() {
    final e = _self;
    return fmt.sprintf(
      _gs('%s %q: %s'),
      Slice.of([e.op, e.url, e.err], _anyElem),
    );
  }

  /// `Timeout()`: o do erro embrulhado, se ele tiver.
  @override
  bool timeout() => switch (_self.err) {
    final Timeouter t when goHasMethod(t, 'Timeout') => t.timeout(),
    _ => false,
  };

  /// `Temporary()`: o do erro embrulhado, se ele tiver.
  @override
  bool temporary() => switch (_self.err) {
    final Temporary t when goHasMethod(t, 'Temporary') => t.temporary(),
    _ => false,
  };
}
