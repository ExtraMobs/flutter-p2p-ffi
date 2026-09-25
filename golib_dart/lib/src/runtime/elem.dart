/// Descritor de tipo de elemento (slices, maps, ponteiros novos).
library;

import 'struct.dart';

/// O que o runtime precisa saber de um tipo Go T que ele guarda: tamanho e
/// presença de ponteiros (amd64; decidem o `cap` do `append`, como no
/// `growslice` do Go) e como criar o zero value. Instâncias são `const`
/// geradas pelo g2d, uma por tipo — semente dos descritores de tipo da
/// reflexão estática.
final class Elem<T> {
  const Elem(this.size, this.zero, {this.pointers = false, this.ofInt});

  /// Conversão Go `T(n)` a partir de um inteiro, para tipos numéricos
  /// (dicionário de genéricos: `T(len(xs))` com T parâmetro de tipo).
  final T Function(BigInt)? ofInt;

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
