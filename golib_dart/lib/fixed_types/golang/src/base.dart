// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Bases de operadores dos tipos básicos Go.
///
/// Toda classe de fixed_types (Int8 … Uint64, Int, Uint, Uintptr, Float32/64,
/// String) estende uma destas bases, e os tipos nomeados gerados pelo g2d
/// (`type Celsius float64`) também: herdam os operadores, que devolvem o
/// próprio tipo nomeado. Cada tipo Go é uma classe distinta, e a identidade
/// em runtime (`is Celsius`) vem de graça. As interfaces [GoOrdered] e
/// [GoNumber] são os bounds dos genéricos (`cmp.Ordered`, `constraints.*`).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../string.dart' as go;
import 'float_format.dart';
import 'float_integer.dart';

/// Identidade Go de um valor em runtime: nome do tipo (`int8`, `main.Celsius`)
/// e method set (nomes Go, ordenados). Usado nas mensagens de type
/// assertion e, depois, na reflexão.
abstract interface class GoTyped {
  String get $goType;
  List<String> get $methods;
}

/// `cmp.Ordered`: inteiros, floats e strings.
abstract interface class GoOrdered<S> implements Comparable<S> {
  bool operator <(S o);
  bool operator <=(S o);
  bool operator >(S o);
  bool operator >=(S o);
}

/// Números Go (inteiros, floats): aritmética e o quociente `/` do Go
/// ([$quo]: truncado nos inteiros, IEEE nos floats) para código genérico.
abstract interface class GoNumber<S> {
  S operator +(S o);
  S operator -(S o);
  S operator *(S o);
  S operator -();
  S $quo(S o);
}

/// Números ordenados (inteiros e floats): bound de uniões como
/// `~int | ~float64` nos genéricos.
abstract interface class GoReal<S> implements GoOrdered<S>, GoNumber<S> {}

/// Inteiros de largura fixa. A representação fica em `ints.dart`
/// ([SmallIntBase] até 32 bits, [WideIntBase] com 64), sem BigInt no caminho
/// comum; esta interface expõe os 64 bits em complemento de dois
/// ([$hi]/[$lo]), a moeda das conversões entre larguras (`T.from(v)`).
abstract base class IntBase<S extends IntBase<S>>
    implements GoReal<S>, GoTyped {
  const IntBase();

  @override
  List<String> get $methods => const [];

  /// Palavra alta dos 64 bits (estendida por sinal ou zero), em [0, 2^32).
  int get $hi;

  /// Palavra baixa dos 64 bits, em [0, 2^32).
  int get $lo;

  /// Tipo com sinal (int*) ou sem (uint*).
  bool get $signed;

  /// Valor como int Dart (índices, contagens, runas); exato em ±2^53.
  int toInt();

  /// Valor matemático exato (fronteira lenta: floats, testes).
  BigInt toBigInt();

  /// Cópia dos bytes em little-endian (não é formato de protocolo).
  Uint8List toLittleEndianBytes();

  @override
  S $quo(S o) => this ~/ o;

  /// `/` inteiro do Go: trunca para zero.
  S operator ~/(S o);

  /// `%` do Go: sinal do dividendo.
  S operator %(S o);
  S operator &(S o);
  S operator |(S o);
  S operator ^(S o);
  S operator ~();

  /// `&^` do Go.
  S andNot(S o);
  S operator <<(int n);
  S operator >>(int n);
}

/// Floats IEEE: operações em binary64, arredondadas pelo construtor
/// ([$wrapDouble]) à largura do tipo.
abstract base class FloatBase<S extends FloatBase<S>>
    implements GoReal<S>, GoTyped {
  const FloatBase();

  @override
  List<String> get $methods => const [];

  double toDouble();

  /// Novo valor do tipo (arredonda para binary32 quando for o caso).
  S $wrapDouble(double v);

  /// 32 ou 64 (formatação `%v`).
  int get $bits => 64;

  @override
  S operator +(S o) => $wrapDouble(toDouble() + o.toDouble());
  @override
  S operator -(S o) => $wrapDouble(toDouble() - o.toDouble());
  @override
  S operator *(S o) => $wrapDouble(toDouble() * o.toDouble());
  @override
  S operator -() => $wrapDouble(-toDouble());
  S operator /(S o) => $wrapDouble(toDouble() / o.toDouble());
  @override
  S $quo(S o) => this / o;

  /// `cmp.Compare`: NaN antes de todos, NaN == NaN; -0 == +0.
  @override
  int compareTo(S o) {
    final a = toDouble(), b = o.toDouble();
    if (a.isNaN) return b.isNaN ? 0 : -1;
    if (b.isNaN) return 1;
    return a < b ? -1 : (a > b ? 1 : 0);
  }

  @override
  bool operator <(S o) => toDouble() < o.toDouble();
  @override
  bool operator <=(S o) => toDouble() <= o.toDouble();
  @override
  bool operator >(S o) => toDouble() > o.toDouble();
  @override
  bool operator >=(S o) => toDouble() >= o.toDouble();

  /// Go T(x) para um inteiro de `width` bits (gc/amd64).
  IntBase toInteger(int width, {required bool signed}) =>
      floatToInteger(toDouble(), width, signed: signed);

  @override
  bool operator ==(Object o) => o is S && toDouble() == o.toDouble();
  @override
  int get hashCode => toDouble().hashCode;

  /// Go `%v`: `strconv.FormatFloat(x, 'g', -1, bits)`.
  @override
  String toString() => formatGoFloat(toDouble(), $bits);
}

/// Strings Go (bytes). Tipos nomeados sobre string delegam a um [go.String].
abstract base class StringBase<S extends StringBase<S>>
    implements GoOrdered<S>, GoTyped {
  const StringBase();

  @override
  List<String> get $methods => const [];

  /// O valor como `Golang.String`.
  go.String get $str;

  /// Novo valor do tipo a partir de um `Golang.String`.
  S $wrapStr(go.String s);

  /// `len(s)` em bytes.
  int get length => $str.length;

  /// `s[i]`: o byte.
  int operator [](int i) => $str[i];

  S operator +(S o) => $wrapStr($str + o.$str);

  /// `s[low:high]`: mesmo tipo nomeado, como no Go.
  S slice([int low = 0, int? high]) => $wrapStr($str.slice(low, high));

  Uint8List toBytes() => $str.toBytes();

  @override
  int compareTo(S o) => $str.compareTo(o.$str);
  @override
  bool operator <(S o) => compareTo(o) < 0;
  @override
  bool operator <=(S o) => compareTo(o) <= 0;
  @override
  bool operator >(S o) => compareTo(o) > 0;
  @override
  bool operator >=(S o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object o) => o is S && $str.compareTo(o.$str) == 0;
  @override
  int get hashCode => Object.hashAll($str.toBytes());
  @override
  String toString() => utf8.decode($str.toBytes(), allowMalformed: true);
}

/// Operações de complex64/complex128 (as de [ComplexBase] delegam a elas).
abstract interface class ComplexOps<C extends ComplexOps<C>> {
  C operator +(C o);
  C operator -(C o);
  C operator *(C o);
  C operator /(C o);
  C operator -();
}

/// Tipos nomeados sobre complex (`type Z complex128`): guardam o valor do
/// subjacente ([$c], um [ComplexOps]) e delegam a ele as operações, que
/// devolvem o próprio tipo nomeado.
abstract base class ComplexBase<S extends ComplexBase<S, C>,
        C extends ComplexOps<C>>
    implements GoTyped {
  const ComplexBase();

  @override
  List<String> get $methods => const [];

  /// O valor como complex64/complex128.
  C get $c;

  /// Novo valor do tipo nomeado.
  S $wrapC(C v);

  S operator +(S o) => $wrapC($c + o.$c);
  S operator -(S o) => $wrapC($c - o.$c);
  S operator *(S o) => $wrapC($c * o.$c);
  S operator /(S o) => $wrapC($c / o.$c);
  S operator -() => $wrapC(-$c);

  @override
  bool operator ==(Object o) => o is S && $c == o.$c;
  @override
  int get hashCode => $c.hashCode;

  /// Go `%v`: o do subjacente (`(1+2i)`).
  @override
  String toString() => $c.toString();
}
