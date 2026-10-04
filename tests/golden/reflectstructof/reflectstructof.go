// reflect.StructOf: tipo struct montado em runtime (nome, layout amd64,
// cache canônico), valores por reflect.New/Field/Set, fmt, ==, DeepEqual,
// map com chave dinâmica e os panics do Go.
package main

import (
	"fmt"
	"reflect"
)

type Inner struct {
	X int
	Y string
}

type M int

func (M) Foo() {}

type Named map[string]int

func try(name string, f func()) {
	defer func() { fmt.Println(name+":", recover()) }()
	f()
}

func describe(t reflect.Type) {
	fmt.Printf("%v kind=%v name=%q pkg=%q size=%d align=%d comparable=%v nf=%d\n",
		t, t.Kind(), t.Name(), t.PkgPath(), t.Size(), t.Align(), t.Comparable(), t.NumField())
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		fmt.Printf("  %d %v pkg=%q type=%v off=%d tag=%q json=%q anon=%v index=%v exported=%v\n",
			i, f.Name, f.PkgPath, f.Type, f.Offset, f.Tag, f.Tag.Get("json"), f.Anonymous, f.Index, f.IsExported())
	}
}

func main() {
	intT := reflect.TypeOf(0)
	strT := reflect.TypeOf("")
	fields := []reflect.StructField{
		{Name: "A", Type: intT, Tag: `json:"a"`},
		{Name: "B", Type: strT},
		{Name: "c", Type: reflect.TypeOf(int8(0)), PkgPath: "main"},
	}
	t := reflect.StructOf(fields)
	describe(t)

	// Canônico: a mesma lista dá o mesmo Type; tag diferente, outro.
	again := reflect.StructOf([]reflect.StructField{
		{Name: "A", Type: intT, Tag: `json:"a"`},
		{Name: "B", Type: strT},
		{Name: "c", Type: reflect.TypeOf(int8(0)), PkgPath: "main"},
	})
	other := reflect.StructOf([]reflect.StructField{
		{Name: "A", Type: intT, Tag: `json:"b"`},
		{Name: "B", Type: strT},
		{Name: "c", Type: reflect.TypeOf(int8(0)), PkgPath: "main"},
	})
	fmt.Println("same:", t == again, "other:", t == other)
	fmt.Println("empty:", reflect.StructOf(nil), reflect.StructOf(nil) == reflect.TypeOf(struct{}{}))

	// Valores.
	p := reflect.New(t)
	v := p.Elem()
	v.Field(0).SetInt(42)
	v.FieldByName("B").SetString("hi")
	fmt.Println("canset:", v.Field(0).CanSet(), v.Field(2).CanSet(), v.Field(2).CanInterface())
	x := v.Interface()
	fmt.Printf("%v | %+v | %T\n", x, x, x)
	fmt.Println(v, p.Type(), v.Field(1).Interface(), v.Field(2).Int())
	v.Field(0).SetInt(7)
	fmt.Println("copy:", x, v.Interface())
	fmt.Printf("%#v\n", v.Interface())

	// == e DeepEqual entre valores do tipo dinâmico.
	w := reflect.New(t).Elem()
	w.Field(0).SetInt(7)
	w.Field(1).SetString("hi")
	fmt.Println("eq:", v.Interface() == w.Interface(), x == w.Interface(), reflect.DeepEqual(v.Interface(), w.Interface()))
	fmt.Println("zero:", reflect.Zero(t).Interface(), reflect.Zero(t).IsZero(), v.IsZero())
	var anyx any = x
	fmt.Println("typeof:", reflect.TypeOf(anyx) == t, reflect.ValueOf(anyx).Field(0).Int())

	// Layout amd64: alinhamento, padding e campo final de tamanho zero.
	describe(reflect.StructOf([]reflect.StructField{
		{Name: "A", Type: reflect.TypeOf(int8(0))},
		{Name: "B", Type: reflect.TypeOf(int64(0))},
		{Name: "C", Type: reflect.TypeOf(int16(0))},
	}))
	describe(reflect.StructOf([]reflect.StructField{
		{Name: "A", Type: reflect.TypeOf(int32(0))},
		{Name: "Z", Type: reflect.TypeOf(struct{}{})},
	}))
	describe(reflect.StructOf([]reflect.StructField{
		{Name: "S", Type: reflect.TypeOf([]int(nil))},
		{Name: "Arr", Type: reflect.TypeOf([3]uint16{})},
		{Name: "P", Type: reflect.TypeOf((*int)(nil))},
		{Name: "_", Type: intT, PkgPath: "main"},
		{Name: "_", Type: strT, PkgPath: "main"},
	}))

	// Aninhado e embutido (promoção pelo FieldByName).
	inner := reflect.StructOf([]reflect.StructField{{Name: "N", Type: intT}})
	outer := reflect.StructOf([]reflect.StructField{
		{Name: "Inner", Type: reflect.TypeOf(Inner{}), Anonymous: true},
		{Name: "Sub", Type: inner},
		{Name: "Arr", Type: reflect.ArrayOf(2, inner)},
	})
	describe(outer)
	o := reflect.New(outer).Elem()
	o.FieldByName("X").SetInt(5)
	o.FieldByName("Y").SetString("y")
	o.Field(1).Field(0).SetInt(9)
	o.Field(2).Index(1).Field(0).SetInt(3)
	snap := o.Interface()
	o.Field(1).Field(0).SetInt(10)
	fmt.Printf("%v | %+v\n", snap, o.Interface())
	sf, ok := outer.FieldByName("Y")
	fmt.Println("promoted:", sf.Name, sf.Index, ok)

	// Slice e map do tipo dinâmico.
	s := reflect.MakeSlice(reflect.SliceOf(inner), 2, 2)
	s.Index(1).Field(0).SetInt(11)
	s = reflect.Append(s, s.Index(1))
	fmt.Println("slice:", s.Len(), s.Interface(), s.Type())
	m := reflect.MakeMap(reflect.MapOf(t, strT))
	k1 := reflect.New(t).Elem()
	k1.Field(0).SetInt(1)
	m.SetMapIndex(k1, reflect.ValueOf("one"))
	k2 := reflect.New(t).Elem()
	k2.Field(0).SetInt(1)
	fmt.Println("map:", m.Len(), m.MapIndex(k2), m.Type())
	k2.Field(0).SetInt(2)
	fmt.Println("miss:", m.MapIndex(k2).IsValid())

	// Struct com slice: não comparável.
	unc := reflect.StructOf([]reflect.StructField{{Name: "S", Type: reflect.TypeOf([]int(nil))}})
	fmt.Println("uncomparable:", unc.Comparable(), unc)
	try("cmp", func() {
		a, b := reflect.Zero(unc).Interface(), reflect.Zero(unc).Interface()
		fmt.Println(a == b)
	})

	// Panics do Go.
	try("noname", func() { reflect.StructOf([]reflect.StructField{{Type: intT}}) })
	try("invalid", func() { reflect.StructOf([]reflect.StructField{{Name: "A", Type: intT}, {Name: "1x", Type: intT}}) })
	try("notype", func() { reflect.StructOf([]reflect.StructField{{Name: "A"}}) })
	try("unexported", func() { reflect.StructOf([]reflect.StructField{{Name: "a", Type: intT}}) })
	try("underscore", func() { reflect.StructOf([]reflect.StructField{{Name: "_x", Type: intT}}) })
	try("dup", func() { reflect.StructOf([]reflect.StructField{{Name: "A", Type: intT}, {Name: "A", Type: strT}}) })
	try("anonpkg", func() {
		reflect.StructOf([]reflect.StructField{{Name: "Inner", Type: reflect.TypeOf(Inner{}), Anonymous: true, PkgPath: "main"}})
	})
	try("pkgs", func() {
		reflect.StructOf([]reflect.StructField{{Name: "a", Type: intT, PkgPath: "p1"}, {Name: "b", Type: intT, PkgPath: "p2"}})
	})
	try("embedptrptr", func() {
		reflect.StructOf([]reflect.StructField{{Name: "P", Type: reflect.TypeOf((**int)(nil)), Anonymous: true}})
	})
	try("embedmethods", func() {
		reflect.StructOf([]reflect.StructField{{Name: "A", Type: intT}, {Name: "M", Type: reflect.TypeOf(M(0)), Anonymous: true}})
	})
	try("embednamedmap", func() {
		reflect.StructOf([]reflect.StructField{{Name: "Named", Type: reflect.TypeOf(Named(nil)), Anonymous: true}, {Name: "A", Type: intT}})
	})
	try("field", func() { reflect.Zero(t).Field(5) })
	try("iface", func() { v.Field(2).Interface() })
	try("set", func() { v.Field(2).SetInt(1) })
}
