package main

import (
	"fmt"
	"sync"
)

type P struct{ X int }

func (p P) Show() { fmt.Println("show", p.X) }

func (p P) Report(wg *sync.WaitGroup) {
	fmt.Println("go", p.X)
	wg.Done()
}

func (p *P) ShowPtr() { fmt.Println("ptr", p.X) }

type Outer struct {
	P
	Tag string
}

type OuterPtr struct {
	*P
}

func main() {
	p := P{1}
	defer p.Show()
	pp := &P{2}
	defer pp.Show()
	defer pp.ShowPtr()
	o := Outer{P{3}, "o"}
	defer o.Show()
	op := OuterPtr{&P{4}}
	defer op.Show()

	var wg sync.WaitGroup
	wg.Add(1)
	g := P{5}
	go g.Report(&wg)
	g.X = 70
	wg.Wait()

	p.X = 50
	pp.X = 60
	o.X = 30
	op.X = 40
}
