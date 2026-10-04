// Package main exercita o reflect sobre os descritores estáticos (M5, D1):
// TypeOf/Kind/Name/PkgPath/String de básicos, nomeados e compostos; campos com
// tag, embutidos e FieldByName; Implements; Value com Set*/Append/New/MakeMap/
// MakeSlice; Convert, DeepEqual, IsZero e o idiom TypeOf((*I)(nil)).Elem().
package main

import (
	"errors"
	"fmt"
	"reflect"
	"sort"
)

type Celsius float64

func (c Celsius) String() string { return fmt.Sprintf("%.1fC", float64(c)) }

type IDs []string

type Inner struct {
	A int
	b string
}

type Outer struct {
	Inner
	Name  string            `json:"name,omitempty" xml:"n"`
	Tags  []string          `json:"tags"`
	Attrs map[string]int    `json:"attrs"`
	Ptr   *int              `json:"ptr"`
	Any   any               `json:"any"`
	Temp  Celsius           `json:"temp"`
	List  IDs               `json:"list"`
	Arr   [2]uint8          `json:"arr"`
	Next  *Outer            `json:"-"`
}

func (o *Outer) Hello() string { return "oi " + o.Name }
func (o Outer) Value() int     { return o.A }

type Greeter interface{ Hello() string }

func describe(v any) {
	t := reflect.TypeOf(v)
	if t == nil {
		fmt.Println("nil")
		return
	}
	fmt.Println(t.String(), t.Kind(), t.Name(), t.PkgPath())
}

func main() {
	describe(1)
	describe(int8(1))
	describe("s")
	describe(true)
	describe(3.5)
	describe(Celsius(2))
	describe(IDs{"a"})
	describe([]int{1})
	describe(map[string]int{})
	describe(map[string]any{"x": 1})
	describe([]any{1})
	describe(&Outer{})
	describe(Outer{})
	describe([3]int{})
	describe(nil)
	describe(errors.New("x"))
	n := 5
	describe(&n)

	t := reflect.TypeOf(Outer{})
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		fmt.Println(i, f.Name, f.Type, f.Tag.Get("json"), f.Anonymous, f.PkgPath, f.Index, f.Offset)
	}
	if f, ok := t.FieldByName("A"); ok {
		fmt.Println("A via", f.Index, f.Type)
	}
	_, ok := t.FieldByName("b")
	fmt.Println("b?", ok)
	tag, ok := t.Field(1).Tag.Lookup("xml")
	fmt.Println(tag, ok)

	greeter := reflect.TypeOf((*Greeter)(nil)).Elem()
	fmt.Println(greeter, greeter.Kind(), reflect.TypeOf(&Outer{}).Implements(greeter), t.Implements(greeter))
	errT := reflect.TypeOf((*error)(nil)).Elem()
	fmt.Println(errT, errT.Kind(), reflect.TypeOf(errors.New("x")).Implements(errT))
	fmt.Println(reflect.TypeOf(&Outer{}).NumMethod(), t.NumMethod())

	o := &Outer{Name: "x", Attrs: map[string]int{"b": 2, "a": 1}}
	v := reflect.ValueOf(o).Elem()
	v.FieldByName("Name").SetString("novo")
	v.Field(0).Field(0).SetInt(7)
	v.FieldByName("Tags").Set(reflect.Append(v.FieldByName("Tags"), reflect.ValueOf("t1")))
	p := reflect.New(reflect.TypeOf(0))
	p.Elem().SetInt(9)
	v.FieldByName("Ptr").Set(p)
	v.FieldByName("Any").Set(reflect.ValueOf([]int{1, 2}))
	v.FieldByName("Temp").SetFloat(36.6)
	v.FieldByName("Arr").Index(1).SetUint(255)
	fmt.Println(o.Name, o.A, o.Tags, *o.Ptr, o.Any, o.Temp, o.Arr, v.Field(0).Field(1).CanSet(), v.Field(1).CanSet())
	keys := v.FieldByName("Attrs").MapKeys()
	sort.Slice(keys, func(i, j int) bool { return keys[i].String() < keys[j].String() })
	for _, k := range keys {
		fmt.Println(k, v.FieldByName("Attrs").MapIndex(k))
	}
	m := reflect.MakeMap(reflect.TypeOf(map[string]int{}))
	m.SetMapIndex(reflect.ValueOf("z"), reflect.ValueOf(26))
	fmt.Println(m.Interface(), m.Len())
	s := reflect.MakeSlice(reflect.TypeOf(IDs{}), 1, 4)
	s.Index(0).SetString("um")
	fmt.Println(s.Interface(), s.Len(), s.Cap(), s.Type())
	fmt.Println(reflect.DeepEqual(map[string][]int{"a": {1}}, map[string][]int{"a": {1}}), reflect.DeepEqual([]int{}, []int(nil)))
	fmt.Println(reflect.ValueOf(Outer{}).IsZero(), reflect.ValueOf(o).Elem().IsZero(), reflect.ValueOf(0.0).IsZero())
	fmt.Println(reflect.Zero(t).Field(1).String())
	var e error
	fmt.Println(reflect.ValueOf(&e).Elem().Kind(), reflect.ValueOf(&e).Elem().IsNil())
	c := reflect.ValueOf(Celsius(1.5)).Convert(reflect.TypeOf(float64(0)))
	fmt.Println(c.Interface(), c.Type(), reflect.ValueOf(65).Convert(reflect.TypeOf("")).Interface())
	fmt.Println(reflect.ValueOf(Celsius(1.5)).Interface())
	fmt.Println(reflect.Indirect(reflect.ValueOf(o)).Type(), reflect.ValueOf(o).Kind() == reflect.Ptr)
	iv := reflect.ValueOf([]any{1, "a", nil})
	for i := 0; i < iv.Len(); i++ {
		el := iv.Index(i)
		fmt.Println(el.Kind(), el.Elem().IsValid())
	}
	extras()
}

type Flag bool

type Matrix [2][2]int

type Handler func(int) int

type Set map[string]struct{}

func extras() {
	// Kinds com constantes do reflect, num switch.
	for _, v := range []any{Flag(true), Matrix{}, Handler(nil), Set{}, make(chan int), func() {}, struct{ X int }{1}, uintptr(3), complex(1, 2)} {
		t := reflect.TypeOf(v)
		switch t.Kind() {
		case reflect.Bool, reflect.Array, reflect.Func, reflect.Map, reflect.Chan, reflect.Struct:
			fmt.Println("composto/bool:", t, t.Kind())
		default:
			fmt.Println("outro:", t, t.Kind(), t.Size())
		}
	}
	m := Matrix{{1, 2}, {3, 4}}
	mv := reflect.ValueOf(&m).Elem()
	mv.Index(1).Index(0).SetInt(30)
	fmt.Println(m, mv.Len(), mv.Type().Elem(), mv.Type().Len())
	fv := reflect.ValueOf(Flag(false))
	fmt.Println(fv.Bool(), fv.Kind(), fv.Type())
	var f Flag
	reflect.ValueOf(&f).Elem().SetBool(true)
	fmt.Println(f)

	s := []int{5, 1, 4}
	sw := reflect.Swapper(s)
	sw(0, 2)
	fmt.Println(s)
	dst := make([]int, 2)
	fmt.Println(reflect.Copy(reflect.ValueOf(dst), reflect.ValueOf(s)), dst)
	sv := reflect.ValueOf(&s).Elem()
	sv.SetLen(2)
	fmt.Println(s, sv.Slice(0, 1).Interface())

	set := Set{"b": {}, "a": {}}
	it := reflect.ValueOf(set).MapRange()
	n := 0
	for it.Next() {
		n++
		_ = it.Key().String()
	}
	fmt.Println("chaves:", n, reflect.TypeOf(set).Key(), reflect.TypeOf(set).Elem())

	type node struct {
		V    int
		Next *node
	}
	a := &node{V: 1}
	a.Next = a
	b := &node{V: 1}
	b.Next = b
	fmt.Println(reflect.DeepEqual(a, b), reflect.DeepEqual(a, &node{V: 2}))
	fmt.Println(reflect.TypeOf(a).Elem().Field(1).Type, reflect.TypeOf(node{}).String())

	var ip *int
	pv := reflect.ValueOf(ip)
	fmt.Println(pv.IsNil(), pv.Elem().IsValid(), pv.Type())
	x := 3
	xv := reflect.ValueOf(&x).Elem()
	px := xv.Addr().Interface().(*int)
	*px = 4
	fmt.Println(x, xv.CanAddr(), xv.Int())
	fmt.Println(reflect.ValueOf(uint8(200)).Uint(), reflect.ValueOf(float32(1.5)).Float(), reflect.ValueOf("é").Len())
	fmt.Println(reflect.TypeOf(0).ConvertibleTo(reflect.TypeOf("")), reflect.TypeOf(IDs{}).AssignableTo(reflect.TypeOf([]string{})),
		reflect.TypeOf(Celsius(0)).AssignableTo(reflect.TypeOf(0.0)))
	fmt.Println(reflect.ValueOf(Celsius(3)).String(), reflect.ValueOf(Celsius(3)))
	defer func() { fmt.Println("recuperado:", recover()) }()
	reflect.ValueOf(3).SetInt(4)
}
