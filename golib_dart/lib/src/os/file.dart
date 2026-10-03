part of '../../os.dart';

/// `os.File` dos descritores padrão (0, 1, 2). Não abre arquivos: o sistema de
/// arquivos não está neste recorte.
final class File extends GoStruct<File>
    with io.WriterSync, io.StringWriterSync, io.CloserSync
    implements io.Writer, io.StringWriter, io.Closer {
  File._(this._fd, this._name);

  /// `(*File)(nil)` dentro de uma interface.
  static final File $nil = File._(-1, '')..$nilPtr = true;

  final int _fd;
  final String _name;
  bool _closed = false;

  @override
  String get $goType => 'os.File';
  @override
  List<String> get $ptrMethods => const [
    'Close',
    'Fd',
    'Name',
    'Write',
    'WriteString',
  ];
  @override
  File $copy() => this;
  @override
  void $set(File o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  GoError _path(String op, GoError e) =>
      fs.PathError(op: Golang.String.fromDart(op), path: name(), err: e);

  /// `Name()`.
  Golang.String name() => Golang.String.fromDart(_name);

  /// `Fd()`.
  Golang.Uintptr fd() => Golang.Uintptr(_fd);

  /// `Close()`: o segundo `Close` devolve `ErrClosed`.
  @override
  GoError? close() {
    if (_closed) return _path('close', errClosed);
    _closed = true;
    return null;
  }

  (Golang.Int, GoError?) _write(List<int> b) {
    if (_closed) return (Golang.Int(0), _path('write', errClosed));
    if (_fd == 0) {
      return (
        Golang.Int(0),
        _path(
          'write',
          ErrorString(Golang.String.fromDart('bad file descriptor')),
        ),
      );
    }
    if (_fd == 2) {
      out.writeStderrBytes(b);
    } else {
      out.writeStdout(b);
    }
    return (Golang.Int(b.length), null);
  }

  /// `Write(b)`.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> b) =>
      _write([for (final x in b.items) x.toInt()]);

  /// `WriteString(s)`.
  @override
  (Golang.Int, GoError?) writeString(Golang.String s) => _write(s.toBytes());
}

/// `os.Stdin`.
final File stdin = File._(0, '/dev/stdin');

/// `os.Stdout`.
final File stdout = File._(1, '/dev/stdout');

/// `os.Stderr`.
final File stderr = File._(2, '/dev/stderr');
