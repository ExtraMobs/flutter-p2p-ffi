// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import '../int64.dart';

/// Conversão Go float → inteiro como o gc compila em amd64 (a spec deixa o
/// resultado fora do intervalo a cargo da implementação). Devolve os 64 bits
/// que a instrução deixaria; `T.from` do destino mantém os bits baixos.
///
/// - int64/int/uint32: CVTTSD2SQ — trunca; NaN ou fora de int64 → MinInt64.
/// - int32/int16/int8/uint16/uint8: CVTTSD2SL — idem com MinInt32.
/// - uint64/uint/uintptr: x >= 2^63 → CVTTSD2SQ(x - 2^63) | 2^63; senão CVTTSD2SQ.
Int64 floatToInteger(double x, int width, {required bool signed}) {
  if (width == 64 && !signed && x >= _two63) {
    return _cvtt64(x - _two63) | _minInt64;
  }
  if (width == 64 || (width == 32 && !signed)) return _cvtt64(x);
  return _cvtt32(x);
}

const _two63 = 9223372036854775808.0;
const _two31 = 2147483648.0;
const _two32 = 4294967296.0;
final _minInt64 = Int64(1) << 63;

/// Truncado em [-2^63, 2^63): a magnitude inteira é exata em double, e as
/// palavras saem por divisão exata por 2^32 (sem int acima de 2^53 no JS).
Int64 _cvtt64(double x) {
  if (x.isNaN || x < -_two63 || x >= _two63) return _minInt64;
  final m = x.truncateToDouble().abs();
  final hi = (m / _two32).floorToDouble();
  final v = (Int64(hi.toInt()) << 32) | Int64((m - hi * _two32).toInt());
  return x < 0 ? -v : v;
}

Int64 _cvtt32(double x) =>
    Int64(x.isNaN || x <= -_two31 - 1 || x >= _two31 ? -0x80000000 : x.toInt());
