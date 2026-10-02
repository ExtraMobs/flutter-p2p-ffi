part of '../../strconv.dart';

String _formatFloat(double f, int fmtc, int prec, int bitSize) {
  if (bitSize != 32 && bitSize != 64) {
    throw Panic(
      Golang.String.fromDart(
        'strconv: illegal AppendFloat/FormatFloat bitSize',
      ),
    );
  }
  final c = String.fromCharCode(fmtc);
  final x = bitSize == 32 ? Golang.Float32(f).toDouble() : f;
  if (x.isNaN || x.isInfinite) return ff.formatGoFloatFmt(x, 'g', -1, 64);
  if (!'eEfgG'.contains(c)) {
    if ('bxX'.contains(c)) {
      // ponytail: %b/%x/%X (mantissa/expoente binários) ainda sem porta.
      throw UnsupportedError('strconv.FormatFloat: formato $c');
    }
    return '%$c'; // o Go devolve '%' + fmt para formato desconhecido
  }
  return ff.formatGoFloatFmt(x, c, prec, bitSize);
}

/// `strconv.FormatFloat(f, fmt, prec, bitSize)` para `e E f g G`.
Golang.String formatFloat(
  Golang.Float64 f,
  Golang.Uint8 fmt,
  Golang.Int prec,
  Golang.Int bitSize,
) => Golang.String.fromDart(
  _formatFloat(f.toDouble(), fmt.toInt(), prec.toInt(), bitSize.toInt()),
);

/// `strconv.AppendFloat(dst, f, fmt, prec, bitSize)`.
Slice<Golang.Uint8> appendFloat(
  Slice<Golang.Uint8> dst,
  Golang.Float64 f,
  Golang.Uint8 fmt,
  Golang.Int prec,
  Golang.Int bitSize,
) => _appendBytes(
  dst,
  _formatFloat(
    f.toDouble(),
    fmt.toInt(),
    prec.toInt(),
    bitSize.toInt(),
  ).codeUnits,
);
