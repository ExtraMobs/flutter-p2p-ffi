# Uso de `reflect`

Gerado por `python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo`. **Não edite**.

Toda seleção que toca o pacote `reflect` nos pacotes do grafo. Status: todas pendentes
até o M5 (reflexão estática, `TODO/P1-design-m5-reflexao.md`).

9666 usos em 134 pacotes.

## Por símbolo

| símbolo | usos | pacotes |
|---|---:|---:|
| `TypeOf` | 304 | 87 |
| `ValueOf` | 430 | 61 |
| `PkgPath` | 70 | 58 |
| `Elem` | 864 | 52 |
| `Kind` | 745 | 52 |
| `Type` | 1085 | 50 |
| `String` | 308 | 43 |
| `Interface` | 505 | 41 |
| `Name` | 124 | 31 |
| `IsNil` | 247 | 30 |
| `Ptr` | 233 | 29 |
| `Slice` | 157 | 28 |
| `Len` | 212 | 27 |
| `Value` | 565 | 26 |
| `Index` | 174 | 26 |
| `Struct` | 109 | 26 |
| `Field` | 193 | 25 |
| `NumField` | 90 | 24 |
| `Pointer` | 74 | 24 |
| `Uint64` | 88 | 23 |
| `Map` | 80 | 23 |
| `Uint` | 124 | 22 |
| `Bool` | 117 | 22 |
| `Int64` | 91 | 21 |
| `Uint32` | 78 | 21 |
| `Array` | 58 | 21 |
| `New` | 158 | 20 |
| `Int` | 96 | 20 |
| `Uint8` | 89 | 19 |
| `Int32` | 88 | 19 |
| `Set` | 289 | 18 |
| `Float64` | 66 | 18 |
| `Float32` | 66 | 17 |
| `Uint16` | 40 | 17 |
| `Tag` | 92 | 16 |
| `Int16` | 39 | 16 |
| `Int8` | 39 | 16 |
| `IsValid` | 74 | 15 |
| `Float` | 46 | 15 |
| `Key` | 43 | 15 |
| `Get` | 77 | 14 |
| `Implements` | 34 | 13 |
| `Zero` | 75 | 12 |
| `Uintptr` | 32 | 12 |
| `MapIndex` | 35 | 11 |
| `Call` | 24 | 11 |
| `Func` | 24 | 11 |
| `SetUint` | 27 | 10 |
| `MakeMap` | 24 | 10 |
| `SetMapIndex` | 24 | 10 |
| `StructField` | 77 | 9 |
| `Append` | 39 | 9 |
| `Addr` | 31 | 9 |
| `SetInt` | 31 | 9 |
| `MapKeys` | 24 | 9 |
| `FieldByName` | 34 | 8 |
| `TypeFor` | 33 | 8 |
| `In` | 21 | 8 |
| `Bytes` | 19 | 8 |
| `CanAddr` | 17 | 8 |
| `DeepEqual` | 10 | 8 |
| `Convert` | 24 | 7 |
| `SetFloat` | 16 | 7 |
| `SetString` | 14 | 7 |
| `MakeSlice` | 13 | 7 |
| `SetBool` | 10 | 7 |
| `Anonymous` | 9 | 7 |
| `Indirect` | 49 | 6 |
| `MethodByName` | 18 | 6 |
| `MapRange` | 13 | 6 |
| `Next` | 13 | 6 |
| `Chan` | 12 | 6 |
| `SetBytes` | 10 | 6 |
| `AssignableTo` | 9 | 6 |
| `PtrTo` | 100 | 5 |
| `NumIn` | 22 | 5 |
| `CanInterface` | 19 | 5 |
| `Complex` | 15 | 5 |
| `Out` | 12 | 5 |
| `OverflowInt` | 12 | 5 |
| `OverflowUint` | 11 | 5 |
| `Complex128` | 9 | 5 |
| `Complex64` | 9 | 5 |
| `Invalid` | 6 | 5 |
| `NumOut` | 10 | 4 |
| `PointerTo` | 10 | 4 |
| `Copy` | 8 | 4 |
| `SliceOf` | 6 | 4 |
| `FieldByIndex` | 5 | 4 |
| `UnsafePointer` | 8 | 3 |
| `CanSet` | 7 | 3 |
| `ArrayOf` | 6 | 3 |
| `Cap` | 6 | 3 |
| `IsVariadic` | 6 | 3 |
| `NewAt` | 3 | 3 |
| `StructOf` | 16 | 2 |
| `Size` | 7 | 2 |
| `Offset` | 4 | 2 |
| `SetLen` | 4 | 2 |
| `UnsafeAddr` | 4 | 2 |
| `Comparable` | 3 | 2 |
| `Bits` | 2 | 2 |
| `ConvertibleTo` | 2 | 2 |
| `IsZero` | 2 | 2 |
| `MapOf` | 2 | 2 |
| `FuncOf` | 14 | 1 |
| `MakeFunc` | 14 | 1 |
| `StructTag` | 7 | 1 |
| `NumMethod` | 6 | 1 |
| `CanConvert` | 3 | 1 |
| `Data` | 2 | 1 |
| `Method` | 2 | 1 |
| `SelectCase` | 2 | 1 |
| `AppendSlice` | 1 | 1 |
| `CallSlice` | 1 | 1 |
| `Lookup` | 1 | 1 |
| `OverflowFloat` | 1 | 1 |
| `Select` | 1 | 1 |
| `SelectRecv` | 1 | 1 |
| `SliceHeader` | 1 | 1 |
| `StringHeader` | 1 | 1 |

## Por pacote

Posições exatas: `reflectUsage` do dump do pacote (goast).

| pacote | usos | símbolos | status |
|---|---:|---|---|
| `github.com/gogo/protobuf/proto` | 1970 | Elem(247), Interface(215), Type(148), Kind(120), ValueOf(94), Set(93), PtrTo(82), Len(72), Index(63), IsNil(58), TypeOf(57), Ptr(54), Name(42), New(41), Field(38), Value(33), Slice(31), Append(30), String(27), Get(25), Struct(25), Tag(25), Bool(19), Addr(17), Map(17), Int32(16), NumField(16), FieldByName(15), Int64(15), Uint32(15), Uint64(15), Uint8(15), Float32(14), Float64(14), MapIndex(14), StructField(12), MapKeys(11), Implements(10), IsValid(10), Int(9), SetInt(9), Bytes(8), Zero(7), Indirect(6), MakeSlice(6), SetMapIndex(6), Uint(6), Float(4), Key(4), MakeMap(4), SetUint(4), Convert(3), SetBytes(3), CanAddr(2), Cap(2), Int16(2), Int8(2), SetBool(2), SetLen(2), SetString(2), Uint16(2), AppendSlice(1), AssignableTo(1), Bits(1), Call(1), Copy(1), FieldByIndex(1), MethodByName(1), Pointer(1), SetFloat(1), SliceOf(1) | pendente |
| `google.golang.org/protobuf/internal/impl` | 1559 | Type(270), Elem(252), Kind(195), Value(77), IsNil(52), Set(48), New(43), Zero(38), Slice(35), Ptr(34), Int32(30), Interface(30), String(30), TypeOf(26), ValueOf(25), Int64(24), Len(24), Bool(19), StructField(19), Uint32(19), Uint64(19), IsValid(16), Field(15), Float32(14), Float64(14), Convert(13), Uint8(13), Get(12), PtrTo(12), Tag(12), Int(11), Struct(9), Float(8), Key(8), MapRange(8), Next(8), MakeMap(7), SetMapIndex(7), Uint(7), Map(5), MethodByName(5), NumField(5), Call(3), Func(3), In(3), Index(3), MapIndex(3), Name(3), Bytes(2), FieldByName(2), Implements(2), Method(2), Pointer(2), Addr(1), Append(1), CanAddr(1), Int16(1), Int8(1), IsZero(1), MapKeys(1), NewAt(1), Offset(1), PkgPath(1), SetInt(1), Uint16(1), Uintptr(1) | pendente |
| `go.uber.org/fx` | 544 | Type(86), Value(81), Field(39), StructField(31), TypeOf(25), NumField(24), Elem(23), Interface(23), Tag(19), ValueOf(19), NumIn(16), FuncOf(14), Kind(14), MakeFunc(14), Set(13), StructOf(13), New(12), Get(10), In(9), Call(8), String(7), StructTag(7), Name(5), Out(5), Ptr(5), Struct(5), NumOut(4), Func(3), Implements(3), IsVariadic(3), Anonymous(1), CallSlice(1), PkgPath(1), Zero(1) | pendente |
| `github.com/ipld/go-ipld-prime/node/bindnode` | 487 | Elem(56), Type(55), Kind(49), Value(34), Set(30), Interface(23), ValueOf(22), String(21), Ptr(20), Field(14), IsNil(14), New(14), TypeOf(10), FieldByName(9), NumField(9), Len(8), Index(7), PointerTo(5), Slice(5), StructField(5), Uint(5), Key(4), Struct(4), AssignableTo(3), Bool(3), Int(3), Name(3), SetInt(3), SetString(3), SetUint(3), StructOf(3), Uint8(3), Addr(2), Append(2), Float64(2), Int64(2), IsValid(2), Map(2), MapIndex(2), SliceOf(2), Uint64(2), Zero(2), Bytes(1), Convert(1), ConvertibleTo(1), FieldByIndex(1), Float(1), Float32(1), Int16(1), Int32(1), Int8(1), MakeMap(1), MapOf(1), SetBool(1), SetBytes(1), SetFloat(1), SetMapIndex(1), Uint16(1), Uint32(1) | pendente |
| `gopkg.in/yaml.v3` | 447 | Value(41), Type(34), Elem(29), Kind(27), Interface(20), String(20), ValueOf(17), Ptr(16), Set(16), IsNil(13), Bool(10), Int(10), Uint(10), Field(9), New(9), TypeOf(7), Float32(6), Len(6), Map(6), Slice(6), Struct(6), Float(5), Float64(5), Int16(5), Int32(5), Int64(5), Int8(5), IsValid(5), SetInt(5), Uint16(5), Uint32(5), Uint64(5), Uint8(5), Uintptr(5), CanAddr(4), Key(4), MakeMap(4), OverflowInt(4), OverflowUint(4), SetFloat(4), SetUint(4), Addr(3), Array(3), MapIndex(3), MapKeys(3), SetBool(3), SetMapIndex(3), Tag(3), Index(2), NumField(2), PkgPath(2), SetString(2), Anonymous(1), Get(1), Implements(1), MakeSlice(1), Name(1), PtrTo(1), Zero(1) | pendente |
| `github.com/polydawn/refmt/obj` | 445 | Type(59), Value(58), Kind(29), Elem(26), Set(24), Pointer(21), ValueOf(17), String(15), Zero(10), IsNil(9), Len(9), Uint8(9), Name(8), Uint(8), Bool(7), Int(7), New(7), Ptr(7), Array(5), Float32(5), Float64(5), Index(5), Int16(5), Int32(5), Int64(5), Int8(5), Interface(5), Slice(5), Uint16(5), Uint32(5), Uint64(5), Uintptr(5), Struct(4), IsValid(3), Map(3), SetBytes(3), SetFloat(3), SetUint(3), TypeOf(3), Float(2), Func(2), Key(2), MapIndex(2), SetInt(2), SetString(2), Append(1), Bytes(1), Field(1), Invalid(1), MakeMap(1), MakeSlice(1), MapKeys(1), NumField(1), PointerTo(1), SetBool(1), SetMapIndex(1) | pendente |
| `github.com/go-jose/go-jose/v4/json` | 437 | Type(73), Value(43), Kind(37), Elem(22), Ptr(18), String(18), IsNil(17), Interface(15), Set(13), ValueOf(8), Len(7), Slice(7), Bool(6), Int(6), Map(6), NumMethod(6), TypeOf(6), Uint(6), Uint8(6), Name(5), Array(4), Field(4), Float32(4), Float64(4), Implements(4), Int16(4), Int32(4), Int64(4), Int8(4), IsValid(4), Uint16(4), Uint32(4), Uint64(4), Addr(3), Cap(3), Index(3), Key(3), New(3), Struct(3), Uintptr(3), Zero(3), Anonymous(2), CanAddr(2), Float(2), MakeSlice(2), PtrTo(2), SetLen(2), SetString(2), Bits(1), Bytes(1), CanSet(1), Convert(1), Copy(1), Get(1), MakeMap(1), MapIndex(1), MapKeys(1), NumField(1), OverflowFloat(1), OverflowInt(1), OverflowUint(1), PkgPath(1), SetBool(1), SetBytes(1), SetFloat(1), SetInt(1), SetMapIndex(1), SetUint(1), StructField(1), Tag(1) | pendente |
| `gopkg.in/yaml.v2` | 427 | Type(36), Value(36), Elem(29), ValueOf(23), Kind(22), Set(20), String(19), Interface(17), Bool(10), Int(10), IsNil(10), Ptr(10), Uint(10), New(9), TypeOf(8), Field(7), Map(7), Float32(6), Len(6), Slice(6), Float(5), Float64(5), Int16(5), Int32(5), Int64(5), Int8(5), SetInt(5), Struct(5), Uint16(5), Uint32(5), Uint64(5), Uint8(5), Uintptr(5), OverflowInt(4), OverflowUint(4), SetFloat(4), SetUint(4), Array(3), CanAddr(3), Key(3), MakeMap(3), MapIndex(3), MapKeys(3), Tag(3), Addr(2), FieldByIndex(2), Index(2), IsValid(2), NumField(2), PkgPath(2), SetMapIndex(2), SetString(2), Zero(2), Anonymous(1), Convert(1), Get(1), MakeSlice(1), Name(1), SetBool(1) | pendente |
| `go.uber.org/dig` | 327 | Type(88), Value(63), Elem(27), Kind(20), TypeOf(13), Name(11), Get(10), Tag(10), Ptr(8), Field(6), StructField(6), Implements(5), Interface(5), Slice(5), ValueOf(5), NumField(4), String(4), Len(3), NumOut(3), PkgPath(3), PointerTo(3), Zero(3), ArrayOf(2), Func(2), Out(2), Pointer(2), SliceOf(2), Anonymous(1), Append(1), Array(1), Call(1), In(1), Index(1), IsVariadic(1), MakeSlice(1), New(1), NumIn(1), Set(1), Struct(1) | pendente |
| `github.com/kr/pretty` | 324 | Type(26), String(23), Kind(14), Elem(13), Interface(13), IsValid(13), IsNil(11), Value(11), Bool(10), Int(10), Uint(10), Len(9), Field(8), Index(8), Pointer(7), Ptr(7), Slice(7), Struct(7), Array(6), Complex(6), Float(6), NumField(6), Chan(5), Map(5), UnsafePointer(5), Complex128(4), Complex64(4), Float32(4), Float64(4), Func(4), Int16(4), Int32(4), Int64(4), Int8(4), MapIndex(4), Uint16(4), Uint32(4), Uint64(4), Uint8(4), Uintptr(4), ValueOf(4), CanAddr(3), Name(3), UnsafeAddr(3), Invalid(2), MapKeys(2), CanInterface(1) | pendente |
| `github.com/whyrusleeping/cbor/go` | 321 | Kind(35), Type(31), ValueOf(24), String(21), Value(21), Interface(18), Set(18), Indirect(15), Ptr(12), Elem(10), Array(6), CanSet(5), Int(5), IsNil(5), Uint8(5), Field(4), Int32(4), Int64(4), Name(4), New(4), SetInt(4), Slice(4), Float32(3), Float64(3), Int16(3), Int8(3), Uint(3), Zero(3), Bool(2), Bytes(2), Get(2), Index(2), Key(2), Len(2), Map(2), NumField(2), OverflowInt(2), SetFloat(2), Struct(2), Tag(2), Uint16(2), Uint32(2), Uint64(2), Append(1), FieldByName(1), Float(1), IsValid(1), MakeMap(1), MapIndex(1), MapKeys(1), OverflowUint(1), PkgPath(1), SetBytes(1), SetMapIndex(1), SetUint(1), StructField(1), TypeOf(1) | pendente |
| `github.com/whyrusleeping/cbor-gen` | 210 | Kind(45), Elem(29), String(17), Struct(14), Slice(12), Ptr(10), Uint8(10), Array(9), Name(9), Int64(8), Uint64(8), Map(6), Type(6), Bool(5), Key(4), TypeOf(4), PkgPath(3), Len(2), Pointer(2), ValueOf(2), Field(1), Get(1), Interface(1), NumField(1), Tag(1) | pendente |
| `github.com/pion/rtcp` | 167 | Type(18), Field(16), Interface(14), CanInterface(12), Index(10), Kind(9), Indirect(8), ValueOf(7), Size(6), Slice(5), Struct(5), Elem(4), Get(4), NumField(4), SetUint(4), Tag(4), Uint(4), IsValid(3), Len(3), Ptr(3), MethodByName(2), TypeOf(2), Uint16(2), Uint32(2), Uint64(2), Uint8(2), Append(1), Call(1), CanSet(1), Implements(1), IsNil(1), Name(1), New(1), NewAt(1), Set(1), String(1), UnsafeAddr(1), Value(1) | pendente |
| `github.com/cockroachdb/redact/internal/rfmt` | 163 | String(15), Type(14), Kind(10), TypeOf(10), Value(10), Slice(6), IsValid(5), Uint(5), ValueOf(5), Elem(4), Field(4), Int(4), Interface(4), IsNil(4), Len(4), Bytes(3), Index(3), Map(3), Ptr(3), Uint8(3), Array(2), Bool(2), CanInterface(2), Chan(2), Complex(2), Float(2), Func(2), Int16(2), Int32(2), Int64(2), Int8(2), Pointer(2), Struct(2), Uint16(2), Uint32(2), Uint64(2), Uintptr(2), UnsafePointer(2), CanAddr(1), Complex128(1), Complex64(1), Float32(1), Float64(1), Invalid(1), Name(1), NumField(1) | pendente |
| `go.opentelemetry.io/otel/attribute` | 129 | Len(26), ValueOf(25), Index(18), Interface(12), Value(7), Elem(5), TypeFor(5), Copy(4), String(4), ArrayOf(3), New(3), Array(2), Bool(2), Float(2), Int(2), IsValid(2), Kind(2), Type(2), Addr(1), Field(1), Slice(1) | pendente |
| `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` | 112 | Interface(13), ValueOf(13), Type(12), Elem(10), Kind(10), Set(5), IsNil(4), Index(3), New(3), Ptr(3), Slice(3), TypeFor(3), Implements(2), Key(2), Len(2), Map(2), Value(2), Append(1), Bool(1), Call(1), Convert(1), ConvertibleTo(1), Float32(1), Float64(1), Int(1), Int32(1), Int64(1), MakeMap(1), MakeSlice(1), MapIndex(1), MapKeys(1), SetBytes(1), SetMapIndex(1), String(1), Uint32(1), Uint64(1), Uint8(1) | pendente |
| `github.com/polydawn/refmt/obj/atlas` | 104 | Type(22), Kind(15), Value(13), Elem(5), Interface(4), ValueOf(4), IsNil(3), Name(3), Out(3), Ptr(3), Struct(3), Anonymous(2), AssignableTo(2), Call(2), Field(2), Func(2), NumIn(2), NumOut(2), Pointer(2), TypeOf(2), FieldByName(1), Get(1), In(1), Index(1), Map(1), NumField(1), PkgPath(1), Tag(1) | pendente |
| `github.com/go-logr/logr/funcr` | 103 | Interface(9), Field(5), Kind(5), String(5), Bool(4), Int(4), Pointer(4), Uint(4), Complex(3), Float(3), Key(3), Array(2), Complex128(2), Complex64(2), Float32(2), Float64(2), Int16(2), Int32(2), Int64(2), Int8(2), IsNil(2), Len(2), Map(2), Slice(2), Struct(2), Uint16(2), Uint32(2), Uint64(2), Uint8(2), Uintptr(2), Value(2), Anonymous(1), CanInterface(1), Elem(1), Index(1), Lookup(1), MapRange(1), Name(1), Next(1), NumField(1), PkgPath(1), Tag(1), Type(1), TypeOf(1), ValueOf(1) | pendente |
| `github.com/golang/protobuf/proto` | 102 | Type(17), TypeOf(10), Kind(8), Elem(6), Get(5), Interface(5), Tag(5), Field(3), PtrTo(3), ValueOf(3), Zero(3), Call(2), Func(2), In(2), Map(2), MethodByName(2), Name(2), NumField(2), Ptr(2), String(2), Value(2), AssignableTo(1), Bool(1), Float32(1), Float64(1), Int32(1), Int64(1), IsNil(1), MapOf(1), New(1), Set(1), Struct(1), StructField(1), Uint32(1), Uint64(1) | pendente |
| `github.com/miekg/dns` | 90 | Index(28), Uint(28), Len(7), String(4), Elem(3), ValueOf(3), Field(2), Int(2), Int16(1), Int32(1), Int64(1), Int8(1), Kind(1), NumField(1), Slice(1), Tag(1), Type(1), Uint16(1), Uint32(1), Uint64(1), Uint8(1) | pendente |
| `github.com/rogpeppe/go-internal/fmtsort` | 77 | Value(11), Type(5), Elem(4), Pointer(4), String(4), Bool(3), Int(3), IsNil(3), Uint(3), Complex(2), Field(2), Float(2), Index(2), Kind(2), Len(2), ValueOf(2), Array(1), Chan(1), Complex128(1), Complex64(1), Float32(1), Float64(1), Int16(1), Int32(1), Int64(1), Int8(1), Interface(1), Key(1), Map(1), MapRange(1), Next(1), NumField(1), Ptr(1), Struct(1), Uint16(1), Uint32(1), Uint64(1), Uint8(1), Uintptr(1) | pendente |
| `github.com/cockroachdb/redact/internal/rfmt/fmtsort` | 75 | Value(8), Type(5), Elem(4), Pointer(4), String(4), Bool(3), Int(3), IsNil(3), Uint(3), Complex(2), Field(2), Float(2), Index(2), Kind(2), Len(2), ValueOf(2), Array(1), Chan(1), Complex128(1), Complex64(1), Float32(1), Float64(1), Int16(1), Int32(1), Int64(1), Int8(1), Interface(1), Key(1), Map(1), MapRange(1), Next(1), NumField(1), Ptr(1), Struct(1), Uint16(1), Uint32(1), Uint64(1), Uint8(1), Uintptr(1), UnsafePointer(1) | pendente |
| `github.com/gogo/protobuf/types` | 75 | Interface(19), Indirect(18), IsNil(18), ValueOf(18), Elem(1), New(1) | pendente |
| `github.com/ipfs/go-ipfs-cmds` | 75 | Kind(12), String(6), ValueOf(6), Elem(5), TypeOf(4), Array(3), In(3), Interface(3), Pointer(3), Slice(3), Type(3), TypeFor(3), Implements(2), New(2), Addr(1), Bool(1), Call(1), CanAddr(1), Float64(1), Func(1), Int(1), Int64(1), Invalid(1), NumIn(1), NumOut(1), Out(1), PointerTo(1), Set(1), Uint(1), Uint64(1), Value(1) | pendente |
| `github.com/cockroachdb/pebble/v2/sstable` | 64 | Type(9), Kind(5), Bool(4), Field(4), String(4), Get(3), Index(3), Offset(3), Tag(3), Uint32(3), Uint64(3), ValueOf(3), NumField(2), SetUint(2), Struct(2), Uint(2), Elem(1), FieldByIndex(1), IsZero(1), Name(1), SetBool(1), SetString(1), StructField(1), TypeOf(1), Value(1) | pendente |
| `github.com/ipld/go-ipld-prime/fluent` | 59 | String(6), Interface(4), Kind(4), Elem(3), Len(3), Bool(2), Field(2), Int(2), Type(2), Uint(2), Uint8(2), Value(2), Array(1), Bytes(1), Float(1), Float32(1), Float64(1), Index(1), Int16(1), Int32(1), Int64(1), Int8(1), IsNil(1), Key(1), Map(1), MapIndex(1), MapRange(1), Name(1), Next(1), NumField(1), Ptr(1), Slice(1), Struct(1), Uint16(1), Uint32(1), Uint64(1), ValueOf(1) | pendente |
| `google.golang.org/protobuf/internal/descfmt` | 52 | ValueOf(7), Interface(5), MethodByName(4), Type(4), Name(3), Value(3), Bool(2), Call(2), Elem(2), Int(2), IsNil(2), String(2), Uint(2), In(1), Int16(1), Int32(1), Int64(1), Int8(1), Kind(1), Out(1), Slice(1), Uint16(1), Uint32(1), Uint64(1), Uint8(1) | pendente |
| `github.com/getsentry/sentry-go` | 41 | IsValid(6), Len(4), MethodByName(4), FieldByName(3), Kind(3), Uint(3), Value(3), ValueOf(3), Call(2), Index(2), Slice(2), Uintptr(2), Elem(1), String(1), Struct(1), TypeOf(1) | pendente |
| `github.com/go-logfmt/logfmt` | 39 | IsNil(5), Kind(5), Ptr(5), ValueOf(5), Array(2), Chan(2), Elem(2), Func(2), Interface(2), Map(2), Slice(2), Struct(2), String(1), Type(1), TypeOf(1) | pendente |
| `github.com/ipfs/kubo/config` | 39 | Interface(7), CanInterface(3), Elem(3), Type(3), Field(2), Kind(2), Len(2), Zero(2), Array(1), Index(1), IsNil(1), IsValid(1), Key(1), Map(1), MapRange(1), Name(1), Next(1), NumField(1), Pointer(1), Slice(1), Struct(1), Value(1), ValueOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/host/eventbus` | 35 | Type(18), TypeOf(7), Elem(3), String(3), Kind(2), Pointer(2) | pendente |
| `google.golang.org/protobuf/internal/encoding/tag` | 25 | Kind(7), Int32(3), Int64(3), Uint32(2), Uint64(2), Bool(1), Elem(1), Float32(1), Float64(1), Slice(1), String(1), Type(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/internal/filetype` | 22 | TypeOf(19), Type(2), SliceOf(1) | pendente |
| `go.opentelemetry.io/otel/sdk/internal/attrnorm` | 18 | Type(4), Array(2), Elem(2), Kind(2), Len(2), TypeFor(2), ValueOf(2), Index(1), Interface(1) | pendente |
| `go.opentelemetry.io/otel/sdk/metric/internal/attrnorm` | 18 | Type(4), Array(2), Elem(2), Kind(2), Len(2), TypeFor(2), ValueOf(2), Index(1), Interface(1) | pendente |
| `github.com/cockroachdb/errors/errutil` | 17 | Elem(4), Kind(2), TypeOf(2), ValueOf(2), AssignableTo(1), Implements(1), Interface(1), IsNil(1), Ptr(1), Set(1), Type(1) | pendente |
| `go.opentelemetry.io/otel/attribute/internal` | 17 | ValueOf(3), Copy(2), Elem(2), TypeFor(2), Array(1), ArrayOf(1), Interface(1), IsValid(1), Kind(1), Len(1), New(1), Type(1) | pendente |
| `github.com/cockroachdb/errors/markers` | 16 | TypeOf(6), Comparable(2), Elem(2), Kind(2), Implements(1), Interface(1), Ptr(1), Type(1) | pendente |
| `github.com/huin/goupnp/soap` | 16 | Type(3), Field(2), Kind(2), Get(1), Indirect(1), Interface(1), Name(1), NumField(1), String(1), Struct(1), Tag(1), ValueOf(1) | pendente |
| `go.uber.org/fx/internal/lifecycle` | 16 | Convert(4), Interface(4), TypeOf(4), CanConvert(3), ValueOf(1) | pendente |
| `golang.org/x/crypto/cryptobyte` | 16 | ValueOf(6), Elem(5), OverflowInt(1), OverflowUint(1), Set(1), SetInt(1), SetUint(1) | pendente |
| `go.opentelemetry.io/otel/internal/global` | 15 | TypeFor(14), Type(1) | pendente |
| `github.com/cockroachdb/errors/errbase` | 13 | String(2), TypeOf(2), Array(1), Chan(1), Elem(1), Kind(1), Map(1), PkgPath(1), Ptr(1), Slice(1), Type(1) | pendente |
| `github.com/ipld/go-ipld-prime/schema/dsl` | 13 | ValueOf(3), FieldByName(2), Set(2), Append(1), Elem(1), IsNil(1), MakeMap(1), SetMapIndex(1), Type(1) | pendente |
| `github.com/ceramicnetwork/go-dag-jose/dagjose` | 12 | Kind(4), Map(3), ValueOf(3), Slice(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p` | 12 | IsVariadic(2), NumIn(2), Type(2), ValueOf(2), AssignableTo(1), Elem(1), In(1), TypeOf(1) | pendente |
| `go.uber.org/dig/internal/dot` | 11 | String(6), Type(4), Elem(1) | pendente |
| `github.com/ipfs/boxo/pinning/remote/client/openapi` | 10 | Kind(2), Slice(2), TypeOf(2), Map(1), Pointer(1), String(1), Struct(1) | pendente |
| `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp/internal/semconv` | 9 | Name(2), PkgPath(2), Elem(1), Kind(1), Pointer(1), String(1), TypeOf(1) | pendente |
| `go.uber.org/zap/zapcore` | 9 | IsNil(2), Kind(2), Ptr(2), ValueOf(2), DeepEqual(1) | pendente |
| `github.com/go-kit/log` | 8 | IsNil(2), Kind(2), Ptr(2), ValueOf(2) | pendente |
| `github.com/libp2p/go-libp2p/core/record` | 8 | Type(2), Elem(1), Interface(1), Kind(1), New(1), Pointer(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/otel/sdk/metric` | 8 | Pointer(4), ValueOf(4) | pendente |
| `golang.org/x/crypto/internal/alias` | 8 | Pointer(4), ValueOf(4) | pendente |
| `github.com/cockroachdb/redact` | 7 | Index(1), Interface(1), Kind(1), Len(1), Slice(1), Type(1), ValueOf(1) | pendente |
| `github.com/hanwen/go-fuse/v2/fuse` | 7 | Type(2), ValueOf(2), Interface(1), NewAt(1), Size(1) | pendente |
| `github.com/ipld/go-ipld-prime` | 7 | ValueOf(3), Elem(2), IsNil(1), Set(1) | pendente |
| `github.com/libp2p/go-libp2p-routing-helpers` | 7 | SelectCase(2), Interface(1), Select(1), SelectRecv(1), TypeOf(1), ValueOf(1) | pendente |
| `github.com/cespare/xxhash` | 6 | Data(2), Cap(1), Len(1), SliceHeader(1), StringHeader(1) | pendente |
| `github.com/ipfs/go-ipfs-cmds/http` | 6 | Elem(1), Interface(1), Kind(1), New(1), Pointer(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/auto/sdk` | 6 | Name(2), PkgPath(2), String(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/otel/sdk/trace` | 6 | Name(2), PkgPath(2), String(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/otel/semconv/v1.41.0` | 6 | TypeOf(3), Name(1), PkgPath(1), String(1) | pendente |
| `go.opentelemetry.io/otel/semconv/v1.43.0` | 6 | TypeOf(3), Name(1), PkgPath(1), String(1) | pendente |
| `go.opentelemetry.io/otel/trace` | 6 | Name(2), PkgPath(2), String(1), TypeOf(1) | pendente |
| `go.uber.org/fx/internal/fxlog` | 6 | Elem(2), Name(2), TypeOf(2) | pendente |
| `github.com/dunglas/httpsfv` | 5 | ValueOf(2), Int(1), TypeOf(1), Uint(1) | pendente |
| `github.com/opentracing/opentracing-go/log` | 5 | ValueOf(2), IsNil(1), Kind(1), Ptr(1) | pendente |
| `github.com/pion/ice/v4` | 5 | ValueOf(2), IsNil(1), Kind(1), Ptr(1) | pendente |
| `golang.org/x/sys/execabs` | 5 | Addr(1), Elem(1), FieldByName(1), Pointer(1), ValueOf(1) | pendente |
| `google.golang.org/grpc` | 5 | TypeOf(2), DeepEqual(1), Elem(1), Implements(1) | pendente |
| `github.com/cockroachdb/pebble/v2/internal/manifest` | 4 | Pointer(2), ValueOf(2) | pendente |
| `github.com/gogo/protobuf/protoc-gen-gogo/descriptor` | 4 | Indirect(1), Interface(1), IsNil(1), ValueOf(1) | pendente |
| `github.com/ipfs/boxo/routing/http/contentrouter` | 4 | String(2), TypeOf(2) | pendente |
| `github.com/ipfs/boxo/routing/http/filters` | 4 | String(2), TypeFor(2) | pendente |
| `github.com/ipfs/go-datastore` | 4 | TypeOf(2), Elem(1), Implements(1) | pendente |
| `github.com/libp2p/go-libp2p-pubsub/pb` | 4 | PkgPath(2), TypeOf(2) | pendente |
| `github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/pb` | 4 | PkgPath(2), TypeOf(2) | pendente |
| `github.com/quic-go/quic-go` | 4 | Elem(1), Name(1), Type(1), ValueOf(1) | pendente |
| `go.opentelemetry.io/otel/semconv/v1.37.0` | 4 | Name(1), PkgPath(1), String(1), TypeOf(1) | pendente |
| `go.uber.org/fx/internal/fxreflect` | 4 | Func(1), Kind(1), Pointer(1), ValueOf(1) | pendente |
| `golang.org/x/net/http2` | 4 | Kind(1), Uint(1), Uintptr(1), ValueOf(1) | pendente |
| `google.golang.org/protobuf/internal/filedesc` | 4 | Elem(1), Interface(1), New(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/bitswap/network/httpnet` | 3 | PkgPath(1), Type(1), ValueOf(1) | pendente |
| `github.com/ipfs/boxo/routing/http/client` | 3 | PkgPath(1), Type(1), ValueOf(1) | pendente |
| `github.com/ipfs/go-ipfs-cmds/cli` | 3 | Kind(2), Invalid(1) | pendente |
| `github.com/ipshipyard/p2p-forge/client` | 3 | PkgPath(1), Type(1), ValueOf(1) | pendente |
| `google.golang.org/protobuf/proto` | 3 | Kind(1), Ptr(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/bitswap/message/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/filestore/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/ipld/merkledag/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/ipld/unixfs/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/ipfs/boxo/ipns/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/ipfs/go-log/v2` | 2 | DeepEqual(2) | pendente |
| `github.com/ipfs/kubo/core` | 2 | Comparable(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p-kad-dht/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p-record/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/core/crypto/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/core/peer/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/core/record/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/host/autonat/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/protocol/autonatv2/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/protocol/holepunch/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/protocol/identify/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/security/insecure/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/security/noise/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/libp2p/go-libp2p/p2p/transport/webrtc/pb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/prometheus/client_model/go` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `go.opencensus.io/stats/view` | 2 | DeepEqual(2) | pendente |
| `go.opentelemetry.io/proto/otlp/collector/trace/v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/proto/otlp/common/v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/proto/otlp/resource/v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `go.opentelemetry.io/proto/otlp/trace/v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `go.uber.org/dig/internal/digreflect` | 2 | Pointer(1), ValueOf(1) | pendente |
| `golang.org/x/xerrors` | 2 | String(1), TypeOf(1) | pendente |
| `google.golang.org/genproto/googleapis/api/httpbody` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/genproto/googleapis/rpc/errdetails` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/genproto/googleapis/rpc/status` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/grpc/binarylog/grpc_binarylog_v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/grpc/health/grpc_health_v1` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/descriptorpb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/gofeaturespb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/anypb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/durationpb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/fieldmaskpb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/structpb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/timestamppb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `google.golang.org/protobuf/types/known/wrapperspb` | 2 | PkgPath(1), TypeOf(1) | pendente |
| `github.com/cockroachdb/errors/safedetails` | 1 | TypeOf(1) | pendente |
| `github.com/cockroachdb/pebble/v2/internal/keyspan` | 1 | DeepEqual(1) | pendente |
| `github.com/elgris/jsondiff` | 1 | DeepEqual(1) | pendente |
| `github.com/ipfs/kubo/repo/fsrepo/migrations/common` | 1 | DeepEqual(1) | pendente |
| `github.com/libp2p/go-libp2p/core/event` | 1 | Type(1) | pendente |
| `google.golang.org/protobuf/reflect/protoreflect` | 1 | DeepEqual(1) | pendente |
