part of '../../../encoding/json.dart';

// `stream.go`: `Encoder` e `Decoder` sobre `io.Writer`/`io.Reader`.
//
// Versão dupla (D2): `NewEncoder`/`NewDecoder` só guardam a interface
// (`WRAPPING_SHIM_CALLS`); os métodos são de tipo concreto do shim, então
// síncronos (chamam `write`/`read`). ⚠️ Sobre um escritor/leitor que
// suspende de fato, a forma síncrona dele cai no `fatal` `g2d:` do
// `go.syncOfAsync` (nunca num resultado errado).

/// `json.NewEncoder(w)`.
Encoder? newEncoder(io.Writer? w) => Encoder._(w);

/// `*json.Encoder`.
final class Encoder extends GoStruct<Encoder> {
  Encoder() : _w = null;
  Encoder._(this._w);

  static final Encoder $nil = Encoder()..$nilPtr = true;

  io.Writer? _w;
  GoError? _err;
  bool _escapeHTML = true;
  List<int> _indentPrefix = const [];
  List<int> _indentValue = const [];

  @override
  String get $goType => 'json.Encoder';

  @override
  List<String> get $ptrMethods => const [
    'Encode',
    'SetEscapeHTML',
    'SetIndent',
  ];

  @override
  Encoder $copy() => Encoder._(_w)
    .._err = _err
    .._escapeHTML = _escapeHTML
    .._indentPrefix = _indentPrefix
    .._indentValue = _indentValue;

  @override
  void $set(Encoder o) {
    _w = o._w;
    _err = o._err;
    _escapeHTML = o._escapeHTML;
    _indentPrefix = o._indentPrefix;
    _indentValue = o._indentValue;
  }

  @override
  List<Object?> get $fields => [_w, _err, _escapeHTML];

  @override
  List<String> get $fieldNames => const ['w', 'err', 'escapeHTML'];

  /// `Encode(v)`: o JSON de v e um `\n`, numa só chamada a `Write`.
  GoError? encode(Object? v) {
    if (_err != null) return _err;
    final e = _EncodeState();
    final err = e.marshal(v, _escapeHTML ? _optEscapeHTML : 0);
    if (err != null) return err;
    e.writeByte(0x0a);
    var b = e.buf;
    if (_indentPrefix.isNotEmpty || _indentValue.isNotEmpty) {
      final ib = <int>[];
      final err2 = _appendIndent(ib, b, _indentPrefix, _indentValue);
      if (err2 != null) return err2;
      b = ib;
    }
    final (_, werr) = _w!.write(_out(b));
    if (werr != null) _err = werr;
    return werr;
  }

  /// `SetIndent(prefix, indent)`.
  void setIndent(Golang.String prefix, Golang.String indent) {
    _indentPrefix = prefix.toBytes();
    _indentValue = indent.toBytes();
  }

  /// `SetEscapeHTML(on)`.
  void setEscapeHTML(bool on) => _escapeHTML = on;
}

/// `json.NewDecoder(r)`.
Decoder? newDecoder(io.Reader? r) => Decoder._(r);

const _tokenTopValue = 0,
    _tokenArrayStart = 1,
    _tokenArrayValue = 2,
    _tokenArrayComma = 3,
    _tokenObjectStart = 4,
    _tokenObjectKey = 5,
    _tokenObjectColon = 6,
    _tokenObjectValue = 7,
    _tokenObjectComma = 8;

/// `*json.Decoder`: lê valores JSON em sequência de um `io.Reader`.
final class Decoder extends GoStruct<Decoder> {
  Decoder() : _r = null;
  Decoder._(this._r);

  static final Decoder $nil = Decoder()..$nilPtr = true;

  io.Reader? _r;

  /// `buf` (o mesmo crescimento do Go: o `Read` vê os mesmos tamanhos).
  _Bytes _buf = _nilBytes();
  final _DecodeState _d = _DecodeState();
  int _scanp = 0;
  int _scanned = 0;
  final _Scanner _scan = _Scanner();
  GoError? _err;
  int _tokenState = _tokenTopValue;
  final List<int> _tokenStack = [];

  @override
  String get $goType => 'json.Decoder';

  @override
  List<String> get $ptrMethods => const [
    'Buffered',
    'Decode',
    'DisallowUnknownFields',
    'InputOffset',
    'More',
    'Token',
    'UseNumber',
  ];

  @override
  Decoder $copy() =>
      throw Panic(_gs('json: cópia de json.Decoder não suportada'));

  @override
  void $set(Decoder o) =>
      throw Panic(_gs('json: cópia de json.Decoder não suportada'));

  @override
  List<Object?> get $fields => [_r, _scanp, _scanned, _err];

  @override
  List<String> get $fieldNames => const ['r', 'scanp', 'scanned', 'err'];

  /// `UseNumber()`: números em `any` viram `Number`.
  void useNumber() => _d.useNumber = true;

  /// `DisallowUnknownFields()`.
  void disallowUnknownFields() => _d.disallowUnknownFields = true;

  /// `Decode(v)`: o próximo valor JSON em v.
  GoError? decode(Object? v) {
    if (_err != null) return _err;
    final perr = this._tokenPrepareForDecode();
    if (perr != null) return perr;
    if (!this._tokenValueAllowed()) {
      return SyntaxError._('not at beginning of value', inputOffset().toInt());
    }
    final (n, err) = _readValue();
    if (err != null) return err;
    final win = _buf.slice(_scanp, _scanp + n);
    _d.init(_in(win), win);
    _scanp += n;
    final uerr = _d.unmarshal(v);
    this._tokenValueEnd();
    return uerr;
  }

  /// `Buffered()`: o que já foi lido e ainda não decodificado.
  io.Reader? buffered() => bytes.newReader(_buf.slice(_scanp));

  int _b(int i) => _buf[i].toInt();

  /// `readValue`: lê até o fim do próximo valor; devolve o tamanho.
  (int, GoError?) _readValue() {
    _scan.reset();
    var scanp = _scanp;
    GoError? err;
    input:
    while (scanp >= 0) {
      for (; scanp < _buf.length; scanp++) {
        final c = _b(scanp);
        _scan.bytes++;
        switch (_scan.step(_scan, c)) {
          case _scanEnd:
            _scan.bytes--;
            break input;
          case _scanEndObject || _scanEndArray:
            if (_stateEndValue(_scan, 0x20) == _scanEnd) {
              scanp++;
              break input;
            }
          case _scanError:
            _err = _scan.err;
            return (0, _scan.err);
        }
      }
      if (err != null) {
        if (identical(err, io.eof)) {
          if (_scan.step(_scan, 0x20) == _scanEnd) break input;
          if (_nonSpace(_buf)) err = io.errUnexpectedEOF;
        }
        _err = err;
        return (0, err);
      }
      final n = scanp - _scanp;
      err = _refill();
      scanp = _scanp + n;
    }
    return (scanp - _scanp, null);
  }

  /// `refill`: compacta o buffer e lê mais (pelo menos 512 bytes de espaço).
  GoError? _refill() {
    if (_scanp > 0) {
      _scanned += _scanp;
      final n = _buf.copyFrom(_buf.slice(_scanp));
      _buf = _buf.slice(0, n);
      _scanp = 0;
    }
    const minRead = 512;
    if (_buf.capacity - _buf.length < minRead) {
      final nb = Slice<Golang.Uint8>.make(
        _buf.length,
        2 * _buf.capacity + minRead,
        _byteElem,
      );
      nb.copyFrom(_buf);
      _buf = nb;
    }
    final (n, err) = _r!.read(_buf.slice(_buf.length, _buf.capacity));
    _buf = _buf.slice(0, _buf.length + n.toInt());
    return err;
  }

  /// `InputOffset()`.
  Golang.Int64 inputOffset() => Golang.Int64(_scanned + _scanp);
}

bool _nonSpace(_Bytes b) {
  for (var i = 0; i < b.length; i++) {
    if (!_isSpace(b[i].toInt())) return true;
  }
  return false;
}
