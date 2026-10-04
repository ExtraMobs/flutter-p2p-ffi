part of '../../reflect.dart';

/// Kinds do Go (os valores de `reflect.Kind`).
const kInvalid = 0,
    kBool = 1,
    kInt = 2,
    kInt8 = 3,
    kInt16 = 4,
    kInt32 = 5,
    kInt64 = 6,
    kUint = 7,
    kUint8 = 8,
    kUint16 = 9,
    kUint32 = 10,
    kUint64 = 11,
    kUintptr = 12,
    kFloat32 = 13,
    kFloat64 = 14,
    kComplex64 = 15,
    kComplex128 = 16,
    kArray = 17,
    kChan = 18,
    kFunc = 19,
    kInterface = 20,
    kMap = 21,
    kPointer = 22,
    kSlice = 23,
    kString = 24,
    kStruct = 25,
    kUnsafePointer = 26;

const _kindNames = [
  'invalid',
  'bool',
  'int',
  'int8',
  'int16',
  'int32',
  'int64',
  'uint',
  'uint8',
  'uint16',
  'uint32',
  'uint64',
  'uintptr',
  'float32',
  'float64',
  'complex64',
  'complex128',
  'array',
  'chan',
  'func',
  'interface',
  'map',
  'ptr',
  'slice',
  'string',
  'struct',
  'unsafe.Pointer',
];

/// Nome Go de um kind (`Kind.String()`).
String kindName(int k) =>
    k >= 0 && k < _kindNames.length ? _kindNames[k] : 'kind$k';

bool _isIntKind(int k) => k >= kInt && k <= kInt64;
bool _isUintKind(int k) => k >= kUint && k <= kUintptr;
bool _isFloatKind(int k) => k == kFloat32 || k == kFloat64;
bool _isComplexKind(int k) => k == kComplex64 || k == kComplex128;

/// `reflect.Kind` (`type Kind uint`).
final class Kind extends Golang.Uint64Base<Kind> implements fmt.Stringer {
  Kind([int v = 0]) : super(v);
  Kind.from(Golang.IntBase v) : super.from(v);
  Kind.fromBigInt(BigInt v) : super.fromBigInt(v);
  Kind._(super.$hi, super.$lo) : super.raw();

  @override
  Kind $make(int hi, int lo) => Kind._(hi, lo);

  @override
  String get $goType => 'reflect.Kind';

  @override
  List<String> get $methods => const ['String'];

  @override
  Golang.String string() => Golang.String.fromDart(kindName(toInt()));
}

/// `reflect.ChanDir` (`type ChanDir int`).
final class ChanDir extends Golang.Int64Base<ChanDir> implements fmt.Stringer {
  ChanDir([int v = 0]) : super(v);
  ChanDir.from(Golang.IntBase v) : super.from(v);
  ChanDir.fromBigInt(BigInt v) : super.fromBigInt(v);
  ChanDir._(super.$hi, super.$lo) : super.raw();

  @override
  ChanDir $make(int hi, int lo) => ChanDir._(hi, lo);

  @override
  String get $goType => 'reflect.ChanDir';

  @override
  List<String> get $methods => const ['String'];

  @override
  Golang.String string() => Golang.String.fromDart(switch (toInt()) {
    1 => '<-chan',
    2 => 'chan<-',
    3 => 'chan',
    final d => 'ChanDir$d',
  });
}
