# boilerplate — fixed_types.Golang

Byte-backed runtime representations for Go primitive semantics. This is a
shared Dart adaptation, not an upstream Go module or a Go compiler.

```dart
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

final maximum = Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one);
final zero = maximum + Golang.Uint64(1);
```

Dart has no nested type namespaces. The library path and `Golang` import
prefix implement the logical schema `fixed_types.Golang.<type>` without
dynamic factories. Types currently available: signed and unsigned integers
of 8, 16, 32 and 64 bits, `Int` (64-bit architecture int), `Uint` (64-bit
architecture uint), `Uintptr` (64-bit pointer integer), `Byte` (alias of `Uint8`),
`Rune` (alias of `Int32`), `Bool`, `Float32`, `Float64`, `Complex64`, `Complex128`,
and `String`.
Bool stores one private byte (not an ABI guarantee). `not`, `and(() => rhs)`
and `or(() => rhs)` adapt Go logical operators because Dart cannot overload
`!`, `&&` or `||`; deferred RHS preserves short-circuit evaluation. Native Dart
conditionals require explicit `toBool()`, with no numeric truthiness conversion.
String preserves arbitrary bytes; indexing, length and slicing use byte offsets.
Explicit `toDart` conversion rejects invalid UTF-8. `fromCodePoint(BigInt)`
implements Go integer-to-string conversion, replacing invalid Unicode scalars
with U+FFFD after validating the exact value before narrowing. `fromRune`
receives an already-converted Int32/Rune, preserving conversion order. Rune iteration
and rune-slice conversion are not yet implemented; IPLD integration is pending.

Authority: [official Go specification](https://go.dev/ref/spec), sections
Numeric types, Integer operators, Integer overflow and Conversions between
numeric types. The local specification and differential tests were evaluated
with Go 1.25.7 windows/amd64.

The integer values hold one, two, four or eight private bytes according to their width.
BigInt is used only for exact intermediate
arithmetic. Runtime integer conversions truncate; these constructors do not
model Go compile-time constant representability checks. Internal little-endian
bytes do not define protocol serialization. Dart `~/` represents Go integer
`/`, `~` represents unary `^`, and `andNot` represents `&^`. Negative shifts
raise ArgumentError; integer division by zero raises
IntegerDivisionByZeroException, adapting Go runtime panics.

Run `dart test` (requires Go on PATH) and `dart analyze` from this package.
`test/go_integer_vectors.go` generates the comparison values during tests;
it is a reusable test oracle, not a reference clone or downloaded fixture.

Incomplete: full conversion matrix across all types, arbitrary-width shift
operands, complete Web validation and consumer migration. Do not claim
complete Go type-system parity or remove protocol validation based solely on
these wrappers.

The focused uint64/string tests also run as JavaScript with
`dart test --platform node test/uint64_test.dart test/string_test.dart`.
That is a Node JavaScript proof, not a browser/Wasm or full cross-runtime audit.

Float32 stores IEEE 754 binary32 in four bytes. Arithmetic uses Dart binary64
intermediates followed by explicit binary32 conversion. A Go oracle checks 324
outputs including subnormal values, overflow, signed zero and infinity; NaNs
are compared by classification, not payload. This is not exhaustive proof of
all rounding cases or Go compiler FMA choices. Integer/float conversions
(`test/integer_conversion_test.dart`, `test/float_conversion_test.dart`,
`test/integer_float_test.dart`) and the complex types (`Complex64`,
`Complex128`, `test/go_complex_parity_test.dart`) are implemented and checked
against Go oracles; the full conversion matrix across all type pairs is still
incomplete, as noted above. Go permits implementation-dependent
behavior for floating division by zero; this implementation follows IEEE
infinities/NaN. It does not simulate compiler constant evaluation.

Float64 holds eight bytes and uses Dart binary64 arithmetic. Its separate Go
oracle compares 324 arithmetic results at binary64 precision, including the
smallest subnormal, maximum finite value and the 53-bit precision boundary.
NaN payloads and compiler expression fusion are not claimed equivalent.

## String storage and memory

Go strings permit arbitrary bytes, including invalid UTF-8. A Dart text String
alone cannot preserve that domain using ordinary UTF-8 conversion. Therefore
the current Go value keeps one byte representation, not both bytes and text.
Application/UI text need not become a Go string unless it crosses a port boundary
where Go byte semantics matter.

Bytes are not universally smaller: ASCII is one UTF-8 byte per character, é is
two, CJK commonly three, and supplementary characters four. Dart runtime string
storage, object headers and allocator behavior vary; UTF-16 code-unit count is
not a measurement of retained heap. No blanket memory-saving percentage is
claimed. Text-backed or hybrid storage may benefit text-heavy workloads, but
must retain invalid input bytes, byte indexing, sorting and slicing semantics.
It needs workload/heap measurements before adding representation flags or caches.

The previous concatenation built a growable list, converted it to Uint8List,
then copied it again through the public constructor. It now allocates one
destination Uint8List and copies each operand into it. A private ownership
constructor avoids the redundant copy; public inputs and outputs still copy.
Slices deliberately copy their selected bytes: a tiny slice should not retain
a large parent buffer. No persistent decoded-text cache is introduced.
