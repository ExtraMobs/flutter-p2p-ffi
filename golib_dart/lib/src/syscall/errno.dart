part of '../../syscall.dart';

// `syscall.Errno` (porta de `syscall_unix.go` do Go 1.26.5).

/// `syscall.Errno`: tipo nomeado sobre `uintptr`, na forma que o g2d gera
/// para um nomeado sobre básico (classe sobre `Uint64Base`: `Errno(11)`,
/// `Errno.from`, operadores, igualdade por valor dentro de interface).
///
/// Satisfaz `net.Error` (`Timeout`/`Temporary`) como no Go; a interface
/// mora no runtime ([NetError]) para o `syscall` não importar o `net`.
final class Errno extends Golang.Uint64Base<Errno>
    implements NetError, ErrorIs, Typed {
  Errno([int v = 0]) : super(v);
  Errno.from(Golang.IntBase v) : super.from(v);
  Errno.fromBigInt(BigInt v) : super.fromBigInt(v);
  const Errno._(super.$hi, super.$lo) : super.raw();

  @override
  Errno $make(int hi, int lo) => Errno._(hi, lo);

  @override
  String get $goType => 'syscall.Errno';

  @override
  List<String> get $methods => _errnoMethods;

  /// Descritor de reflexão (`SHIM_RTYPES`).
  static final RType<Errno> $rt = rtNamed<Errno>(
    'syscall',
    'Errno',
    'syscall.Errno',
    () => rtUintptr,
    kind: kUintptr,
    size: 8,
    align: 8,
    zero: Errno.new,
    conv: (v) => Errno.from(v as Golang.IntBase),
    methods: _errnoMethods,
    ptrMethods: _errnoMethods,
  );

  @override
  RType get $rtype => $rt;

  /// `Error()`: o texto da tabela do linux, ou `errno N`.
  @override
  Golang.String error() {
    // `0 <= int(e) && int(e) < len(errors)`: int(e) é negativo acima de
    // 2^63 (a parte alta com o bit de sinal).
    if ($hi == 0 && $lo < errnoTexts.length) {
      final s = errnoTexts[$lo];
      if (s.isNotEmpty) return Golang.String.fromDart(s);
    }
    return Golang.String.fromDart('errno ${Golang.Int.from(this)}');
  }

  /// `Is(target)`: os erros portáveis do `io/fs`/`errors` que o errno
  /// representa.
  @override
  bool is$(GoError? target) {
    if (identical(target, fs.errPermission)) {
      return this == eacces || this == eperm;
    }
    if (identical(target, fs.errExist)) {
      return this == eexist || this == enotempty;
    }
    if (identical(target, fs.errNotExist)) return this == enoent;
    if (identical(target, errors.errUnsupported)) {
      return this == enosys || this == enotsup || this == eopnotsupp;
    }
    return false;
  }

  /// `Temporary()`.
  @override
  bool temporary() =>
      this == eintr || this == emfile || this == enfile || timeout();

  /// `Timeout()`.
  @override
  bool timeout() => this == eagain || this == ewouldblock || this == etimedout;
}

const _errnoMethods = ['Error', 'Is', 'Temporary', 'Timeout'];
