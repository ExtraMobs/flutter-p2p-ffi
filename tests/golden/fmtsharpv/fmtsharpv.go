// `%#v` (sintaxe Go do valor): básicos, structs (com campo não exportado e
// anônima), ponteiro para struct (topo, nulo e aninhado num campo), slices,
// arrays, `[]byte`/`[N]byte` (a exceção do Go: `[]byte` no topo tem grafia
// fixa, `[N]byte` não), maps, interface nula em contêiner, `GoStringer`,
// erros do runtime, tipo nomeado sobre slice e ponteiro nomeado com métodos
// via interface (dinâmico). `%#x`/`%#o`/`%#q`/`# em float`/`%#q` de runa.
//
// Endereço de ponteiro não é reproduzível: `shape` reduz `0x<hex>` para
// `ADDR` antes de imprimir (mesma ideia do golden `fmtaddr`).
package main

import (
	"errors"
	"fmt"
	"strings"
)

type P struct {
	X, Y int
	z    int
}

type Q struct {
	Ptr *P
}

type Ids []string

type Counter int

func (c *Counter) Inc() { *c++ }

type T int

func (t T) GoString() string { return fmt.Sprintf("T(%d)", int(t)) }

func isHex(b byte) bool {
	return b >= '0' && b <= '9' || b >= 'a' && b <= 'f'
}

// shape substitui cada `0x<hex>` por `ADDR`.
func shape(s string) string {
	for {
		i := strings.Index(s, "0x")
		if i < 0 {
			return s
		}
		j := i + 2
		for j < len(s) && isHex(s[j]) {
			j++
		}
		s = s[:i] + "ADDR" + s[j:]
	}
}

func main() {
	// básicos: int, uint (hex), bool, string (aspas), float.
	fmt.Printf("%#v %#v %#v %#v %#v\n", 5, uint8(5), true, "hi\n", 3.5)
	// %#x/%#o de inteiro, %#q de string (backquote) e de runa (sem efeito),
	// # em float (%#g, %#.3e, %#.0f).
	fmt.Printf("%#x %#o %#q %#q %#g %#.3e %#.0f\n", 255, 8, "hi", 'a', 3.5, 3.5, 3.0)

	// struct nomeada (campo não exportado incluso) e struct anônima.
	fmt.Printf("%#v\n", P{1, 2, 3})
	fmt.Printf("%#v\n", struct{ X int }{X: 1})
	// ponteiro para struct aninhado num campo: não nulo (endereço) e nulo.
	fmt.Println(shape(fmt.Sprintf("%#v", Q{Ptr: &P{1, 2, 3}})))
	fmt.Printf("%#v\n", Q{})

	// ponteiro para struct no nível de topo: não nulo (&...) e nulo.
	p := &P{1, 2, 3}
	fmt.Println(shape(fmt.Sprintf("%#v", p)))
	var np *P
	fmt.Printf("%#v\n", np)

	// slices, arrays, []byte/[N]byte, slice de slice, nil, tipo nomeado.
	fmt.Printf("%#v\n", []int{1, 2})
	fmt.Printf("%#v\n", []byte{1, 2})
	var ns []int
	fmt.Printf("%#v\n", ns)
	fmt.Printf("%#v\n", [2]int{1, 2})
	fmt.Printf("%#v\n", [2]byte{1, 2})
	fmt.Printf("%#v\n", [][]int{{1, 2}, {3}})
	fmt.Printf("%#v\n", Ids{"a", "b"})

	// maps: com entradas (chaves ordenadas) e nil.
	fmt.Printf("%#v\n", map[string]int{"b": 2, "a": 1})
	var nm map[string]int
	fmt.Printf("%#v\n", nm)

	// interface nula dentro de um contêiner (no topo continua <nil>).
	fmt.Printf("%#v\n", []interface{}{nil, 1, "a"})
	var i interface{}
	fmt.Printf("%#v\n", i)

	// GoStringer: chamado em vez da sintaxe estrutural.
	fmt.Printf("%#v\n", T(5))

	// erros do runtime: errors.New, fmt.Errorf com %w, errors.Join.
	inner := errors.New("inner")
	fmt.Printf("%#v\n", inner)
	fmt.Println(shape(fmt.Sprintf("%#v", fmt.Errorf("outer: %w", inner))))
	fmt.Println(shape(fmt.Sprintf("%#v", errors.Join(inner, errors.New("x")))))

	// ponteiro nomeado com métodos (N$Ptr) via interface, tipo estático
	// desconhecido na transpilação: não nulo e nulo.
	var c Counter = 5
	var any1 interface{} = &c
	fmt.Println(shape(fmt.Sprintf("%#v", any1)))
	var nilCounter *Counter
	var any2 interface{} = nilCounter
	fmt.Printf("%#v\n", any2)
}
