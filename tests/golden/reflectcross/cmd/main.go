// Command cmd percorre por reflexão tipos de outro pacote: campos, tags,
// embutidos, métodos, Implements e Set através de ponteiro.
package main

import (
	"fmt"
	"reflect"

	"g2d.test/reflectcross/shapes"
)

func walk(t reflect.Type, indent string) {
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		fmt.Printf("%s%s %v pkg=%q exp=%v emb=%v tag=%q json=%q\n", indent, f.Name, f.Type, f.PkgPath, f.IsExported(), f.Anonymous, f.Tag, f.Tag.Get("json"))
		if f.Anonymous && f.Type.Kind() == reflect.Struct {
			walk(f.Type, indent+"  ")
		}
	}
}

func main() {
	r := shapes.New(2, 3)
	t := reflect.TypeOf(r)
	fmt.Println(t, t.Kind(), t.Elem().Name(), t.Elem().PkgPath())
	walk(t.Elem(), "")

	shape := reflect.TypeOf((*shapes.Shape)(nil)).Elem()
	fmt.Println(shape, shape.Kind(), t.Implements(shape), t.Elem().Implements(shape))
	fmt.Println(t.NumMethod(), t.Elem().NumMethod())
	for i := 0; i < t.NumMethod(); i++ {
		fmt.Println("método:", t.Method(i).Name, t.Method(i).Type)
	}

	v := reflect.ValueOf(r).Elem()
	v.FieldByName("W").SetFloat(10)
	v.FieldByName("ID").SetInt(99)
	v.FieldByName("Tags").Set(reflect.ValueOf([]string{"a", "b"}))
	m := reflect.MakeMap(v.FieldByName("Props").Type())
	m.SetMapIndex(reflect.ValueOf("k"), reflect.ValueOf(5))
	v.FieldByName("Props").Set(m)
	fmt.Println(r.Area(), r.ID, r.Tags, r.Props, v.FieldByName("note").CanSet(), v.FieldByName("note").String())
	f, ok := t.Elem().FieldByName("Describe")
	fmt.Println(f.Name, ok)
	g, ok := t.Elem().FieldByName("ID")
	fmt.Println(g.Name, g.Index, ok)

	u := reflect.ValueOf(shapes.Unit(4))
	fmt.Println(u.Type(), u.Kind(), u.Int(), u.Interface())
	if s, ok := u.Interface().(fmt.Stringer); ok {
		fmt.Println("stringer:", s.String())
	}
	fmt.Println(reflect.DeepEqual(shapes.New(1, 1), shapes.New(1, 1)), reflect.DeepEqual(*shapes.New(1, 1), *shapes.New(1, 2)))
}
