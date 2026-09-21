# boilerplate — fixed_types.Golang

Byte-backed runtime representations of Go primitive semantics. This is a shared
Dart adaptation, not an upstream Go module and not a Go compiler.

```dart
import 'package:boilerplate/fixed_types/golang.dart' as Golang;

final maximum = Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one);
final zero = maximum + Golang.Uint64(1);
```

Dart has no nested type namespaces, so the library path plus the `Golang` import
prefix implement the logical schema `fixed_types.Golang.<type>` without dynamic
factories.

Authority: the [Go specification](https://go.dev/ref/spec), sections *Numeric
types*, *Integer operators*, *Integer overflow* and *Conversions between numeric
types*. Differential tests were evaluated against Go 1.25.7 windows/amd64.

## Types available

Signed and unsigned integers of 8, 16, 32 and 64 bits; `Int` and `Uint`
(64-bit architecture width); `Uintptr`; `Byte` (alias of `Uint8`); `Rune`
(alias of `Int32`); `Bool`; `Float32`; `Float64`; `Complex64`; `Complex128`;
and `String`.

## Semantics

- **Integers** hold one, two, four or eight private bytes according to width.
  `BigInt` is used only for exact intermediate arithmetic. Runtime conversions
  truncate; these constructors do not model Go's compile-time constant
  representability checks. Dart `~/` represents Go's integer `/`, `~`
  represents unary `^`, and `andNot` represents `&^`. Negative shifts raise
  `ArgumentError`; division by zero raises `IntegerDivisionByZeroException`,
  adapting Go's runtime panics. Internal little-endian bytes do not define
  protocol serialization.
- **Bool** stores one private byte (not an ABI guarantee). `not`,
  `and(() => rhs)` and `or(() => rhs)` adapt Go's logical operators, since Dart
  cannot overload `!`, `&&` or `||`; the deferred right-hand side preserves
  short-circuit evaluation. Dart conditionals require explicit `toBool()`, with
  no numeric truthiness.
- **Float32** stores IEEE 754 binary32 in four bytes; arithmetic uses binary64
  intermediates followed by explicit binary32 conversion. **Float64** holds
  eight bytes and uses Dart binary64 arithmetic. Go permits
  implementation-dependent behavior for floating division by zero; this
  implementation follows IEEE infinities/NaN.
- **String** preserves arbitrary bytes, including invalid UTF-8, so the value
  keeps a byte representation rather than Dart text. Indexing, length and
  slicing use byte offsets; `toDart` rejects invalid UTF-8.
  `fromCodePoint(BigInt)` implements Go's integer-to-string conversion,
  replacing invalid Unicode scalars with U+FFFD after validating the exact
  value before narrowing. `fromRune` takes an already-converted `Int32`/`Rune`,
  preserving conversion order. Slices copy their selected bytes so a small
  slice does not retain a large parent buffer. Application/UI text need not
  become a Go string unless it crosses a port boundary where Go byte semantics
  matter.

## Verification

Run `dart test` and `dart analyze` from this package; the tests require Go on
`PATH`. `test/go_integer_vectors.go` generates comparison values during the run
— a reusable test oracle, not a reference clone or downloaded fixture.

Go oracles check 324 outputs each for `Float32` (including subnormals,
overflow, signed zero and infinity) and `Float64` (including the smallest
subnormal, the maximum finite value and the 53-bit precision boundary). NaNs
are compared by classification, not payload; compiler expression fusion is not
claimed equivalent. Integer/float conversions
(`test/integer_conversion_test.dart`, `test/float_conversion_test.dart`,
`test/integer_float_test.dart`) and the complex types
(`test/go_complex_parity_test.dart`) are checked against Go oracles as well.

The focused uint64/string tests also run as JavaScript with
`dart test --platform node test/uint64_test.dart test/string_test.dart`. That
is a Node proof, not a browser/Wasm or full cross-runtime audit.

## Known gaps

Rune iteration and rune-slice conversion are not implemented, and IPLD
integration is pending. The full conversion matrix across all type pairs,
arbitrary-width shift operands, complete Web validation and consumer migration
remain incomplete. Do not claim complete Go type-system parity, and do not
remove protocol validation on the strength of these wrappers alone.
