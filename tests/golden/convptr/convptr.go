// Conversões entre ponteiros: (*U)(p) de mesmo subjacente básico (o padrão
// do google.golang.org/protobuf/internal/set), nil, igualdade e volta ao tipo
// de origem; (*[N]T)(s) sobre o armazenamento do slice, slice nil e curto.
package main

import (
	"fmt"
	"math/bits"
)

type int64s uint64

func (bs *int64s) Len() int         { return bits.OnesCount64(uint64(*bs)) }
func (bs *int64s) Has(n uint64) bool { return uint64(*bs)&(uint64(1)<<n) > 0 }
func (bs *int64s) Set(n uint64)      { *(*uint64)(bs) |= uint64(1) << n }
func (bs *int64s) Clear(n uint64)    { *(*uint64)(bs) &^= uint64(1) << n }

type Ints struct{ lo int64s }

type F float64

type Name string

func try(f func()) {
	defer func() { fmt.Println("recover:", recover()) }()
	f()
}

func main() {
	var bs int64s
	bs.Set(3)
	bs.Set(5)
	bs.Clear(3)
	fmt.Println(bs, bs.Len(), bs.Has(5), bs.Has(3))
	var s Ints
	s.lo.Set(1)
	fmt.Println(s.lo, s)

	f := F(1.5)
	q := (*float64)(&f)
	*q *= 3
	fmt.Println(f, *q)

	n := Name("a")
	pn := (*string)(&n)
	*pn += "b"
	fmt.Println(n, *pn, (*Name)(pn) == &n, q == (*float64)(&f))

	var nilp *F
	fmt.Println((*float64)(nilp) == nil)

	buf := []byte{1, 2, 3, 4, 5}
	a := (*[4]byte)(buf)
	a[0] = 9
	buf[1] = 8
	fmt.Println(buf, *a, len(a))
	b := (*[2]byte)(buf[3:])
	b[1]++
	fmt.Println(buf)
	var nb []byte
	fmt.Println((*[0]byte)(nb) == nil, (*[0]byte)(buf[:0]) == nil)
	try(func() { _ = (*[8]byte)(buf) })
}
