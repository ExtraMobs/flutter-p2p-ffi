part of '../runtime.dart';

// The value encoding of WIRE.md: everything little-endian; string = u32 n +
// UTF-8; bytes = i32 n + bytes (-1 = nil); presence = u8 (0/1).

/// Writer of a request's arguments; grows on its own. The methods follow the
/// generator's kinds and are used in cascade by the generated code
/// (`$W()..h(this)..str(name)`).
final class $W {
  var _b = Uint8List(64);
  late var _d = ByteData.sublistView(_b);
  var _n = 0;

  /// Written handles: kept alive while the call is pending.
  final _keep = <Object>[];

  /// Option sinks (id, sink), registered by the runtime when sending.
  final _sinks = <(int, GoSink<Object?>)>[];

  /// Deferred error (handle from a previous service, argument that does not
  /// cross): the call fails with it, through the Future/Stream when it is
  /// asynchronous.
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

  /// The written bytes.
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

  /// Also the `u64` (the same 8 bytes): Dart stores 64 bits as signed.
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

  /// `[]byte`: null is Go's nil.
  void bytes(Uint8List? v) {
    if (v == null) return i32(-1);
    i32(v.length);
    _raw(v);
  }

  /// Handle (`kHandle`, `kCtx`): 0 = nil.
  void h(GoHandle? x) {
    if (x == null) return i64(0);
    if (x.isReleased) {
      _error ??= IpfsException(
          'handle already released: cannot use a released handle');
    }
    if (x.$e != _epoch) {
      _error ??= IpfsServiceException(
          'handle from a previous service: the ipfs_host was restarted');
    }
    _keep.add(x);
    i64(x.$h);
  }

  /// Value type (CID, path, peer ID, multiaddr, ipns.Name).
  void val(GoValue? v) {
    if (v == null) return u8(0);
    u8(1);
    str(v.value);
  }

  /// `time.Time`: Unix time in nanoseconds.
  void time(DateTime? t) {
    if (t == null) return u8(0);
    u8(1);
    i64(t.microsecondsSinceEpoch * 1000);
  }

  /// `config.Config`: kubo's own JSON.
  void json(GoJsonValue? c) {
    if (c == null) return u8(0);
    u8(1);
    jsonStr(c.json);
  }

  /// A JSON object as a string.
  void jsonStr(Map<String, Object?> m) => str(jsonEncode(m));

  /// `*T` of a basic type (`*int64`): presence + the value; null = nil.
  void ptr<T extends Object>(T? x, void Function($W w, T v) f) {
    if (x == null) return u8(0);
    u8(1);
    f(this, x);
  }

  void dto(GoDto? d) {
    if (d == null) return u8(0);
    u8(1);
    d.$enc(this);
  }

  /// Error inside a value (`kError`): the message; null = no error.
  void err(String? e) {
    if (e == null) return u8(0);
    u8(1);
    str(e);
  }

  /// Functional option: constructor index + its parameters.
  void opt(GoOption o) {
    u32(o.$i);
    o.$a(this);
  }

  /// `io.Reader` parameter: the bytes (`u8 0`) or a reader handle (`u8 1`).
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
            r, 'r', 'io.Reader: pass a Uint8List or a reader handle');
        u8(0);
        bytes(null);
    }
  }

  /// `chan<- T` of an option: the sink id, which receives the call's `item`s.
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

  /// `kSlice`: `i32 n` + elements; null = nil.
  void list<T>(List<T>? xs, void Function($W w, T e) f) {
    if (xs == null) return i32(-1);
    i32(xs.length);
    for (final e in xs) {
      f(this, e);
    }
  }

  /// `kAny`, Go's `any` (WIRE.md, "Value encoding"): `u8` tag + value. Maps
  /// go with string keys; [DateTime] as ISO 8601 and a [GoValue] as its
  /// string, like the Go side writes them.
  void any(Object? v) {
    switch (v) {
      case null:
        u8(0);
      case bool b:
        u8(1);
        this.b(b);
      case int i:
        u8(2);
        i64(i);
      case double d:
        u8(3);
        f64(d);
      case String s:
        u8(4);
        str(s);
      case Uint8List bs:
        u8(5);
        bytes(bs);
      case List<Object?> xs:
        u8(6);
        i32(xs.length);
        xs.forEach(any);
      case Map<Object?, Object?> m:
        u8(7);
        i32(m.length);
        for (final e in m.entries) {
          str('${e.key}');
          any(e.value);
        }
      case DateTime t:
        u8(4);
        str(t.toUtc().toIso8601String());
      case GoValue g:
        u8(4);
        str(g.value);
      default:
        throw ArgumentError.value(
            v,
            'v',
            'not a dynamic value (null, bool, '
                'int, double, String, Uint8List, List, Map, DateTime, GoValue)');
    }
  }

  /// `kMap`: `i32 n` + pairs (key without a presence byte).
  void map<K, V>(
      Map<K, V> m, void Function($W w, K k) key, void Function($W w, V v) val) {
    i32(m.length);
    for (final e in m.entries) {
      key(this, e.key);
      val(this, e.value);
    }
  }
}

/// Reader of a response (or of a stream/sink item).
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

  /// Presence byte: false = Go's nil.
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

  /// Handle that may be nil (0): null, or the object created by [f].
  T? hn<T>(T Function(int h) f) {
    final h = i64();
    return h == 0 ? null : f(h);
  }

  /// Non-null handle: a Go nil becomes an IpfsException.
  T hnn<T>(T Function(int h) f) {
    final h = i64();
    return h == 0 ? $nil() : f(h);
  }

  /// `time.Time` (without presence): Unix time in nanoseconds, in UTC.
  DateTime time() =>
      DateTime.fromMicrosecondsSinceEpoch(i64() ~/ 1000, isUtc: true);

  /// A JSON object sent as a string (`config.Config`, without presence).
  Map<String, Object?> json() => jsonDecode(str()) as Map<String, Object?>;

  /// `kError`: the message, or null.
  String? err() => p() ? str() : null;

  /// `kSlice`: nil becomes an empty list.
  List<T> list<T>(T Function() f) {
    final n = i32();
    return [for (var k = 0; k < n; k++) f()];
  }

  /// `kMap`: the key is read before the value.
  Map<K, V> map<K, V>(K Function() key, V Function() val) {
    final n = i32();
    return {for (var k = 0; k < n; k++) key(): val()};
  }

  /// `kAny`: null, bool, int, double, String, Uint8List, `List<Object?>` or
  /// `Map<String, Object?>` (the Go side's `any`, WIRE.md).
  Object? any() {
    switch (u8()) {
      case 0:
        return null;
      case 1:
        return b();
      case 2:
        return i64();
      case 3:
        return f64();
      case 4:
        return str();
      case 5:
        return bytes();
      case 6:
        final n = i32();
        return [for (var k = 0; k < n; k++) any()];
      case 7:
        final n = i32();
        return {for (var k = 0; k < n; k++) str(): any()};
      case final t:
        throw IpfsException('unknown dynamic value tag $t');
    }
  }
}
