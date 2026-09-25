// Package main usa nomes que coincidem com os do dart:core usados pelo
// código gerado (Object, Map, String, identical, int, bool): eles precisam
// ser renomeados para não sombrear o core.
package main

import "fmt"

type Object struct{ Name string }

type Map struct{ Size int }

type String int

func (s String) Double() String { return s * 2 }

func Identical(a, b *Object) bool { return a == b }

func Print(xs ...any) { fmt.Println(xs...) }

func main() {
	o := &Object{"x"}
	int := 3
	bool := true
	var s String = 5
	m := Map{Size: int}
	var anything any = o
	fmt.Println(Identical(o, o), Identical(o, &Object{"x"}), int, bool, s.Double(), m, o.Name, anything != nil)
	Print("print", int)
}
