part of '../../strings.dart';

const _builderByte = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

/// `strings.Builder`: struct de shim usada por valor no código gerado
/// (`go.GoStruct`: zero `Builder()`, cópia, `$set`). Porta de
/// `strings/builder.go` do Go 1.26: mesmo crescimento (`Cap`) e a checagem de
/// cópia (`addr`), com o pânico do Go.
final class Builder extends GoStruct<Builder>
    implements io.Writer, io.ByteWriter, io.StringWriter, Stringer {
  Builder();

  /// `(*Builder)(nil)` dentro de uma interface.
  static final Builder $nil = Builder()..$nilPtr = true;

  Builder? _addr;
  Slice<Golang.Uint8> _buf = Slice.nil(_builderByte);

  @override
  String get $goType => 'strings.Builder';

  @override
  List<String> get $ptrMethods => const [
    'Cap',
    'Grow',
    'Len',
    'Reset',
    'String',
    'Write',
    'WriteByte',
    'WriteRune',
    'WriteString',
  ];

  @override
  Builder $copy() => Builder()
    .._addr = _addr
    .._buf = _buf;

  @override
  void $set(Builder o) {
    _addr = o._addr;
    _buf = o._buf;
  }

  @override
  List<Object?> get $fields => [Addr(_addr), _buf];

  @override
  List<String> get $fieldNames => const ['addr', 'buf'];

  void _copyCheck() {
    if (_addr == null) {
      _addr = this;
    } else if (!identical(_addr, this)) {
      throw Panic(
        Golang.String.fromDart(
          'strings: illegal use of non-zero Builder copied by value',
        ),
      );
    }
  }

  /// `String()`.
  @override
  Golang.String string() => Golang.String.fromBytes(
    Uint8List.fromList([for (final b in _buf.items) b.toInt()]),
  );

  /// `Len()`.
  Golang.Int len() => Golang.Int(_buf.length);

  /// `Cap()`.
  Golang.Int cap() => Golang.Int(_buf.capacity);

  /// `Reset()`.
  void reset() {
    _addr = null;
    _buf = Slice.nil(_builderByte);
  }

  /// `Grow(n)`: cap `2*cap + n` arredondado à classe de tamanho do alocador
  /// (bytealg.MakeNoZero), como o Go.
  void grow(Golang.Int n) {
    _copyCheck();
    final k = n.toInt();
    if (k < 0) {
      throw Panic(
        Golang.String.fromDart('strings.Builder.Grow: negative count'),
      );
    }
    if (_buf.capacity - _buf.length < k) {
      final size = allocBytes(2 * _buf.capacity + k);
      final nb = Slice<Golang.Uint8>.make(
        size,
        size,
        _builderByte,
      ).slice(0, _buf.length);
      nb.copyFrom(_buf);
      _buf = nb;
    }
  }

  /// `Write(p)`.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) {
    _copyCheck();
    _buf = _buf.appendSlice(p);
    return (Golang.Int(p.length), null);
  }

  /// `WriteByte(c)`.
  @override
  GoError? writeByte(Golang.Uint8 c) {
    _copyCheck();
    _buf = _buf.append([c]);
    return null;
  }

  /// `WriteRune(r)`: UTF-8 do Go (runa inválida → U+FFFD).
  (Golang.Int, GoError?) writeRune(Golang.Rune r) {
    _copyCheck();
    final bytes = Golang.String.fromRune(r).toBytes();
    _buf = _buf.append([for (final b in bytes) Golang.Uint8(b)]);
    return (Golang.Int(bytes.length), null);
  }

  /// `WriteString(s)`.
  @override
  (Golang.Int, GoError?) writeString(Golang.String s) {
    _copyCheck();
    final bytes = s.toBytes();
    _buf = _buf.append([for (final b in bytes) Golang.Uint8(b)]);
    return (Golang.Int(bytes.length), null);
  }
}
