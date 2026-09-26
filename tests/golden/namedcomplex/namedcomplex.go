// Tipos nomeados sobre complex128/complex64: constantes, operadores, método,
// conversões, map com chave complex (ordem do %v), divisão por zero IEEE e
// os builtins real/imag/complex.
package main

import "fmt"

type Z complex128

type Z64 complex64

type P complex128 // sem métodos: %v do subjacente

func (z Z) Conj() Z { return Z(complex(real(z), -imag(z))) }

func (z Z) String() string { return fmt.Sprintf("Z%v", complex128(z)) }

func main() {
	var z Z = 1 + 2i
	fmt.Println(z*z, z+z, z-1, -z, z/(1+1i))
	fmt.Println(z.Conj(), z == Z(complex(1, 2)), z != 0)
	c := complex128(z)
	fmt.Println(c, real(c), imag(c))
	var w Z64 = Z64(z)
	fmt.Println(complex128(w)*complex128(w), w*w)
	x, y := 3.0, -4.0
	fmt.Println(complex(x, y), real(z)+imag(z))
	m := map[Z]int{z: 1, 2: 2}
	fmt.Println(m[1+2i], m[2], len(m))
	zs := []Z{1, 1i}
	zs = append(zs, z)
	fmt.Println(zs, fmt.Sprint(zs[2]))
	mp := map[P]string{2 + 1i: "b", 1 + 5i: "a", 2 - 1i: "c"}
	var zero P
	fmt.Println(mp, P(z)/zero, zero/zero)
	fmt.Printf("%v %v\n", zero, []P{zero, P(w)})
}
