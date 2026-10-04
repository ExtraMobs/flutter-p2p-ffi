// Package main chama por reflexão (M5, D1): Call/CallSlice, variádicos,
// métodos ligados (Method/MethodByName, Method.Func), MakeFunc e FuncOf.
package main

import (
	"errors"
	"fmt"
	"reflect"
	"strings"
)

type G struct{ N int }

func (g G) Hi(n int) string        { return fmt.Sprint("hi ", n+g.N) }
func (g *G) Inc(d int)             { g.N += d }
func (g G) Pair() (int, error)      { return g.N, errors.New("e") }
func (g G) Join(sep string, xs ...string) string { return strings.Join(xs, sep) }

type Op func(int, int) int

type Count int

func (c Count) Double() Count { return c * 2 }
func (c *Count) Add(n int)    { *c += Count(n) }

type Greeter interface{ Hi(int) string }

func add(a, b int) int { return a + b }

func sum(xs ...int) (t int) {
	for _, x := range xs {
		t += x
	}
	return
}

func main() {
	ft := reflect.TypeOf(add)
	fmt.Println(ft, ft.NumIn(), ft.In(0), ft.NumOut(), ft.Out(0), ft.IsVariadic())
	st := reflect.TypeOf(sum)
	fmt.Println(st, st.IsVariadic(), st.In(0))
	out := reflect.ValueOf(add).Call([]reflect.Value{reflect.ValueOf(2), reflect.ValueOf(3)})
	fmt.Println(len(out), out[0].Int())
	fmt.Println(reflect.ValueOf(sum).Call([]reflect.Value{reflect.ValueOf(1), reflect.ValueOf(2), reflect.ValueOf(3)})[0])
	fmt.Println(reflect.ValueOf(sum).CallSlice([]reflect.Value{reflect.ValueOf([]int{4, 5})})[0])
	fmt.Println(reflect.ValueOf(sum).Call(nil)[0])
	var op Op = func(a, b int) int { return a * b }
	ot := reflect.TypeOf(op)
	fmt.Println(ot, ot.Kind(), ot.NumIn())
	fmt.Println(reflect.ValueOf(op).Call([]reflect.Value{reflect.ValueOf(6), reflect.ValueOf(7)})[0])

	g := G{N: 1}
	v := reflect.ValueOf(g)
	fmt.Println(v.NumMethod(), v.Method(0).Type(), v.MethodByName("Hi").Call([]reflect.Value{reflect.ValueOf(4)})[0])
	r := v.MethodByName("Pair").Call(nil)
	fmt.Println(r[0], r[1], r[1].Type())
	fmt.Println(v.MethodByName("Join").Call([]reflect.Value{reflect.ValueOf("-"), reflect.ValueOf("a"), reflect.ValueOf("b")})[0])
	pv := reflect.ValueOf(&g)
	pv.MethodByName("Inc").Call([]reflect.Value{reflect.ValueOf(10)})
	fmt.Println(g.N, pv.NumMethod(), v.MethodByName("Nope").IsValid())
	m, _ := reflect.TypeOf(&g).MethodByName("Hi")
	fmt.Println(m.Name, m.Type, m.Func.Call([]reflect.Value{reflect.ValueOf(&g), reflect.ValueOf(1)})[0])
	m2 := reflect.TypeOf(g).Method(0)
	fmt.Println(m2.Name, m2.Type, m2.Type.NumIn())

	c := Count(3)
	cv := reflect.ValueOf(&c)
	cv.MethodByName("Add").Call([]reflect.Value{reflect.ValueOf(4)})
	fmt.Println(c, cv.MethodByName("Double").Call(nil)[0], cv.Elem().MethodByName("Double").Call(nil)[0])

	var gr Greeter = g
	iv := reflect.ValueOf(&gr).Elem()
	fmt.Println(iv.Kind(), iv.NumMethod(), iv.Method(0).Call([]reflect.Value{reflect.ValueOf(5)})[0])

	swap := func(in []reflect.Value) []reflect.Value { return []reflect.Value{in[1], in[0]} }
	var intSwap func(int, int) (int, int)
	fn := reflect.MakeFunc(reflect.TypeOf(intSwap), swap)
	reflect.ValueOf(&intSwap).Elem().Set(fn)
	fmt.Println(intSwap(1, 2))
	var strSwap func(string, string) (string, string)
	reflect.ValueOf(&strSwap).Elem().Set(reflect.MakeFunc(reflect.TypeOf(strSwap), swap))
	fmt.Println(strSwap("a", "b"))
	mk := reflect.MakeFunc(reflect.TypeOf(op), func(in []reflect.Value) []reflect.Value {
		return []reflect.Value{reflect.ValueOf(int(in[0].Int() - in[1].Int()))}
	})
	fmt.Println(mk.Interface().(Op)(9, 4), mk.Type())

	f2 := reflect.FuncOf([]reflect.Type{reflect.TypeOf(0)}, []reflect.Type{reflect.TypeOf("")}, false)
	fmt.Println(f2, f2 == reflect.TypeOf(func(int) string { return "" }))

	defer func() { fmt.Println("recuperado:", recover()) }()
	reflect.ValueOf(add).Call([]reflect.Value{reflect.ValueOf(1)})
}
