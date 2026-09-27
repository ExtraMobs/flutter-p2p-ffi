package main

import (
	"fmt"

	"g2d.test/unexportedcross/a"
)

func main() {
	x := a.New()
	fmt.Println(x.Get())

	y := a.Double(x)
	fmt.Println(y.Get(), x.Get())

	p := a.NewPair(3, 4)
	fmt.Println(p.Sum())

	b := a.NewBox()
	imp := b.Impl
	fmt.Println(imp.Get())

	xs := a.All()
	xs = append(xs, nil)
	total := 0
	for _, v := range xs {
		if v != nil {
			total += v.Get()
		}
	}
	fmt.Println(total, len(xs))

	c := a.NewCounter()
	fmt.Println(c.Value())
}
