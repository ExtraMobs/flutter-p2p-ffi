# Funções transcendentais do `math` (Exp, Log, Pow, Log2, Lgamma, Sin...)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

O shim `math` já tem as funções de resultado único (Sqrt, Floor, Ceil, Trunc, Abs, Max, Min, Inf,
IsInf, IsNaN, Signbit, Copysign, Float32/64bits/frombits, NaN), com oráculo bit a bit. Faltam as
transcendentais: `Exp`, `Log`, `Pow`, `Log2`, `Log10`, `Log1p`, `Expm1`, `Lgamma`, `Gamma`,
`Sin`, `Cos`, `Tan`, `Atan`, `Sincos`, `Erfc`, `Cbrt`, `Frexp`, `Ldexp`, `Modf`, `Round`...

O `dart:math` não serve (libm da VM × `Math.*` do JS: sem garantia de bits iguais). Portar o código
Go puro (fdlibm) daria o mesmo resultado em toda plataforma Dart, **mas não o do Go no amd64**: lá
`Exp` e `Log` são assembly (`exp_amd64.s`, `log_amd64.s`; `Pow` e `Log2` chamam os dois), com outro
algoritmo, e o `exp_amd64.s` ainda escolhe FMA pela CPU. O resultado de referência do Go depende da
arquitetura (e da CPU).

Bloqueia na fronteira: `github.com/klauspost/compress` (Pow, Log2), `gonum.org/v1/gonum/mathext/internal/gonum`
(Exp, Lgamma), `github.com/cockroachdb/pebble/v2/internal/humanize` (Log, Pow).

## Prova

Cópia de `exp`/`log` puros do `GOROOT/src/math` (Go 1.26.5) comparada com `math.Exp`/`math.Log` no
amd64, 2 milhões de entradas aleatórias:

```go
for i := 0; i < 2000000; i++ {
	x := math.Float64frombits(r.Uint64())
	if x != x { continue }
	y := (r.Float64() - 0.5) * 1400
	if math.Float64bits(math.Exp(y)) != math.Float64bits(pexp(y)) { de++ }
	ax := math.Abs(x)
	if math.Float64bits(math.Log(ax)) != math.Float64bits(plog(ax)) { dl++ }
}
```

```text
$ GOTOOLCHAIN=go1.26.5 go run .      (windows/amd64)
exp diffs 320730 log diffs 971
```

```text
$ ls $(go env GOROOT)/src/math/*amd64*
dim_amd64.s  exp_amd64.go  exp_amd64.s  floor_amd64.s  hypot_amd64.s  log_amd64.s
```

## Critério de pronto

- Decidir o alvo: (a) porta do Go puro (igual em toda plataforma Dart e ao Go fora de
  amd64/arm64/s390x), documentando a diferença de ulp para o `go run` amd64; ou (b) porta dos
  algoritmos do assembly amd64 sem FMA (bate com o amd64 sem FMA). Registrar em `docs/mapping-spec.md`.
- Oráculo Go nos testes do golib_dart (bits exatos contra o alvo escolhido); fixture e2e com valores
  que não caiam na divergência, se o alvo for (a).
- As funções sem transcendental (`Frexp`, `Ldexp`, `Modf`, `Round`, `RoundToEven`, `Nextafter`) podem
  vir antes, com oráculo exato.
