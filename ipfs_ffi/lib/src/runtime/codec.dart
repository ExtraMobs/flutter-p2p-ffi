part of '../runtime.dart';

// A codificação dos valores do WIRE.md: tudo little-endian; string = u32 n +
// UTF-8; bytes = i32 n + bytes (-1 = nil); presença = u8 (0/1).

/// Escritor dos argumentos de um pedido; cresce sozinho. Os métodos seguem os
/// kinds do gerador e são usados em cascata pelo código gerado
/// (`$W()..h(this)..str(nome)`).
final class $W {
  var _b = Uint8List(64);
  late var _d = ByteData.sublistView(_b);
  var _n = 0;

  /// Handles escritos: ficam vivos enquanto a chamada está pendente.
  final _keep = <Object>[];

  /// Sinks das opções (id, sink), registrados pelo runtime ao enviar.
  final _sinks = <(int, GoSink<Object?>)>[];

  /// Erro adiado (handle de um serviço anterior, argumento que não
  /// atravessa): a chamada falha com ele, pelo Future/Stream quando é
  /// assíncrona.
  Object? _error;

  void _check() {
    if (_error case final e?) throw e;
  }

  void _grow(int k) {
    if (_n + k <= _b.length) return;
    var cap = _b.length * 2;
    while (cap < _n + k) {
      cap *= 2;
    }
    _b = Uint8List(cap)..setRange(0, _n, _b);
    _d = ByteData.sublistView(_b);
  }

  void _raw(List<int> v) {
    _grow(v.length);
    _b.setRange(_n, _n + v.length, v);
    _n += v.length;
  }

  /// Os bytes escritos.
  Uint8List take() => Uint8List.sublistView(_b, 0, _n);

  void u8(int v) {
    _grow(1);
    _b[_n++] = v;
  }

  void u32(int v) {
    _grow(4);
    _d.setUint32(_n, v, Endian.little);
    _n += 4;
  }

  void i32(int v) {
    _grow(4);
    _d.setInt32(_n, v, Endian.little);
    _n += 4;
  }

  /// Também o `u64` (os mesmos 8 bytes): o Dart guarda 64 bits com sinal.
  void i64(int v) {
    _grow(8);
    _d.setInt64(_n, v, Endian.little);
    _n += 8;
  }

  void f64(double v) {
    _grow(8);
    _d.setFloat64(_n, v, Endian.little);
    _n += 8;
  }

  void b(bool v) => u8(v ? 1 : 0);

  void str(String s) {
    final e = utf8.encode(s);
    u32(e.length);
    _raw(e);
  }

  /// `[]byte`: null é o nil do Go.
  void bytes(Uint8List? v) {
    if (v == null) return i32(-1);
    i32(v.length);
    _raw(v);
  }

  /// Handle (`kHandle`, `kCtx`): 0 = nil.
  void h(GoHandle? x) {
    if (x == null) return i64(0);
    if (x.$e != _epoch) {
      _error ??= IpfsServiceException(
          'handle de um serviço anterior: o ipfs_host foi reiniciado');
    }
    _keep.add(x);
    i64(x.$h);
  }

  /// Tipo-valor (CID, path, peer ID, multiaddr, ipns.Name).
  void val(GoValue? v) {
    if (v == null) return u8(0);
    u8(1);
    str(v.value);
  }

  /// `time.Time`: Unix em nanossegundos.
  void time(DateTime? t) {
    if (t == null) return u8(0);
    u8(1);
    i64(t.microsecondsSinceEpoch * 1000);
  }

  /// `config.Config`: o JSON do próprio kubo.
  void json(GoJsonValue? c) {
    if (c == null) return u8(0);
    u8(1);
    jsonStr(c.json);
  }

  /// Um objeto JSON como string.
  void jsonStr(Map<String, Object?> m) => str(jsonEncode(m));

  void dto(GoDto? d) {
    if (d == null) return u8(0);
    u8(1);
    d.$enc(this);
  }

  /// Erro dentro de um valor (`kError`): a mensagem; null = sem erro.
  void err(String? e) {
    if (e == null) return u8(0);
    u8(1);
    str(e);
  }

  /// Opção funcional: índice do construtor + os parâmetros dele.
  void opt(GoOption o) {
    u32(o.$i);
    o.$a(this);
  }

  /// `io.Reader` em parâmetro: os bytes (`u8 0`) ou um handle de leitor (`u8 1`).
  void reader(Object r) {
    switch (r) {
      case Uint8List():
        u8(0);
        bytes(r);
      case GoHandle():
        u8(1);
        h(r);
      default:
        _error ??= ArgumentError.value(
            r, 'r', 'io.Reader: passe Uint8List ou um handle de leitor');
        u8(0);
        bytes(null);
    }
  }

  /// `chan<- T` de uma opção: o id do sink, que recebe os `item`s da chamada.
  void sink(GoSink<Object?> s) {
    var id = 0;
    try {
      id = _channel.newId();
      _sinks.add((id, s));
    } on IpfsServiceException catch (e) {
      _error ??= e;
    }
    u32(id);
  }

  /// `kSlice`: `i32 n` + elementos; null = nil.
  void list<T>(List<T>? xs, void Function($W w, T e) f) {
    if (xs == null) return i32(-1);
    i32(xs.length);
    for (final e in xs) {
      f(this, e);
    }
  }

  /// `kMap`: `i32 n` + pares (chave sem byte de presença).
  void map<K, V>(
      Map<K, V> m, void Function($W w, K k) key, void Function($W w, V v) val) {
    i32(m.length);
    for (final e in m.entries) {
      key(this, e.key);
      val(this, e.value);
    }
  }
}

/// Leitor de uma resposta (ou de um item de stream/sink).
final class $R {
  $R(this._b) : _d = ByteData.sublistView(_b);

  final Uint8List _b;
  final ByteData _d;
  var _i = 0;

  int u8() => _b[_i++];

  int u32() {
    final v = _d.getUint32(_i, Endian.little);
    _i += 4;
    return v;
  }

  int i32() {
    final v = _d.getInt32(_i, Endian.little);
    _i += 4;
    return v;
  }

  int i64() {
    final v = _d.getInt64(_i, Endian.little);
    _i += 8;
    return v;
  }

  double f64() {
    final v = _d.getFloat64(_i, Endian.little);
    _i += 8;
    return v;
  }

  bool b() => u8() != 0;

  /// Byte de presença: false = nil do Go.
  bool p() => u8() != 0;

  String str() {
    final n = u32();
    final s = utf8.decode(Uint8List.sublistView(_b, _i, _i + n));
    _i += n;
    return s;
  }

  /// `[]byte`; null = nil.
  Uint8List? bytes() {
    final n = i32();
    if (n < 0) return null;
    final v = Uint8List.sublistView(_b, _i, _i + n);
    _i += n;
    return v;
  }

  /// Handle que pode ser nil (0): null, ou o objeto criado por [f].
  T? hn<T>(T Function(int h) f) {
    final h = i64();
    return h == 0 ? null : f(h);
  }

  /// Handle não nulo: nil do Go vira IpfsException.
  T hnn<T>(T Function(int h) f) {
    final h = i64();
    return h == 0 ? $nil() : f(h);
  }

  /// `time.Time` (sem a presença): Unix em nanossegundos, em UTC.
  DateTime time() =>
      DateTime.fromMicrosecondsSinceEpoch(i64() ~/ 1000, isUtc: true);

  /// Um objeto JSON vindo como string (`config.Config`, sem a presença).
  Map<String, Object?> json() => jsonDecode(str()) as Map<String, Object?>;

  /// `kError`: a mensagem, ou null.
  String? err() => p() ? str() : null;

  /// `kSlice`: nil vira lista vazia.
  List<T> list<T>(T Function() f) {
    final n = i32();
    return [for (var k = 0; k < n; k++) f()];
  }

  /// `kMap`: a chave é lida antes do valor.
  Map<K, V> map<K, V>(K Function() key, V Function() val) {
    final n = i32();
    return {for (var k = 0; k < n; k++) key(): val()};
  }
}
