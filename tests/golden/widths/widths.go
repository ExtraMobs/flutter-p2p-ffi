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
}
