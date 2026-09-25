// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:math' as math;

import 'ints.dart';

/// Arredonda um inteiro de 64 bits direto à precisão do significando IEEE
/// (24 ou 53 bits), com desempate para par e sem arredondamento duplo; o
/// resultado é exato em binary64 antes de um eventual binary32.
///
/// Trabalha nas palavras da magnitude: o significando tem no máximo 53 bits e
/// a parte descartada no máximo 40 (shift <= 64 - 24), então nenhum int passa
/// de 2^53 em nenhuma plataforma.
double integerToFloat(WideIntBase value, int precision) {
  var hi = value.$hi, lo = value.$lo;
  final neg = value.$signed && hi >= 0x80000000;
  if (neg) {
    hi = (-hi - (lo != 0 ? 1 : 0)) & 0xFFFFFFFF;
    lo = -lo & 0xFFFFFFFF;
  }
  final shift = (hi != 0 ? 32 + hi.bitLength : lo.bitLength) - precision;
  double r;
  if (shift <= 0) {
    r = hi * 4294967296.0 + lo;
  } else {
    int sig, discarded;
    if (shift >= 32) {
      final k = shift - 32;
      sig = hi >> k;
      discarded = (hi & ((1 << k) - 1)) * 4294967296 + lo;
    } else {
      sig = hi * (1 << (32 - shift)) + (lo >> shift);
      discarded = lo & ((1 << shift) - 1);
    }
    final half = math.pow(2, shift - 1).toInt();
    if (discarded > half || (discarded == half && sig.isOdd)) sig++;
    r = sig * math.pow(2, shift).toDouble();
  }
  return neg ? -r : r;
}
