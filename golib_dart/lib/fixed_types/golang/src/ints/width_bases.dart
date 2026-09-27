part of '../ints.dart';

// Uma base por largura: fixa largura e sinal e dá os construtores que os
// tipos nomeados gerados pelo g2d repassam (`N(v)`, `N.from`, `N.fromBigInt`).

abstract base class Int8Base<S extends Int8Base<S>> extends SmallIntBase<S> {
  Int8Base([int v = 0]) : super.raw(_wrap(v, 0x100, true));
  Int8Base.from(IntBase v) : this(v.$lo);
  Int8Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 8;
  @override
  bool get $signed => true;
}

abstract base class Int16Base<S extends Int16Base<S>> extends SmallIntBase<S> {
  Int16Base([int v = 0]) : super.raw(_wrap(v, 0x10000, true));
  Int16Base.from(IntBase v) : this(v.$lo);
  Int16Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 16;
  @override
  bool get $signed => true;
}

abstract base class Int32Base<S extends Int32Base<S>> extends SmallIntBase<S> {
  Int32Base([int v = 0]) : super.raw(_wrap(v, _p32, true));
  Int32Base.from(IntBase v) : this(v.$lo);
  Int32Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 32;
  @override
  bool get $signed => true;
}

abstract base class Uint8Base<S extends Uint8Base<S>> extends SmallIntBase<S> {
  Uint8Base([int v = 0]) : super.raw(_wrap(v, 0x100, false));
  Uint8Base.from(IntBase v) : this(v.$lo);
  Uint8Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 8;
  @override
  bool get $signed => false;
}

abstract base class Uint16Base<S extends Uint16Base<S>>
    extends SmallIntBase<S> {
  Uint16Base([int v = 0]) : super.raw(_wrap(v, 0x10000, false));
  Uint16Base.from(IntBase v) : this(v.$lo);
  Uint16Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 16;
  @override
  bool get $signed => false;
}

abstract base class Uint32Base<S extends Uint32Base<S>>
    extends SmallIntBase<S> {
  Uint32Base([int v = 0]) : super.raw(_wrap(v, _p32, false));
  Uint32Base.from(IntBase v) : this(v.$lo);
  Uint32Base.fromBigInt(BigInt v) : this(_bigLo(v));
  @override
  int get $width => 32;
  @override
  bool get $signed => false;
}

abstract base class Int64Base<S extends Int64Base<S>> extends WideIntBase<S> {
  Int64Base([int v = 0]) : super.raw(_hiOf(v), v & _m32);
  Int64Base.from(IntBase v) : super.raw(v.$hi, v.$lo);
  Int64Base.fromBigInt(BigInt v) : super.raw(_bigHi(v), _bigLo(v));
  const Int64Base.raw(super.$hi, super.$lo) : super.raw();
  @override
  bool get $signed => true;
}

abstract base class Uint64Base<S extends Uint64Base<S>> extends WideIntBase<S> {
  Uint64Base([int v = 0]) : super.raw(_hiOf(v), v & _m32);
  Uint64Base.from(IntBase v) : super.raw(v.$hi, v.$lo);
  Uint64Base.fromBigInt(BigInt v) : super.raw(_bigHi(v), _bigLo(v));
  const Uint64Base.raw(super.$hi, super.$lo) : super.raw();
  @override
  bool get $signed => false;
}
