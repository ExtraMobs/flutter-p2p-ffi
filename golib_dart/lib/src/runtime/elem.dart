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
    this.value = false,
    this.ofInt,
    this.ofFloat,
    this.rewrap,
    this.type,
  });

  /// Descritor de reflexão de T (`reflect.Type`, thunk): o g2d o emite só
  /// num grafo que usa reflexão; o reflect o lê para o tipo dinâmico de um
  /// `[]T`/`map[K]T` guardado numa interface.
  final Object Function()? type;

  /// `f<T>()`: T reificado (reflexão sobre um `Elem` de tipo estático
  /// desconhecido).
  R $with<R>(R Function<E>() f) => f<T>();

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

  /// T é struct/array **por valor** ([GoValue] com armazenamento próprio).
  /// Ponteiro `*T` e interface também guardam um [GoValue] no Dart (o objeto
  /// apontado, ou a cópia por valor dentro da interface), mas copiar o
  /// elemento é copiar a referência: só com [value] o elemento é copiado
  /// ([copyOf]) e sobrescrito in-place ([storeAt]).
  final bool value;

  /// Zero value novo (structs precisam de objetos distintos).
  final T Function() zero;

  /// Cópia de valor de um elemento: struct/array por valor são copiados;
  /// ponteiro e interface mantêm o mesmo objeto (e o `$isValue`).
  T copyOf(T v) => value && v is GoValue ? v.$copy() as T : v;

  /// Valor de T entrando numa interface (`any(v)` com v de parâmetro de
  /// tipo): struct/array por valor vira a cópia marcada `$isValue`.
  Object? ifaceOf(T v) => value && v is GoValue ? v.$ifaceCopy() : v;

  /// `a[i] = v` num armazenamento de elementos T: struct/array por valor
  /// sobrescrevem in-place (ponteiros para o elemento veem o novo valor);
  /// os demais trocam a referência.
  void storeAt(List<T> array, int i, T v) {
    final cur = array[i];
    if (value && cur is GoValue && v is GoValue) {
      cur.$set(v);
    } else {
      array[i] = v;
    }
  }
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
