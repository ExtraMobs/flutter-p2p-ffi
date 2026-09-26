// Repro de github.com/petar/GoLLRB/llrb (avgvar.go): math.Sqrt no shim math.
package main

import (
	"fmt"
	"math"
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

func main() {
	var av avgVar
	for _, s := range []float64{2, 4, 4, 4, 5, 5, 7, 9} {
		av.Add(s)
	}
	fmt.Println(av.GetAvg(), av.GetVar(), av.GetStdDev())
	fmt.Println(math.Sqrt(2), math.Sqrt(0.1), math.Sqrt(1e-310), math.Sqrt(math.MaxFloat64))
	var zero float64
	fmt.Println(math.Sqrt(math.Copysign(0, -1)), math.Sqrt(-1), math.Sqrt(1/zero), math.Sqrt(-1/zero))
}
