part of '../../../net/url.dart';

Slice<Golang.String> _nilStrings() => Slice.nil(_strElem);

const _stringsElem = Elem<Slice<Golang.String>>(
  24,
  _nilStrings,
  pointers: true,
);

/// `url.Values` (`type Values map[string][]string`): chaves sensíveis a
/// caixa, cada uma com uma lista de valores.
final class Values extends GoMap<Golang.String, Slice<Golang.String>>
    implements Golang.GoTyped {
  Values(GoMap<Golang.String, Slice<Golang.String>> v) : super.alias(v);

  @override
  String get $goType => 'url.Values';
  @override
  List<String> get $methods => _valuesMethods;

  /// `Get(key)`: o primeiro valor, ou "".
  Golang.String get(Golang.String key) {
    final vs = this[key];
    return vs.length == 0 ? Golang.String() : vs[0];
  }

  /// `Set(key, value)`: troca os valores por `[value]`.
  void set(Golang.String key, Golang.String value) {
    this[key] = Slice.of([value], _strElem);
  }

  /// `Add(key, value)`: acrescenta value aos valores.
  void add(Golang.String key, Golang.String value) {
    this[key] = this[key].append([value]);
  }

  /// `Del(key)`: apaga a chave.
  void del(Golang.String key) => delete(key);

  /// `Has(key)`: a chave existe.
  bool has(Golang.String key) => containsKey(key);

  /// `Encode()`: `k=v&...` em ordem de chave, com [queryEscape].
  Golang.String encode() {
    if (length == 0) return Golang.String();
    final keys = Slice.of(keysSnapshot(), _strElem);
    slices.sort(_stringsElem, _strElem, keys);
    final buf = BytesBuilder(copy: false);
    for (final k in keys.items) {
      final keyEscaped = queryEscape(k).toBytes();
      for (final v in this[k].items) {
        if (buf.length > 0) buf.addByte(0x26);
        buf
          ..add(keyEscaped)
          ..addByte(0x3d)
          ..add(queryEscape(v).toBytes());
      }
    }
    return Golang.String.fromBytes(buf.takeBytes());
  }
}

const _valuesMethods = ['Add', 'Del', 'Encode', 'Get', 'Has', 'Set'];

/// `*url.Values`: vista sobre qualquer ponteiro para o valor.
final class Values$Ptr extends PtrView<Values> {
  Values$Ptr(super.$p);

  /// `(*Values)(nil)` dentro de uma interface.
  static final Values$Ptr $nil = Values$Ptr(const NilPtr<Values>());

  @override
  String get $goType => '*url.Values';
  @override
  List<String> get $methods => _valuesMethods;

  Golang.String get(Golang.String p0) => $p.value.get(p0);
  void set(Golang.String p0, Golang.String p1) => $p.value.set(p0, p1);
  void add(Golang.String p0, Golang.String p1) => $p.value.add(p0, p1);
  void del(Golang.String p0) => $p.value.del(p0);
  bool has(Golang.String p0) => $p.value.has(p0);
  Golang.String encode() => $p.value.encode();
}

/// `ParseQuery(query)`: os pares da query; o primeiro erro volta junto com
/// tudo o que deu para analisar.
(Values, GoError?) parseQuery(Golang.String query) {
  final m = Values(GoMap(_stringsElem));
  final err = _parseQuery(m, query);
  return (m, err);
}

/// `urlmaxqueryparams` no padrão do Go 1.26.5 (sem GODEBUG): 10000.
const _defaultMaxParams = 10000;

GoError? _parseQuery(Values m, Golang.String query) {
  if (strings.count(query, _gs('&')).toInt() + 1 > _defaultMaxParams) {
    return _errNew('number of URL query parameters exceeded limit');
  }
  GoError? err;
  while (query.length != 0) {
    final (key0, rest, _) = strings.cut(query, _gs('&'));
    query = rest;
    if (strings.contains(key0, _gs(';'))) {
      err = fmt.errorf(
        _gs('invalid semicolon separator in query'),
        Slice.nil(_anyElem),
      );
      continue;
    }
    if (key0.length == 0) continue;
    final (k, v, _) = strings.cut(key0, _gs('='));
    final (key, err1) = queryUnescape(k);
    if (err1 != null) {
      err ??= err1;
      continue;
    }
    final (value, err2) = queryUnescape(v);
    if (err2 != null) {
      err ??= err2;
      continue;
    }
    m[key] = m[key].append([value]);
  }
  return err;
}
