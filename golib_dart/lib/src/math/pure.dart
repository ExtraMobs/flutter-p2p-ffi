/// Porta do código Go puro do pacote `math` (Go 1.26.5; derivado do FreeBSD
/// msun/fdlibm e do Cephes) sobre `double`: o resultado do `math` do Go sem
/// assembly (386, arm, riscv64, wasm...), bit a bit, igual em VM, JS e Wasm.
/// No amd64 o gc usa assembly em Exp e Log (e, por elas, em Pow, Log2,
/// Log10, Gamma...), com outro algoritmo: pode diferir no último bit.
///
/// As expressões constantes do Go (`1 / Ln10`, `Pi / 4`...) são dobradas com
/// precisão arbitrária antes de virar float64; aqui entram já dobradas.
// ignore_for_file: library_prefixes
library;

import 'dart:math' as dm;
import 'dart:typed_data';

import '../../fixed_types/golang.dart' as Golang;
import '../../math/bits.dart' as bits;

part 'pure/exp.dart';
part 'pure/log.dart';
part 'pure/pow.dart';
part 'pure/trig.dart';
part 'pure/lgamma.dart';
part 'pure/gamma.dart';
part 'pure/erf.dart';

final ByteData _b = ByteData(8);

int _hi(double x) {
  _b.setFloat64(0, x);
  return _b.getUint32(0);
}

int _lo(double x) {
  _b.setFloat64(0, x);
  return _b.getUint32(4);
}

double _make(int hi, int lo) {
  _b
    ..setUint32(0, hi & 0xffffffff)
    ..setUint32(4, lo & 0xffffffff);
  return _b.getFloat64(0);
}

Golang.Uint64 _bits(double x) {
  _b.setFloat64(0, x);
  return Golang.Uint64().$make(_b.getUint32(0), _b.getUint32(4));
}

double _frombits(Golang.Uint64 v) => _make(v.$hi, v.$lo);

Golang.Uint64 _u64(int hi, int lo) => Golang.Uint64().$make(hi, lo);

const double _smallestNormal = 2.2250738585072014e-308; // 2**-1022
const double _two52 = 4503599627370496.0;
const double _pi = 3.141592653589793;
const double _sqrt2Half = 0.7071067811865476; // Sqrt2/2
const double _invLn10 = 0.4342944819032518; // 1/Ln10
const double _invLn2 = 1.4426950408889634; // 1/Ln2
const double _fourOverPi = 1.2732395447351628; // 4/Pi
const double _piOver4 = 0.7853981633974483; // Pi/4
const double _piOver2 = 1.5707963267948966; // Pi/2
const double _ln2Hi = 6.93147180369123816490e-01;
const double _ln2Lo = 1.90821492927058770002e-10;
