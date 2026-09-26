// Repros dos shims math e math/bits no grafo do kubo:
// github.com/petar/GoLLRB/llrb (math.Sqrt), golang.org/x/crypto/salsa20/salsa
// e zeebo/blake3 (bits.RotateLeft32), google.golang.org/protobuf/internal/set
// (bits.OnesCount64), github.com/ipfs/go-bitfield (bits.OnesCount8) e
// github.com/klauspost/compress (identificador Unicode Δ).
package main

import (
	"fmt"
	"math"
	"math/bits"
)

type avgVar struct {
	count      int64
	sum, sumsq float64
}

func (av *avgVar) Add(sample float64) {
	av.count++
	av.sum += sample
	av.sumsq += sample * sample
}

func (av *avgVar) GetAvg() float64 { return av.sum / float64(av.count) }

func (av *avgVar) GetVar() float64 {
	a := av.GetAvg()
	return av.sumsq/float64(av.count) - a*a
}

func (av *avgVar) GetStdDev() float64 { return math.Sqrt(av.GetVar()) }

// quarterRound no estilo do salsa20.
func quarterRound(a, b, c, d uint32) (uint32, uint32, uint32, uint32) {
	b ^= bits.RotateLeft32(a+d, 7)
	c ^= bits.RotateLeft32(b+a, 9)
	d ^= bits.RotateLeft32(c+b, 13)
	a ^= bits.RotateLeft32(d+c, 18)
	return a, b, c, d
}

type int64Set struct{ lo uint64 }

func (s *int64Set) Len() int     { return bits.OnesCount64(s.lo) }
func (s *int64Set) Set(i uint64) { s.lo |= uint64(1) << i }

type Bitfield []byte

func (bf Bitfield) OnesCount() (count int) {
	for _, b := range bf {
		count += bits.OnesCount8(b)
	}
	return count
}

type Ωmega struct{ Δx float64 }

func Δf(Δ float64) float64 { return Δ * Δ }

func divPanic(hi, lo, y uint64) (msg string) {
	defer func() { msg = fmt.Sprint(recover()) }()
	bits.Div64(hi, lo, y)
	return
}

func main() {
	var av avgVar
	for _, s := range []float64{2, 4, 4, 4, 5, 5, 7, 9} {
		av.Add(s)
	}
	fmt.Println(av.GetAvg(), av.GetVar(), av.GetStdDev())
	fmt.Println(math.Sqrt(2), math.Sqrt(0.1), math.Sqrt(1e-310), math.Sqrt(math.MaxFloat64))
	var zero float64
	fmt.Println(math.Sqrt(math.Copysign(0, -1)), math.Sqrt(-1), math.Sqrt(1/zero), math.Sqrt(-1/zero))

	for _, f := range []float64{-2.5, -0.5, math.Copysign(0, -1), 0.5, 2.5, 4503599627370495.5, math.Inf(-1), math.NaN()} {
		fmt.Println(f, math.Floor(f), math.Ceil(f), math.Trunc(f), math.Abs(f), math.Signbit(f), math.IsNaN(f), math.IsInf(f, -1))
	}
	fmt.Println(math.Max(0, math.Copysign(0, -1)), math.Min(0, math.Copysign(0, -1)), math.Max(math.NaN(), math.Inf(1)), math.Min(1, math.NaN()))
	fmt.Printf("%x %x %v %v\n", math.Float64bits(-1.5), math.Float32bits(0.1), math.Float64frombits(0x400921fb54442d18), math.Float32frombits(0x3f800000))

	fmt.Println(quarterRound(1, 2, 3, 0xffffffff))
	var set int64Set
	for _, i := range []uint64{0, 5, 63, 5} {
		set.Set(i)
	}
	fmt.Println(set.Len(), Bitfield{0xff, 0x01, 0x80, 0}.OnesCount())
	x := uint64(0xfedcba9876543210)
	fmt.Println(bits.Len64(x>>9), bits.TrailingZeros64(x), bits.LeadingZeros64(x>>3), bits.RotateLeft64(x, -4), bits.ReverseBytes64(x))
	s, c := bits.Add64(x, x, 1)
	hi, lo := bits.Mul64(x, x)
	q, r := bits.Div64(hi%x, lo, x)
	fmt.Println(s, c, hi, lo, q, r)
	fmt.Println(divPanic(1, 1, 0))
	fmt.Println(divPanic(1, 1, 1))

	Δ := Ωmega{Δx: 1.5}
	Δ.Δx += Δf(Δ.Δx)
	fmt.Println(Δ, Δ.Δx)
}
