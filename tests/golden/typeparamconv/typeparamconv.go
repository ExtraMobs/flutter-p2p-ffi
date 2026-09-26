// Conversões com parâmetro de tipo numérico: T(f) via $T.ofFloat, int64(x)/
// float32(x) via go.realToInt/realToFloat (TypedAtomicInt64 do cockroachdb/crlib).
package main

import (
	"fmt"
	"sync/atomic"
)

type Number interface {
	~int64 | ~float64 | ~float32 | ~uint8
}

func scale[N Number](x N, f float64) N { return N(float64(x) * f) }

func width[I ~int32 | ~int64](x I) int { return int(x) * 2 }

func toF32[N Number](x N) float32 { return float32(x) }

type ID int64

type TypedAtomicInt64[T ~int64] struct{ v atomic.Int64 }

func (x *TypedAtomicInt64[T]) Load() T       { return T(x.v.Load()) }
func (x *TypedAtomicInt64[T]) Store(val T)   { x.v.Store(int64(val)) }
func (x *TypedAtomicInt64[T]) Add(delta T) T { return T(x.v.Add(int64(delta))) }

func main() {
	fmt.Println(scale(int64(3), 1.5), scale(2.0, 0.25), width(int32(4)), scale(uint8(200), 1.6), scale(float32(1)/3, 3))
	fmt.Println(toF32(int64(16777217)), toF32(1e40), toF32(uint8(7)))
	var a TypedAtomicInt64[ID]
	a.Store(40)
	fmt.Println(a.Add(2), a.Load())
}
