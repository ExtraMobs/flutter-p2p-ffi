# Statements válidos que derrubam o g2d ou geram Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Quatro construções comuns em Go saem sem `Unsupported` e quebram a emissão do pacote inteiro
(`g2d/behaviors/stmts.py`, `g2d/services/operands.py`):

- rótulo que é palavra reservada do Dart (`in:`, `new:`): o nome sai cru e o `dart format` falha;
- `switch x {}` e `switch i.(type) {}` vazios: `TypeError: 'NoneType' object is not iterable` no
  Python (`s["body"]["list"]` é `None`);
- variável do type switch atribuída dentro do case: é declarada `final`;
- alvo entre parênteses (`(*p)++`, `(x) += 3`): `lvalue` não tira o parêntese e o `dart format`
  falha (`Illegal assignment to non-assignable expression`).

## Prova

```go
package main

import "fmt"

func main() {
	x := 1
	p := &x
	(*p)++
	switch x {
	}
	var i any = x
	switch v := i.(type) {
	case int:
		v++
		fmt.Println("int", v)
	}
in:
	for k := range 3 {
		if k == 1 {
			break in
		}
		fmt.Println(k)
	}
}
```

```text
go run: int 3 / 0
g2d (cada caso isolado):
  RuntimeError: dart format falhou: ... (p!.value) += Golang.Int(1);                             (parênteses; rótulo `in:` idem)
  TypeError: 'NoneType' object is not iterable                                                  (switch vazio)
  error - The final variable 'v' can only be set once                                           (type switch)
```

## Critério de pronto

- Os quatro casos emitem Dart válido e igual ao Go.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
