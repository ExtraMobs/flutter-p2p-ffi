/// Descritor de tipo de elemento (slices, maps, ponteiros novos).
library;

import '../../fixed_types/golang.dart' as Golang;
import 'struct.dart';

/// O que o runtime precisa saber de um tipo Go T que ele guarda: tamanho e
/// presença de ponteiros (amd64; decidem o `cap` do `append`, como no
/// `growslice` do Go) e como criar o zero value. Instâncias são `const`
/// geradas pelo g2d, uma por tipo — semente dos descritores de tipo da
/// reflexão estática.
final class Elem<T> {
  const Elem(
    this.size,
    this.zero, {
    this.pointers = false,
    this.ofInt,
    this.ofFloat,
    this.rewrap,
  });

  /// Slice/map/array visto como T (T de core type composto, `S ~[]E`):
  /// o tipo nomeado reembrulha (`IDs(v)`); o sem nome é o próprio valor.
  final T Function(Object)? rewrap;

  /// `append(s, x)` com s do parâmetro de tipo S devolve S, como no Go.
  T rewrapOf(Object v) => rewrap != null ? rewrap!(v) : v as T;

  /// Conversão Go `T(n)` a partir de um inteiro, para tipos numéricos
  /// (dicionário de genéricos: `T(len(xs))` com T parâmetro de tipo).
  final T Function(Golang.IntBase)? ofInt;

  /// Conversão Go `T(f)` a partir de um float (`N(float64(x) * f)`).
  final T Function(Golang.FloatBase)? ofFloat;

  /// `unsafe.Sizeof(T)` em amd64.
  final int size;

  /// T contém ponteiros (string, slice, map, ponteiro, interface...).
  final bool pointers;

  /// Zero value novo (structs precisam de objetos distintos).
  final T Function() zero;

  /// Cópia de valor de um elemento (structs são copiadas).
  T copyOf(T v) => v is GoValue ? v.$copy() as T : v;
}

/// Zero value de `bool` (tear-off const para [Elem]).
bool zeroBool() => false;

/// Zero value de tipos anuláveis: ponteiro, interface, func, chan.
Null zeroNull() => null;

/// `int64(x)` com x de parâmetro de tipo numérico (inteiro ou float em
/// runtime): o inteiro Go, com as regras do gc para float (`toInteger`).
Golang.IntBase realToInt(Object x, int width, bool signed) => switch (x) {
  Golang.IntBase n => n,
  Golang.FloatBase f => f.toInteger(width, signed: signed),
  _ => throw ArgumentError.value(x, 'x', 'não numérico'),
};

/// `float64(x)` com x de parâmetro de tipo numérico: um arredondamento só,
/// como o Go (inteiro via Int64/Uint64 exatos).
S realToFloat<S>(
  Object x,
  S Function(Golang.Int64) fromInt64,
  S Function(Golang.Uint64) fromUint64,
  S Function(double) fromDouble,
) => switch (x) {
  Golang.IntBase n when n.$signed => fromInt64(Golang.Int64.from(n)),
  Golang.IntBase n => fromUint64(Golang.Uint64.from(n)),
  Golang.FloatBase f => fromDouble(f.toDouble()),
  _ => throw ArgumentError.value(x, 'x', 'não numérico'),
};
