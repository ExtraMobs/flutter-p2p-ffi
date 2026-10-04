package main

// Instâncias de tipos genéricos: descritor montado pela fábrica $rtOf.

import (
	"fmt"
	"reflect"
)

type Box[T any] struct {
	V    T `json:"v"`
	List []T
	n    int
}

func (b Box[T]) Get() T   { return b.V }
func (b *Box[T]) Set(v T) { b.V = v }

type Pair[K comparable, V any] struct {
	Key K
	Val V
}

type Opt[T any] []T

func init() {
	var x any = Box[int]{V: 1}
	t := reflect.TypeOf(x)
	fmt.Println(t, t.Name(), t.NumField(), t.Field(0).Type, t.Field(1).Type, t.Field(0).Tag.Get("json"))
	fmt.Println(reflect.TypeOf(&Box[string]{}), reflect.TypeOf(&Box[string]{}).NumMethod())
	p := Pair[string, Box[int]]{Key: "a"}
	pt := reflect.TypeOf(p)
	fmt.Println(pt, pt.Field(1).Type, pt.Field(1).Type == t)
	v := reflect.ValueOf(&p).Elem()
	v.Field(1).Field(0).SetInt(42)
	fmt.Println(p.Val.V, v.Field(1).Interface())
	fmt.Println(reflect.TypeOf(Opt[int]{}), reflect.TypeOf(Opt[int]{}).Elem())
	fmt.Println(reflect.TypeFor[Box[Pair[int, string]]]())
}
