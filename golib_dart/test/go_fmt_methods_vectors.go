//go:build ignore

// Oráculo dos métodos String()/Error() chamados pelo fmt em valores
// aninhados (fmt_methods_test.dart): imprime as saídas em JSON, na ordem dos
// casos do teste Dart.
package main

import (
	"encoding/json"
	"fmt"
	"os"
)

type T struct{ n int }

func (t *T) String() string { return fmt.Sprint("T", t.n) }

type V struct{ n int }

func (v V) String() string { return fmt.Sprint("V", v.n) }

type W struct {
	v V
	E V
}

type B struct{}

func (b *B) String() string { panic("boom") }

type Q struct{ n int }

func (q *Q) String() string { return fmt.Sprint("Q", q.n) }

type E struct{ msg string }

func (e *E) Error() string { return "E:" + e.msg }

type Holder struct {
	Err error
	T   *T
}

func main() {
	out := []string{
		fmt.Sprint([]*T{{1}, {2}}),
		fmt.Sprint([]T{{3}}),
		fmt.Sprint(W{V{1}, V{2}}),
		fmt.Sprint(&B{}),
		fmt.Sprintf("%s", (*Q)(nil)),
		fmt.Sprint([]error{&E{"a"}}),
		fmt.Sprint(Holder{Err: &E{"d"}, T: &T{8}}),
		fmt.Sprint([]*Q{nil}),
		fmt.Sprintf("%d", &B{}),
		fmt.Sprintf("%x|%5v", &B{}, []*T{{4}}),
		fmt.Sprintln([]interface{}{&T{5}, V{6}, T{7}}),
		fmt.Sprintf("%v %+v", map[string]*T{"k": {9}}, W{V{1}, V{2}}),
	}
	json.NewEncoder(os.Stdout).Encode(out)
}
