# Fatiar array fora do limite dá a mensagem de slice

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

`GoArray.slice` delega para `Slice.view(...).slice`, então o panic diz "with capacity"; para array
o Go diz "with length".

## Prova

```go
package main

import "fmt"

func main() {
	defer func() { fmt.Println(recover()) }()
	arr := [3]int{}
	i := 5
	_ = arr[1:i]
}
```

```text
go run:   runtime error: slice bounds out of range [:5] with length 3
dart run: runtime error: slice bounds out of range [:5] with capacity 3
```

## Critério de pronto

- Mensagem igual ao Go; caso no fixture de erros de runtime.
