// Package main exercita a tipagem fixa: larguras de inteiro, float32/64,
// complex, strings como bytes e as adaptações do int nativo.
package main

import (
	"fmt"
	"math"
)

const big uint64 = math.MaxUint64

var minInt64 int64 = math.MinInt64

func half(x float32) float32 { return x / 2 }

func main() {
	// int/int64 nativos: overflow, divisão e resto truncados, shifts largos.
	a := int64(math.MaxInt64)
	a++
	neg := -7
	fmt.Println(a, minInt64/int64(neg/7), neg/2, neg%3, 7%-3, 6&^3, ^5)
	var s uint = 70
	one := 1
	fmt.Println(one<<63, one<<s, -8>>s, 8>>2)

	// Inteiros de largura fixa: wraparound e operações.
	var i8 int8 = 127
	i8++
	var u8 uint8 = 0
	u8--
	u8 += 10
	var i32 int32 = -7
	fmt.Println(i8, u8, i32/2, i32%3, -i32, ^u8, u8&^0x0f, i32<<28, u8>>1)
	u := big
	u++
	fmt.Println(big, u, big/3, big%10, big>>60)
	var u16 uint16 = 65535
	u16 *= u16
	r := 'é'
	fmt.Println(u16, r, r+1, i8 == -128, u8 < 20)

	// Conversões entre larguras, com floats e com string.
	n := 300
	f := 3.99
	fmt.Println(int8(n), uint8(n), int32(u8), int(u8), uint64(neg), int(u-2))
	fmt.Println(int(f), int8(-f), uint8(f*100), float64(n)/7, float32(f))
	fmt.Println(string(rune(65)), string(r), float64(u8)+0.5, uint32(n)*20000000)

	// float32/float64 e complex.
	var f32 float32 = 0.1
	f64 := 0.1
	fmt.Println(f32, f64, f32*3, f64*3, half(1), float64(f32), 1e21, -0.0)
	zero := 0.0
	fmt.Println(1/zero, -1/zero, zero/zero == zero/zero, math.MaxFloat32, float32(1)/3)
	c := complex(1.5, -2)
	fmt.Println(c, c*c, c/complex(0, 1), complex64(c))

	// Strings são bytes: len, índice, slicing, comparação, concatenação.
	str := "olá, mundo"
	bad := "a\xffb"
	fmt.Println(len(str), str[2], str[3], str[5:], str[:3] < "olb", len(bad), bad[1])
	fmt.Println(str+"!", bad, str == "olá, mundo", str[0:0] == "")

	// Chaves de map float: NaN nunca é encontrado; +0 e -0 são a mesma chave.
	m := map[float64]int{}
	nan := math.NaN()
	m[nan] = 1
	m[nan] = 2
	m[0.0] = 3
	m[math.Copysign(0, -1)] = 4
	fmt.Println(len(m), m[nan], m[0])
	ms := map[string]uint8{"x": 250}
	ms["x"] += 10
	ms["y"]++
	fmt.Println(ms["x"], ms["y"], len(ms))

	// 64 bits em duas palavras: carries, produtos acima de 2^53, shifts
	// entre palavras, divisão fora de ±2^53; contagens e índices de todo tipo.
	x := int64(1)<<32 - 1
	y := uint64(1)<<63 + 5
	fmt.Println(x+1, x*x, -x*x, y*3, y/7, y%7, int64(y)/3, int64(y)%1000)
	fmt.Println(minInt64/-1, minInt64%-1, x<<31, x<<32, x<<33, y>>31, y>>32, y>>33, int64(y)>>40)
	var sh uint64 = 1 << 40
	var c8 uint8 = 33
	fmt.Println(one<<c8, x>>c8, y<<sh, int32(-7)>>c8)
	var w32 uint32 = 0xdeadbeef
	var i32b int32 = -0x7ead
	fmt.Println(w32*w32, i32b*i32b*i32b, w32>>31, i32b>>3, uint16(w32), int8(w32), int64(w32)*int64(i32b))
	list := []string{"a", "b", "c", "d"}
	var ix64 int64 = 3
	var ix8 uint8 = 1
	fmt.Println(list[ix64], list[ix8], list[ix8:ix64], string(rune(ix64+64)))

	// %v ordena as chaves como o internal/fmtsort.
	type pt struct{ x, y int }
	mp := map[pt]string{{2, 1}: "c", {1, 5}: "b", {1, 2}: "a"}
	ma := map[[2]int8]bool{{1, -1}: true, {-3, 0}: false, {1, -2}: true}
	mc := map[complex128]int{complex(1, 2): 1, complex(0, 9): 2, complex(1, -1): 3}
	mi := map[any]int{nil: 0, 3: 3, 1: 1, 2: 2}
	fmt.Println(mp, ma, mc, mi)
}
