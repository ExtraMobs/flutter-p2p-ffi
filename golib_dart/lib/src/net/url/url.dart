part of '../../../net/url.dart';

/// `url.URL`: URL já analisada.
final class URL extends GoStruct<URL> implements fmt.Stringer, Golang.GoTyped {
  URL({
    Golang.String? scheme,
    Golang.String? opaque,
    this.user,
    Golang.String? host,
    Golang.String? path,
    Golang.String? fragment,
    Golang.String? rawQuery,
    Golang.String? rawPath,
    Golang.String? rawFragment,
    bool? forceQuery,
    bool? omitHost,
  }) : scheme = scheme ?? Golang.String(),
       opaque = opaque ?? Golang.String(),
       host = host ?? Golang.String(),
       path = path ?? Golang.String(),
       fragment = fragment ?? Golang.String(),
       rawQuery = rawQuery ?? Golang.String(),
       rawPath = rawPath ?? Golang.String(),
       rawFragment = rawFragment ?? Golang.String(),
       forceQuery = forceQuery ?? false,
       omitHost = omitHost ?? false;

  /// `(*URL)(nil)` dentro de uma interface ou como receptor.
  static final URL $nil = URL()..$nilPtr = true;

  Golang.String scheme;
  Golang.String opaque;
  Userinfo? user;
  Golang.String host;
  Golang.String path;
  Golang.String fragment;
  Golang.String rawQuery;
  Golang.String rawPath;
  Golang.String rawFragment;
  bool forceQuery;
  bool omitHost;

  @override
  String get $goType => 'url.URL';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const [
    'AppendBinary',
    'EscapedFragment',
    'EscapedPath',
    'Hostname',
    'IsAbs',
    'JoinPath',
    'MarshalBinary',
    'Parse',
    'Port',
    'Query',
    'Redacted',
    'RequestURI',
    'ResolveReference',
    'String',
    'UnmarshalBinary',
  ];
  @override
  URL $copy() => URL(
    scheme: scheme,
    opaque: opaque,
    user: user,
    host: host,
    path: path,
    fragment: fragment,
    rawQuery: rawQuery,
    rawPath: rawPath,
    rawFragment: rawFragment,
    forceQuery: forceQuery,
    omitHost: omitHost,
  );
  @override
  void $set(URL o) {
    scheme = o.scheme;
    opaque = o.opaque;
    user = o.user;
    host = o.host;
    path = o.path;
    fragment = o.fragment;
    rawQuery = o.rawQuery;
    rawPath = o.rawPath;
    rawFragment = o.rawFragment;
    forceQuery = o.forceQuery;
    omitHost = o.omitHost;
  }

  @override
  List<Object?> get $fields => [
    scheme,
    opaque,
    Addr(user),
    host,
    path,
    fragment,
    rawQuery,
    rawPath,
    rawFragment,
    forceQuery,
    omitHost,
  ];
  @override
  List<String> get $fieldNames => const [
    'Scheme',
    'Opaque',
    'User',
    'Host',
    'Path',
    'Fragment',
    'RawQuery',
    'RawPath',
    'RawFragment',
    'ForceQuery',
    'OmitHost',
  ];
  @override
  List<String> get $fieldTypes => const [
    'string',
    'string',
    '*url.Userinfo',
    'string',
    'string',
    'string',
    'string',
    'string',
    'string',
    'bool',
    'bool',
  ];

  URL get _self {
    if ($nilPtr) nilDeref();
    return this;
  }

  /// `setPath(p)`: Path decodificado e RawPath só se o escape padrão
  /// não reproduz p.
  GoError? _setPath(Golang.String p) {
    final (path, err) = _unescape(p, _encodePath);
    if (err != null) return err;
    this.path = path;
    rawPath = p == _escape(path, _encodePath) ? Golang.String() : p;
    return null;
  }

  /// `EscapedPath()`: RawPath se ele é um escape válido de Path.
  Golang.String escapedPath() {
    final u = _self;
    if (u.rawPath.length != 0 && _validEncoded(u.rawPath, _encodePath)) {
      final (p, err) = _unescape(u.rawPath, _encodePath);
      if (err == null && p == u.path) return u.rawPath;
    }
    if (u.path == _gs('*')) return _gs('*');
    return _escape(u.path, _encodePath);
  }

  GoError? _setFragment(Golang.String f) {
    final (frag, err) = _unescape(f, _encodeFragment);
    if (err != null) return err;
    fragment = frag;
    rawFragment = f == _escape(frag, _encodeFragment) ? Golang.String() : f;
    return null;
  }

  /// `EscapedFragment()`.
  Golang.String escapedFragment() {
    final u = _self;
    if (u.rawFragment.length != 0 &&
        _validEncoded(u.rawFragment, _encodeFragment)) {
      final (f, err) = _unescape(u.rawFragment, _encodeFragment);
      if (err == null && f == u.fragment) return u.rawFragment;
    }
    return _escape(u.fragment, _encodeFragment);
  }

  /// `String()`: a URL remontada (`scheme:opaque?query#fragment` ou
  /// `scheme://userinfo@host/path?query#fragment`).
  @override
  Golang.String string() {
    final u = _self;
    final buf = BytesBuilder(copy: false);
    void ws(Golang.String s) => buf.add(s.toBytes());
    if (u.scheme.length != 0) {
      ws(u.scheme);
      buf.addByte(0x3a);
    }
    if (u.opaque.length != 0) {
      ws(u.opaque);
    } else {
      if (u.scheme.length != 0 || u.host.length != 0 || u.user != null) {
        if (u.omitHost && u.host.length == 0 && u.user == null) {
          // sem `//`
        } else {
          if (u.host.length != 0 || u.path.length != 0 || u.user != null) {
            ws(_gs('//'));
          }
          final ui = u.user;
          if (ui != null) {
            ws(ui.string());
            buf.addByte(0x40);
          }
          if (u.host.length != 0) ws(_escape(u.host, _encodeHost));
        }
      }
      final path = u.escapedPath();
      if (path.length != 0 && path[0] != 0x2f && u.host.length != 0) {
        buf.addByte(0x2f);
      }
      if (buf.length == 0) {
        // `./` antes de um primeiro segmento com `:` (não é esquema).
        final (segment, _, _) = strings.cut(path, _gs('/'));
        if (strings.contains(segment, _gs(':'))) ws(_gs('./'));
      }
      ws(path);
    }
    if (u.forceQuery || u.rawQuery.length != 0) {
      buf.addByte(0x3f);
      ws(u.rawQuery);
    }
    if (u.fragment.length != 0) {
      buf.addByte(0x23);
      ws(u.escapedFragment());
    }
    return Golang.String.fromBytes(buf.takeBytes());
  }

  /// `Redacted()`: [string] com a senha trocada por `xxxxx`; "" no nil.
  Golang.String redacted() {
    if ($nilPtr) return Golang.String();
    final ru = $copy();
    final (_, has) = (ru.user ?? Userinfo.$nil).password();
    if (has) {
      ru.user = userPassword(ru.user!.username(), _gs('xxxxx'));
    }
    return ru.string();
  }

  /// `IsAbs()`: tem esquema.
  bool isAbs() => _self.scheme.length != 0;

  /// `Parse(ref)`: ref analisada no contexto de u.
  (URL?, GoError?) parse(Golang.String ref) {
    final u = _self;
    final (refURL, err) = _parseURL(ref);
    if (err != null) return (null, err);
    return (u.resolveReference(refURL), null);
  }

  /// `ResolveReference(ref)`: RFC 3986 § 5.2.
  URL resolveReference(URL? ref$) {
    final u = _self;
    final ref = ref$ ?? URL.$nil;
    final url = ref._self.$copy();
    if (ref.scheme.length == 0) url.scheme = u.scheme;
    if (ref.scheme.length != 0 || ref.host.length != 0 || ref.user != null) {
      url._setPath(_resolvePath(ref.escapedPath(), Golang.String()));
      return url;
    }
    if (ref.opaque.length != 0) {
      url.user = null;
      url.host = Golang.String();
      url.path = Golang.String();
      return url;
    }
    if (ref.path.length == 0 && !ref.forceQuery && ref.rawQuery.length == 0) {
      url.rawQuery = u.rawQuery;
      if (ref.fragment.length == 0) {
        url.fragment = u.fragment;
        url.rawFragment = u.rawFragment;
      }
    }
    if (ref.path.length == 0 && u.opaque.length != 0) {
      url.opaque = u.opaque;
      url.user = null;
      url.host = Golang.String();
      url.path = Golang.String();
      return url;
    }
    url.host = u.host;
    url.user = u.user;
    url._setPath(_resolvePath(u.escapedPath(), ref.escapedPath()));
    return url;
  }

  /// `Query()`: RawQuery analisada (erros descartados).
  Values query() => parseQuery(_self.rawQuery).$1;

  /// `RequestURI()`: `path?query` (ou `opaque?query`) para uma requisição.
  Golang.String requestURI() {
    final u = _self;
    var result = u.opaque;
    if (result.length == 0) {
      result = u.escapedPath();
      if (result.length == 0) result = _gs('/');
    } else if (strings.hasPrefix(result, _gs('//'))) {
      result = u.scheme + _gs(':') + result;
    }
    if (u.forceQuery || u.rawQuery.length != 0) {
      result += _gs('?') + u.rawQuery;
    }
    return result;
  }

  /// `Hostname()`: Host sem porta e sem colchetes.
  Golang.String hostname() => _splitHostPort(_self.host).$1;

  /// `Port()`: a porta de Host, ou "".
  Golang.String port() => _splitHostPort(_self.host).$2;

  /// `MarshalBinary()`.
  (Slice<Golang.Uint8>, GoError?) marshalBinary() =>
      appendBinary(Slice.nil(_byteElem));

  /// `AppendBinary(b)`.
  (Slice<Golang.Uint8>, GoError?) appendBinary(Slice<Golang.Uint8> b) =>
      (b.appendSlice(bytesOf(string(), _byteElem)), null);

  /// `UnmarshalBinary(text)`.
  GoError? unmarshalBinary(Slice<Golang.Uint8> text) {
    final u = _self;
    final (u1, err) = _parseURL(
      Golang.String.fromBytes(
        Uint8List.fromList([for (final b in text.items) b.toInt()]),
      ),
    );
    if (err != null) return err;
    u.$set(u1!);
    return null;
  }

  /// `JoinPath(elem...)`: os elementos juntados ao caminho e limpos.
  URL joinPath(Slice<Golang.String> elem) => _joinPath(elem).$1;

  (URL, GoError?) _joinPath(Slice<Golang.String> elem) {
    final u = _self;
    final all = [u.escapedPath(), ...elem.items];
    Golang.String p;
    if (!strings.hasPrefix(all[0], _gs('/'))) {
      all[0] = _gs('/') + all[0];
      p = pathpkg.join(Slice.of(all, _strElem)).slice(1);
    } else {
      p = pathpkg.join(Slice.of(all, _strElem));
    }
    if (strings.hasSuffix(all.last, _gs('/')) &&
        !strings.hasSuffix(p, _gs('/'))) {
      p += _gs('/');
    }
    final url = u.$copy();
    final err = url._setPath(p);
    return (url, err);
  }
}
