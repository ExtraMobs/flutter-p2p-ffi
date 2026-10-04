// Fixture do shim encoding/json (decode): structs, casamento de nomes sem
// caixa, embutidos, any, null, overflow, erros com mensagem e offset,
// Unmarshaler/TextUnmarshaler, RawMessage, Number e base64.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

type Inner struct {
	N int
	S string `json:"s"`
}

type base struct {
	ID   int `json:"id"`
	Kind string
}

type Ext struct {
	Tag string
}

type Doc struct {
	Title  string   `json:"title"`
	Count  int      `json:"count"`
	Small  int8     `json:"small"`
	U      uint16   `json:"u"`
	F      float32  `json:"f"`
	Ok     bool     `json:"ok"`
	Ptr    *Inner   `json:"ptr"`
	List   []int    `json:"list"`
	Arr    [3]int   `json:"arr"`
	Map    map[string]float64
	Any    any      `json:"any"`
	Bytes  []byte   `json:"bytes"`
	Q      int      `json:"q,string"`
	QS     string   `json:"qs,string"`
	Skip   string   `json:"-"`
	hidden string
	Nested Inner
	base
	*Ext
}

type Point struct{ X, Y int }

// UnmarshalJSON de receptor ponteiro: "x,y".
func (p *Point) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return fmt.Errorf("point: %w", err)
	}
	xs, ys, ok := strings.Cut(s, ",")
	if !ok {
		return errors.New("point: sem vírgula")
	}
	x, err := strconv.Atoi(xs)
	if err != nil {
		return err
	}
	y, err := strconv.Atoi(ys)
	p.X, p.Y = x, y
	return err
}

type Level struct{ V string }

func (l *Level) UnmarshalText(b []byte) error {
	if len(b) == 0 {
		return errors.New("nível vazio")
	}
	l.V = strings.ToUpper(string(b))
	return nil
}

type Upper string

func (u *Upper) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	*u = Upper(strings.ToUpper(s))
	return nil
}

type WithMarshalers struct {
	P      Point
	PP     *Point
	Points []Point
	L      Level
	LP     *Level
	ByKey  map[Level]int
}

type WithRaw struct {
	Kind string
	Data json.RawMessage
	All  map[string]json.RawMessage
	List []json.RawMessage
	Num  json.Number
	Nums []json.Number
}

type Outer struct {
	A     Inner
	Items []Inner
}

type privEmb struct{ X int }

type HasPrivPtr struct {
	*privEmb
	Y int
}

// kind faz o papel de %T para os tipos que o decode põe em interface{}
// (o fmt do golib_dart não sabe o nome de map/slice sem nome dentro de any).
func kind(x any) string {
	switch x.(type) {
	case nil:
		return "nil"
	case float64:
		return "float64"
	case string:
		return "string"
	case bool:
		return "bool"
	case []any:
		return "[]any"
	case map[string]any:
		return "map[string]any"
	case *Inner:
		return "*main.Inner"
	}
	return "?"
}

func main() {
	src := `{
		"title": "Doc é 😀 \ud800 fim", "COUNT": 3, "small": 7, "u": 65535,
		"f": 1.5, "ok": true, "ptr": {"N": 1, "s": "um"}, "list": [1, 2, 3],
		"arr": [9, 8], "map": {"pi": 3.14, "e": 2.71}, "any": {"a": [1, "b", null, false, {"c": 2.5}]},
		"bytes": "aGVsbG8=", "q": "42", "qs": "\"quoted\"", "Skip": "x", "hidden": "h",
		"nested": {"n": 5, "S": "cinco"}, "id": 77, "kind": "base", "Tag": "ext",
		"unknown": [1, {"deep": true}]
	}`
	var d Doc
	err := json.Unmarshal([]byte(src), &d)
	fmt.Println(err)
	fmt.Printf("%q %d %d %d %v %v\n", d.Title, d.Count, d.Small, d.U, d.F, d.Ok)
	fmt.Printf("%+v %v %v %v\n", *d.Ptr, d.List, d.Arr, d.Map)
	fmt.Printf("%v %s\n", d.Any, kind(d.Any))
	m := d.Any.(map[string]any)
	for _, x := range m["a"].([]any) {
		fmt.Printf("%s:%v ", kind(x), x)
	}
	fmt.Println()
	fmt.Printf("%s %d %q %q %q %+v %d %q %q\n", d.Bytes, d.Q, d.QS, d.Skip, d.hidden, d.Nested, d.ID, d.Kind, d.Ext.Tag)

	// null deixa valores e zera ponteiros, mapas e slices.
	d2 := Doc{Title: "keep", Count: 9, Ptr: &Inner{}, List: []int{1}, Map: map[string]float64{"a": 1}}
	err = json.Unmarshal([]byte(`{"title": null, "count": null, "ptr": null, "list": null, "map": null, "any": null}`), &d2)
	fmt.Println(d2.Title, d2.Count, d2.Ptr == nil, d2.List == nil, d2.Map == nil, d2.Any, err)

	// Slice existente é reaproveitado; array zera o resto ou ignora o excesso.
	nums := []int{7, 7, 7, 7}
	err = json.Unmarshal([]byte(`[1, 2]`), &nums)
	fmt.Println(nums, len(nums), err)
	var arr [3]int = [3]int{5, 5, 5}
	err = json.Unmarshal([]byte(`[1]`), &arr)
	fmt.Println(arr, err)
	err = json.Unmarshal([]byte(`[1, 2, 3, 4, 5]`), &arr)
	fmt.Println(arr, err)
	empty := []string{"x"}
	err = json.Unmarshal([]byte(`[]`), &empty)
	fmt.Println(empty, empty == nil, len(empty), err)
	var pts []Inner
	err = json.Unmarshal([]byte(`[{"N":1},{"N":2,"s":"b"},{}]`), &pts)
	fmt.Printf("%+v %v\n", pts, err)

	// Para interface{}.
	var anyv any
	for _, s := range []string{`1`, `-2.5e3`, `"s"`, `true`, `null`, `[]`, `{}`, `[{"a":{"b":[1]}}]`} {
		err = json.Unmarshal([]byte(s), &anyv)
		fmt.Printf("%s -> %s %v %v\n", s, kind(anyv), anyv, err)
	}
	var target any = &Inner{N: -1}
	err = json.Unmarshal([]byte(`{"N": 10}`), &target)
	fmt.Printf("%s %+v %v\n", kind(target), target, err)

	// Mapas tipados.
	var mi map[int]string
	err = json.Unmarshal([]byte(`{"1":"um","-20":"menos vinte"}`), &mi)
	fmt.Println(mi, err)
	var mu map[uint8]bool
	err = json.Unmarshal([]byte(`{"300":true,"2":false}`), &mu)
	fmt.Println(mu, err)
	var ms map[string][]int
	err = json.Unmarshal([]byte(`{"b":[2],"a":[1,1]}`), &ms)
	fmt.Println(ms, err)

	// Erros de tipo: o decode continua e devolve o primeiro.
	var d3 Doc
	err = json.Unmarshal([]byte(`{"count": "três", "small": 300, "u": -1, "f": 1e40, "ok": 1, "title": 5, "list": {}, "map": [], "q": "x"}`), &d3)
	fmt.Println(err)
	var ute *json.UnmarshalTypeError
	if errors.As(err, &ute) {
		fmt.Println("UnmarshalTypeError:", ute.Value, ute.Type, ute.Offset, ute.Struct, ute.Field)
	}
	for _, s := range []string{`{"small": 300}`, `{"u": -1}`, `{"f": 1e40}`, `{"ok": 1}`, `{"title": 5}`, `{"list": {}}`, `{"map": []}`, `{"q": "x"}`, `{"q": 5}`, `{"qs": 5}`, `{"bytes": "!!"}`, `{"bytes": "aGVsbG8"}`, `{"bytes": 5}`, `{"nested": {"N": "x"}}`, `{"Ptr": {"N": []}}`} {
		var dd Doc
		err = json.Unmarshal([]byte(s), &dd)
		fmt.Println(s, "->", err)
	}
	var o Outer
	err = json.Unmarshal([]byte(`{"A":{"N":"x"}}`), &o)
	fmt.Println(err)
	err = json.Unmarshal([]byte(`{"Items":[{"N":1},{"N":true}]}`), &o)
	fmt.Println(err, len(o.Items))
	var n8 int8
	fmt.Println(json.Unmarshal([]byte(`128`), &n8), n8)
	var u64 uint64
	fmt.Println(json.Unmarshal([]byte(`18446744073709551615`), &u64), u64)
	var f64 float64
	fmt.Println(json.Unmarshal([]byte(`1e400`), &f64), f64)
	var str string
	fmt.Println(json.Unmarshal([]byte(`[1]`), &str), json.Unmarshal([]byte(`{}`), &str))

	// InvalidUnmarshalError.
	fmt.Println(json.Unmarshal([]byte(`1`), nil))
	fmt.Println(json.Unmarshal([]byte(`1`), d))
	var nilp *Doc
	fmt.Println(json.Unmarshal([]byte(`1`), nilp))
	var iue *json.InvalidUnmarshalError
	fmt.Println(errors.As(json.Unmarshal([]byte(`{}`), 5), &iue), iue.Type)

	// SyntaxError com Offset.
	for _, s := range []string{`{"a":1,}`, `[1,2`, `{"a" 1}`, `tru`, `"abc`, `1 2`, `{"a":"\q"}`, "[\"\x01\"]", `[1e+]`, `{,}`, ``, `   `, `[-]`, `{"a":01}`} {
		var x any
		err := json.Unmarshal([]byte(s), &x)
		var se *json.SyntaxError
		if errors.As(err, &se) {
			fmt.Printf("%q -> %v (offset %d)\n", s, se, se.Offset)
		} else {
			fmt.Printf("%q -> %v\n", s, err)
		}
	}

	// Unmarshaler / TextUnmarshaler.
	var wm WithMarshalers
	err = json.Unmarshal([]byte(`{"P":"1,2","PP":"3,4","Points":["5,6","7,8"],"L":"info","LP":"warn","ByKey":{"debug":1,"error":2}}`), &wm)
	fmt.Printf("%+v %+v %+v %+v %+v %v %v\n", wm.P, *wm.PP, wm.Points, wm.L, *wm.LP, wm.ByKey, err)
	err = json.Unmarshal([]byte(`{"P":5}`), &wm)
	fmt.Println(err)
	err = json.Unmarshal([]byte(`{"L":5}`), &wm)
	fmt.Println(err)
	err = json.Unmarshal([]byte(`{"L":""}`), &wm)
	fmt.Println(err)
	err = json.Unmarshal([]byte(`{"L":null,"LP":null}`), &wm)
	fmt.Println(wm.L, wm.LP, err)
	var up Upper
	err = json.Unmarshal([]byte(`"grita"`), &up)
	fmt.Println(up, err)
	var pt Point
	fmt.Println(json.Unmarshal([]byte(`"9,9"`), &pt), pt)

	// RawMessage e Number.
	var wr WithRaw
	err = json.Unmarshal([]byte(`{"Kind":"x","Data": {"a" : [1, 2]} ,"All":{"k":"v","n":null},"List":[1,"2",[3]],"Num":12.50,"Nums":[1,-2e3]}`), &wr)
	fmt.Printf("%s|%s|%s|%s|%s|%v|%s|%v\n", wr.Kind, wr.Data, wr.All["k"], wr.All["n"], wr.List[2], len(wr.List), wr.Num, wr.Nums)
	f, ferr := wr.Num.Float64()
	i, ierr := wr.Num.Int64()
	fmt.Println(f, ferr, i, ierr, wr.Num.String())
	out, err := json.Marshal(wr)
	fmt.Println(string(out), err)
	err = json.Unmarshal([]byte(`{"Num":"7"}`), &wr)
	fmt.Println(wr.Num, err)
	err = json.Unmarshal([]byte(`{"Num":"x7"}`), &wr)
	fmt.Println(wr.Num, err)

	// Embutidos.
	var hp HasPrivPtr
	err = json.Unmarshal([]byte(`{"X": 1, "Y": 2}`), &hp)
	fmt.Println(hp.Y, hp.privEmb == nil, err)
}
