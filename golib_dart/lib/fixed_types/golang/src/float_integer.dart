// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Conversão Go float → inteiro como o gc compila em amd64 (a spec deixa o
/// resultado fora do intervalo a cargo da implementação). Devolve o valor
/// exato antes do corte de largura; o construtor `fromBigInt` do destino
/// mantém os bits baixos.
///
/// - int64/int/uint32: CVTTSD2SQ — trunca; NaN ou fora de int64 → MinInt64.
/// - int32/int16/int8/uint16/uint8: CVTTSD2SL — idem com MinInt32.
/// - uint64/uint/uintptr: x >= 2^63 → CVTTSD2SQ(x - 2^63) | 2^63; senão CVTTSD2SQ.
BigInt floatToInteger(double x, int width, {required bool signed}) {
  if (width == 64 && !signed && x >= _two63) {
    return _cvtt64(x - _two63).toUnsigned(64) | (BigInt.one << 63);
  }
  if (width == 64 || (width == 32 && !signed)) return _cvtt64(x);
  return _cvtt32(x);
}

const _two63 = 9223372036854775808.0;
const _two31 = 2147483648.0;

BigInt _cvtt64(double x) => x.isNaN || x < -_two63 || x >= _two63
    ? -(BigInt.one << 63)
    : BigInt.from(x);

BigInt _cvtt32(double x) => x.isNaN || x <= -_two31 - 1 || x >= _two31
    ? -(BigInt.one << 31)
    : BigInt.from(x);
