package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/bits"
	"math/rand/v2"
	"os"
)

func fb(v float64) string {
	if math.IsNaN(v) {
		return "NaN" // payload de NaN não é portável
	}
	return fmt.Sprintf("%016x", math.Float64bits(v))
}

func main() {
	fs := []float64{0, math.Copysign(0, -1), 1, -1, 2, 0.1, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5,
		1e-300, 1e300, -1e300, math.SmallestNonzeroFloat64, -math.SmallestNonzeroFloat64,
		2.2250738585072014e-308, math.MaxFloat64, -math.MaxFloat64, 4503599627370495.5,
		-4503599627370495.5, 9007199254740993, math.Inf(1), math.Inf(-1), math.NaN(), 12345.6789}
	us := []uint64{0, 1, 2, 3, 0xff, 0x100, 0xffffffff, 0x100000000, 1 << 63, math.MaxUint64,
		0x0123456789abcdef, 0xfedcba9876543210, 0x8000000000000001}
	r := rand.New(rand.NewPCG(7, 9))
	for i := 0; i < 24; i++ {
		us = append(us, r.Uint64()>>(r.Uint64()%64))
	}
	ks := []int{-100, -65, -64, -33, -1, 0, 1, 7, 31, 32, 33, 63, 64, 65, 1000}
	in := map[string]any{"f": nil, "u": nil, "k": ks}
	var fin, uin []string
	for _, f := range fs {
		fin = append(fin, fmt.Sprintf("%016x", math.Float64bits(f)))
	}
	for _, u := range us {
		uin = append(uin, fmt.Sprintf("%x", u))
	}
	in["f"], in["u"] = fin, uin
	out := map[string][]string{}
	add := func(k string, v ...any) { out[k] = append(out[k], fmt.Sprint(v...)) }
	for _, f := range fs {
		add("sqrt", fb(math.Sqrt(f)))
		add("floor", fb(math.Floor(f)))
		add("ceil", fb(math.Ceil(f)))
		add("trunc", fb(math.Trunc(f)))
		add("abs", fb(math.Abs(f)))
		add("signbit", math.Signbit(f))
		add("isNaN", math.IsNaN(f))
		add("isInf", math.IsInf(f, -1), " ", math.IsInf(f, 0), " ", math.IsInf(f, 1))
		add("f32bits", fmt.Sprintf("%08x", math.Float32bits(float32(f))))
		if !math.IsNaN(f) {
			add("f64bits", fmt.Sprintf("%016x", math.Float64bits(f)))
		}
		for _, g := range fs {
			add("max", fb(math.Max(f, g)))
			add("min", fb(math.Min(f, g)))
		}
	}
	for _, u := range us {
		u32, u8 := uint32(u), uint8(u)
		add("ones", bits.OnesCount64(u), " ", bits.OnesCount32(u32), " ", bits.OnesCount8(u8))
		add("lz", bits.LeadingZeros64(u), " ", bits.LeadingZeros8(u8))
		add("tz", bits.TrailingZeros64(u), " ", bits.TrailingZeros32(u32), " ", bits.TrailingZeros(uint(u)))
		add("len", bits.Len64(u), " ", bits.Len32(u32), " ", bits.Len(uint(u)))
		add("rev", fmt.Sprintf("%x %x %x", bits.ReverseBytes64(u), bits.ReverseBytes32(u32), bits.ReverseBytes16(uint16(u))))
		for _, k := range ks {
			add("rot", fmt.Sprintf("%x %x", bits.RotateLeft64(u, k), bits.RotateLeft32(u32, k)))
		}
		for _, v := range us {
			for _, c := range []uint64{0, 1} {
				s, co := bits.Add64(u, v, c)
				d, bo := bits.Sub64(u, v, c)
				s2, co2 := bits.Add(uint(u), uint(v), uint(c))
				d2, bo2 := bits.Sub(uint(u), uint(v), uint(c))
				add("addsub", fmt.Sprintf("%x %x %x %x %x %x %x %x", s, co, d, bo, s2, co2, d2, bo2))
			}
			hi, lo := bits.Mul64(u, v)
			hi2, lo2 := bits.Mul(uint(u), uint(v))
			add("mul", fmt.Sprintf("%x %x %x %x", hi, lo, hi2, lo2))
			if v != 0 {
				h := u % v // garante h < v: sem pânico
				q, rm := bits.Div64(h, u, v)
				q2, rm2 := bits.Div(uint(h), uint(u), uint(v))
				add("div", fmt.Sprintf("%x %x %x %x", q, rm, q2, rm2))
			}
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]any{"in": in, "out": out}); err != nil {
		panic(err)
	}
}
