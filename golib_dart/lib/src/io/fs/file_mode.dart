part of '../../../io/fs.dart';

// Sem deslocar além de 30 bits (no JS `<<`/`&` são de 32 bits com sinal): o
// bit i de m é `(m ~/ 2^i) & 1` (`~/` e `&` com 1 valem nas três plataformas).
int _bit(int i) => i < 31 ? 1 << i : 2147483648;

bool _has(int m, int i) => (m ~/ _bit(i)) & 1 != 0;

const _typeBits = [31, 27, 26, 25, 24, 21, 19];

/// `os.FileMode` (`fs.FileMode`): `uint32` com os bits de permissão e tipo.
final class FileMode extends Golang.Uint32Base<FileMode> implements Stringer {
  FileMode([int v = 0]) : super(v);
  FileMode.from(Golang.IntBase v) : super.from(v);
  FileMode.fromBigInt(BigInt v) : super.fromBigInt(v);

  @override
  FileMode $make(int v) => FileMode(v);

  @override
  String get $goType => 'fs.FileMode';

  @override
  List<String> get $methods => const [
    'IsDir',
    'IsRegular',
    'Perm',
    'String',
    'Type',
  ];

  int get _m => toInt();

  /// `IsDir()`.
  bool isDir() => _has(_m, 31);

  /// `IsRegular()`.
  bool isRegular() => !_typeBits.any((i) => _has(_m, i));

  /// `Perm()`.
  FileMode perm() => FileMode(_m % 512);

  /// `Type()`.
  FileMode type() => FileMode(
    _typeBits.where((i) => _has(_m, i)).fold(0, (a, i) => a + _bit(i)),
  );

  /// `String()`: `drwxr-xr-x`, `-rw-r--r--`.
  @override
  Golang.String string() {
    const str = 'dalTLDpSugct?';
    final b = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (_has(_m, 31 - i)) b.write(str[i]);
    }
    if (b.isEmpty) b.write('-');
    const rwx = 'rwxrwxrwx';
    for (var i = 0; i < 9; i++) {
      b.write(_has(_m, 8 - i) ? rwx[i] : '-');
    }
    return Golang.String.fromDart(b.toString());
  }
}
