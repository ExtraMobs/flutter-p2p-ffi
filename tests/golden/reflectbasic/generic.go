package main

// reflect.TypeFor com parâmetro de tipo: o descritor sai do dicionário $T.

import (
	"fmt"
	"reflect"
)

type GP struct{ X int }

func typeName[T any]() string { return reflect.TypeFor[T]().String() }

func sliceType[T any]() reflect.Type { return reflect.TypeFor[[]T]() }

type Holder[T any] struct{ v T }

func (h Holder[T]) Kind() reflect.Kind { return reflect.TypeFor[T]().Kind() }

// *T nil dentro de genérico, guardado em interface: não é nil.
func nilPtrOf[T any]() any {
	var p *T
	return p
}

func init() {
	for _, x := range []any{nilPtrOf[int](), nilPtrOf[string](), nilPtrOf[GP]()} {
		fmt.Println(x == nil, reflect.TypeOf(x), reflect.ValueOf(x).IsNil())
	}
	fmt.Println(typeName[int](), typeName[GP](), typeName[*GP](), typeName[[]string]())
	fmt.Println(sliceType[GP](), sliceType[int]().Elem() == reflect.TypeOf(0))
	fmt.Println(Holder[string]{}.Kind(), Holder[GP]{}.Kind())
}
