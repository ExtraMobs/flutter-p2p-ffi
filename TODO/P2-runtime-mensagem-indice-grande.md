# Mensagem de índice fora do intervalo com valor ≥ 2⁵³ / ≥ 2⁶³

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

`toInt()` de `uint64` ≥ 2⁶³ vira negativo na VM e valores acima de 2⁵³ arredondam no JS; a mensagem do panic diverge do Go (o panic em si acontece corretamente).

## Prova

```go
package main

import "fmt"

func try(f func()) {
	defer func() { fmt.Println(recover()) }()
	f()
}

func main() {
	s := []int{1}
	var u uint64 = 1 << 63
	var i int64 = 1<<60 + 1
	try(func() { _ = s[u] })
	try(func() { _ = s[i] })
}
```

```text
$ go run main.go
runtime error: index out of range [9223372036854775808] with length 1
runtime error: index out of range [1152921504606846977] with length 1
$ dart run (VM)
runtime error: index out of range [-9223372036854775808] with length 1
runtime error: index out of range [1152921504606846977] with length 1
$ node (dart2js)
runtime error: index out of range [9223372036854776000] with length 1
runtime error: index out of range [1152921504606847000] with length 1
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Caminho provável: checar o limite com o inteiro Go (`$hi`/`$lo`) antes do `toInt()` e formatar a mensagem pelo `toString()` dele.
