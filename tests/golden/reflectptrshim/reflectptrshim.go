package main

import (
	"encoding/json"
	"fmt"
	"reflect"
)

type P struct{ X int }

type I interface{ M() }

func main() {
	var p *P
	err := json.Unmarshal([]byte(`{"X":1}`), &p)
	fmt.Println(err, p.X)
	var q *P
	fmt.Println(reflect.TypeOf(&q), reflect.ValueOf(&q).Elem().IsNil())
	var i I
	fmt.Println(reflect.TypeOf(&i).Elem().Kind(), reflect.TypeOf(&i))
	m := reflect.TypeOf((*json.Marshaler)(nil)).Elem()
	fmt.Println(m, reflect.TypeOf(P{}).Implements(m), m.NumMethod())
}
