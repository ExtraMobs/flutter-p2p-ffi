# Interface genérica (`type Key[K any] interface{...}`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Interfaces com parâmetros de tipo são recusadas (`generico:interface`). No grafo aparecem como
constraints autorreferentes (`K Key[K]`, `N NodeID[K]`) e como interfaces de cache
(`LRUCache[K, V]`). Para virar `abstract mixin class Key<K>` o tipo que implementa precisa declarar
`implements Key<k8>` por instanciação, mas o goast só lista no `implements` interfaces não genéricas
(`dumpImplements` pula `TypeParams().Len() > 0`), e o bound `K extends Key<K>` do Dart exige esse
`implements`.

## Prova

```go
package main

import "fmt"

type Key[K any] interface {
	BitLen() int
	Xor(other K) K
}

type k8 uint8

func (k k8) BitLen() int { return 8 }
func (k k8) Xor(o k8) k8 { return k ^ o }

func Distance[K Key[K]](a, b K) int { return a.Xor(b).BitLen() }

func main() { fmt.Println(Distance(k8(3), k8(5))) }
```

```text
$ go run .
8

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
repro: não suportado [generico:interface]: tipo genérico sobre interface em main.go:5:6
```

No grafo do kubo (dumps de `.g2d-cache`): `github.com/ipfs/go-libdht/kad` e
`github.com/probe-lab/go-libdht/kad` (kad.go:16, 47, 59: `Key[K]`, `NodeID[K]`, `RoutingTable[K, N]`),
`github.com/hashicorp/golang-lru/v2/simplelru` (lru_interface.go:8: `LRUCache[K, V]`).

## Critério de pronto

- goast: `implements` com as instanciações de interfaces genéricas satisfeitas pelo tipo (as
  instâncias que aparecem no pacote, como `Key[k8]`), com `schemaVersion` novo se o formato mudar.
- g2d: `abstract mixin class Key<K>`; bound `K extends Key<K>`; fixture e2e com constraint
  autorreferente e interface genérica usada como valor.
