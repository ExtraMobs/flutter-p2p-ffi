package main

import "fmt"

type Arr [2]int

func (a Arr) Sum() int { return a[0] + a[1] }

func (a *Arr) Bump() { a[0]++ }

type Summer interface{ Sum() int }

type Bumper interface {
	Summer
	Bump()
}

func main() {
	a := Arr{1, 2}
	var s Summer = a
	a[0] = 10 // a interface guardou uma cópia
	fmt.Println(s.Sum(), a.Sum())
	if b, ok := s.(Arr); ok {
		fmt.Println(b[0], b[1])
	}
	var bp Bumper = &a
	bp.Bump()
	fmt.Println(bp.Sum(), a[0])
	_, isPtr := s.(*Arr)
	fmt.Println(isPtr)
	fmt.Println(s, a)
}
