// &T elidido em literais de slice, array e map de ponteiros
// (golang.org/x/text/unicode/norm: tabelas de *formInfo).
package main

import "fmt"

type P struct{ X, Y int }

type formInfo struct {
	name string
	decomp [2]byte
}

var table = [...]*formInfo{
	{"nfc", [2]byte{1, 2}},
	{name: "nfd"},
}

func main() {
	ps := []*P{{1, 2}, {3, 4}}
	ps[0].X = 10
	q := ps[0]
	q.Y = 20
	m := map[string]*P{"a": {5, 6}}
	arr := []*[2]int{{7, 8}}
	arr[0][1] = 9
	fmt.Println(*ps[0], ps[1].Y, *m["a"], *arr[0], table[0].name, table[1].decomp, len(table))
	fmt.Println(ps[0] == q, ps[0] == ps[1])
}
