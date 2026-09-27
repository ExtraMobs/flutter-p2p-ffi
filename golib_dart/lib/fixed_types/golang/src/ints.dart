// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Representação dos inteiros Go sem BigInt, igual em todas as plataformas.
///
/// - Até 32 bits ([SmallIntBase]): um `int` normalizado à largura.
/// - 64 bits ([WideIntBase]): duas palavras de 32 bits sem sinal ([$hi]/[$lo]).
///
/// Invariantes que tornam o código exato também no JS (int = double, bitwise
/// em 32 bits): nenhum intermediário passa de 2^53; `&`, `|`, `^`, `~`, `<<`
/// e `>>` só recebem valores de até 32 bits e o resultado é sempre
/// renormalizado (no JS esses operadores devolvem 32 bits sem sinal).
/// Carries entre palavras usam `~/` e `*`, nunca shifts de valores maiores
/// que 32 bits.
library;

import 'dart:typed_data';

import 'base.dart';
import 'bounds.dart';

part 'ints/small_int.dart';
part 'ints/wide_int.dart';
part 'ints/width_bases.dart';

const int _m32 = 0xFFFFFFFF;
const int _p32 = 0x100000000;
const int _p16 = 0x10000;

/// v (|v| <= 2^53) truncado ao módulo `mod` (2^8, 2^16 ou 2^32).
int _wrap(int v, int mod, bool signed) {
  final u = v & (mod - 1);
  return signed && u >= mod ~/ 2 ? u - mod : u;
}

/// Os 32 bits baixos de a*b, com |a|, |b| < 2^32.
int _mul32(int a, int b) {
  a &= _m32;
  b &= _m32;
  final al = a & 0xFFFF, bl = b & 0xFFFF;
  final mid = ((a ~/ _p16) * bl + al * (b ~/ _p16)) & 0xFFFF;
  return (al * bl + mid * _p16) & _m32;
}

/// Palavra alta (complemento de dois) de um int Dart.
int _hiOf(int v) => ((v - (v & _m32)) ~/ _p32) & _m32;

final _bigM32 = BigInt.from(_m32);

int _bigLo(BigInt v) => (v & _bigM32).toInt();
int _bigHi(BigInt v) => ((v >> 32) & _bigM32).toInt();

int _nonZero(int d) {
  // Mesma exceção de antes (o runtime a traduz para o panic do Go); o
  // substituto sugerido (UnsupportedError) seria amplo demais.
  // ignore: deprecated_member_use
  if (d == 0) throw IntegerDivisionByZeroException();
  return d;
}

// Saídas de [_udivmod]: sem alocação (o código é síncrono).
int _qh = 0, _ql = 0, _rh = 0, _rl = 0;

/// Divisão sem sinal de 64 bits por palavras: deslocar e subtrair, a partir
/// do bit mais alto do dividendo (no máximo 64 passos). Quociente em
/// `_qh`/`_ql`, resto em `_rh`/`_rl`.
void _udivmod(int ah, int al, int bh, int bl) {
  var qh = 0, ql = 0, rh = 0, rl = 0;
  for (var i = (ah != 0 ? 32 + ah.bitLength : al.bitLength) - 1; i >= 0; i--) {
    // r < b; se o bit 63 de r estiver ligado, 2r passa de 2^64 > b.
    final carry = rh >= 0x80000000;
    final bit = i >= 32 ? (ah >> (i - 32)) & 1 : (al >> i) & 1;
    rh = ((rh << 1) | (rl >> 31)) & _m32;
    rl = ((rl << 1) | bit) & _m32;
    if (carry || rh > bh || (rh == bh && rl >= bl)) {
      final lo = rl - bl;
      rh = (rh - bh - (lo < 0 ? 1 : 0)) & _m32;
      rl = lo & _m32;
      if (i >= 32) {
        qh |= 1 << (i - 32);
      } else {
        ql |= 1 << i;
      }
    }
  }
  _qh = qh;
  _ql = ql;
  _rh = rh;
  _rl = rl;
}

void _checkShift(int n) {
  if (n < 0) throw ArgumentError.value(n, 'count', 'negative shift amount');
}
