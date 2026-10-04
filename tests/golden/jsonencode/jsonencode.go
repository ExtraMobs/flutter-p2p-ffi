// Fixture do shim encoding/json (encode): regras de campos, tags, mapas
// ordenados, base64, escapes, floats, Marshaler/TextMarshaler, erros e
// Indent/Compact/Valid/HTMLEscape.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strings"
)

func show(v any) {
	b, err := json.Marshal(v)
	if err != nil {
		fmt.Println("erro:", err)
		return
	}
	fmt.Println(string(b))
}

type Inner struct {
	A int
	B string `json:"b"`
}

type inner2 struct {
	Promoted int
	hidden   int
}

type Basic struct {
	Name     string            `json:"name"`
	Age      int               `json:"age,omitempty"`
	Email    string            `json:",omitempty"`
	Skip     int               `json:"-"`
	Dash     int               `json:"-,"`
	Quoted   int64             `json:"q,string"`
	QStr     string            `json:"qs,string"`
	QBool    bool              `json:",string"`
	Ptr      *Inner            `json:"ptr"`
	Nil      *Inner            `json:"nil,omitempty"`
	Tags     []string          `json:"tags"`
	NilSlice []int             `json:"nils"`
	Empty    []int             `json:"empty"`
	Map      map[string]int    `json:"map"`
	NilMap   map[string]string `json:"nilmap"`
	Bytes    []byte            `json:"bytes"`
	Arr      [3]uint8          `json:"arr"`
	Any      any               `json:"any"`
	F32      float32
	private  int
	Inner
	inner2
}

type Depth1 struct{ X int }
type Depth2 struct{ X int }
type Tagged struct {
	X int `json:"X"`
}

// Conflito: Depth1.X e Depth2.X no mesmo nível se anulam; Tagged.X (com
// tag) vence o X sem tag do mesmo nível; o X raso vence todos.
type Conflict struct {
	Depth1
	Depth2
	Y int
}
type TagWins struct {
	Depth1
	Tagged
}
type Shallow struct {
	Depth1
	X string
}

type EmbPtr struct {
	*Inner
	Z int
}

type Celsius float64
type Names []string
type Dict map[string]Celsius

type Point struct{ X, Y int }

// MarshalJSON de receptor valor.
func (p Point) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`"%d<%d>"`, p.X, p.Y)), nil
}

type PtrM struct{ N int }

// MarshalJSON de receptor ponteiro: só vale quando o valor é endereçável.
func (p *PtrM) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`{"ptr": %d }`, p.N)), nil
}

type Holder struct {
	V PtrM
	P *PtrM
}

type Key struct{ A, B string }

func (k Key) MarshalText() ([]byte, error) { return []byte(k.A + "-" + k.B), nil }

type Color int

func (c Color) MarshalText() ([]byte, error) {
	return []byte([]string{"red", "green", "blue"}[c]), nil
}

type Bad struct{}

func (Bad) MarshalJSON() ([]byte, error) { return []byte(`{bad`), nil }

type Fails struct{}

func (Fails) MarshalJSON() ([]byte, error) { return nil, errors.New("boom") }

type TextFails struct{}

func (TextFails) MarshalText() ([]byte, error) { return nil, errors.New("sem texto") }

type Zeroer struct{ V int }

func (z Zeroer) IsZero() bool { return z.V < 0 }

type OmitZero struct {
	A int     `json:",omitzero"`
	B string  `json:",omitzero"`
	P *int    `json:",omitzero"`
	S []int   `json:",omitzero"`
	Z Zeroer  `json:",omitzero"`
	T Point   `json:",omitzero"`
	F float64 `json:",omitzero"`
}

type Node struct {
	Name string
	Next *Node `json:",omitempty"`
}

type WithNumber struct {
	N json.Number
	M json.Number `json:",omitempty"`
}

type Unicode struct {
	Ação   string `json:"ação"`
	Html   string `json:"<b>&"`
	Weird  string `json:"a b"`
	BadTag string `json:"a\\b"`
}

func main() {
	// Básicos.
	show(nil)
	show(true)
	show(42)
	show(-7)
	show(uint64(18446744073709551615))
	show(int8(-128))
	show("olá \"mundo\"\n\t\\ <a href='x'>&</a>")
	show("ctrl:\x01\x1f\x7f bad:\xff\xfe sep:   ok:é")
	show(3.0)
	show(0.1)
	show(1e20)
	show(1e21)
	show(1e-6)
	show(1e-7)
	show(123456789.125)
	show(-0.0)
	show(float32(0.1))
	show(float32(1e21))
	show(float32(1e-7))
	show(float32(3.4e38))
	show(math.MaxFloat64)
	show(math.SmallestNonzeroFloat64)
	show(Celsius(36.6))
	show([]float64{1.5e300, -2.5e-300, 100})

	// Structs com tags.
	n := 5
	_ = n
	b := Basic{
		Name: "Ana", Skip: 1, Dash: 2, Quoted: 99, QStr: "x\"y", QBool: true,
		Ptr: &Inner{A: 1, B: "in"}, Tags: []string{"a", "b"}, Empty: []int{},
		Map: map[string]int{"z": 26, "a": 1, "m": 13}, Bytes: []byte("hello, world!"),
		Arr: [3]uint8{1, 2, 3}, Any: map[string]any{"k": []any{1, "dois", nil, true}},
		F32: 2.5, private: 7, Inner: Inner{A: 10, B: "emb"}, inner2: inner2{Promoted: 3},
	}
	show(b)
	show(&b)
	show(Conflict{Depth1{1}, Depth2{2}, 3})
	show(TagWins{Depth1{1}, Tagged{2}})
	show(Shallow{Depth1{1}, "raso"})
	show(EmbPtr{Z: 1})
	show(EmbPtr{Inner: &Inner{A: 5}, Z: 1})
	show(Unicode{"sim", "h", "w", "bt"})
	show(struct {
		A int `json:"a"`
		b int
	}{1, 2})

	// Mapas: chaves ordenadas como string.
	show(map[int]string{10: "dez", 2: "dois", -1: "menos um", 100: "cem"})
	show(map[uint8]bool{3: true, 1: false})
	show(map[Key]int{{"b", "1"}: 2, {"a", "9"}: 1})
	show(map[Color]string{2: "B", 0: "R"})
	show(Dict{"quente": 40.5, "frio": -3})
	show(map[string]any{"z": nil, "a": map[string]any{"y": 1, "x": []int(nil)}})
	show(map[string]int(nil))

	// Slices, arrays, nomeados.
	show([]byte{})
	show([]byte(nil))
	show([]byte{0, 255, 128})
	show([2][]byte{[]byte("ab"), nil})
	show(Names{"x", "y"})
	show(Names(nil))
	show([0]int{})
	show([]any{1, 2.5, "s", false, nil, []string{}})

	// Marshaler e TextMarshaler.
	show(Point{1, 2})
	show(&Point{3, 4})
	show([]Point{{5, 6}})
	show(PtrM{7})
	show(&PtrM{8})
	h := Holder{V: PtrM{9}, P: &PtrM{10}}
	show(h)
	show(&h)
	show([]PtrM{{11}})
	show(Key{"k", "v"})
	show(Color(1))
	show([]Color{0, 2})
	show(Bad{})
	show(Fails{})
	show(TextFails{})
	show(map[string]Bad{"x": {}})

	// omitzero / omitempty.
	show(OmitZero{})
	z := 0
	show(OmitZero{A: 1, B: "b", P: &z, S: []int{}, Z: Zeroer{-1}, T: Point{1, 1}, F: 0.5})
	show(OmitZero{Z: Zeroer{0}})

	// Number.
	show(WithNumber{N: "12.50"})
	show(WithNumber{})
	show(WithNumber{N: "1e5", M: "-0"})
	show(WithNumber{N: "abc"})
	show(json.Number("7"))

	// Erros.
	show(math.NaN())
	show(math.Inf(-1))
	show(float32(math.Inf(1)))
	show([]chan int{nil})
	show(func() {})
	show(map[[2]int]int{{1, 2}: 3})
	show(complex(1, 2))
	show(struct{ C chan int }{})
	_, err := json.Marshal(Fails{})
	var me *json.MarshalerError
	if errors.As(err, &me) {
		fmt.Println("MarshalerError:", me.Type, me.Err, errors.Unwrap(err))
	}
	_, err = json.Marshal(math.NaN())
	if ue, ok := err.(*json.UnsupportedValueError); ok {
		fmt.Println("UnsupportedValueError:", ue.Str)
	}
	_, err = json.Marshal(map[string]chan bool{"c": nil})
	if te, ok := err.(*json.UnsupportedTypeError); ok {
		fmt.Println("UnsupportedTypeError:", te.Type)
	}

	// Ciclo: detectado depois de 1000 níveis.
	cyc := &Node{Name: "a"}
	cyc.Next = &Node{Name: "b", Next: cyc}
	show(cyc)
	show(&Node{Name: "fim", Next: &Node{Name: "x"}})

	// MarshalIndent, Indent, Compact, Valid, HTMLEscape.
	out, _ := json.MarshalIndent(map[string]any{"a": []int{1, 2}, "b": map[string]any{}, "c": []int{}}, ">", "  ")
	fmt.Println(string(out))
	out, _ = json.MarshalIndent(Inner{1, "x"}, "", "\t")
	fmt.Println(string(out))
	var buf bytes.Buffer
	err = json.Indent(&buf, []byte(` { "a" : [ 1 , 2 ] , "b" : { } } `), "", " ")
	fmt.Printf("%q %v\n", buf.String(), err)
	buf.Reset()
	err = json.Indent(&buf, []byte(`{"a":`), "", " ")
	fmt.Printf("%q %v\n", buf.String(), err)
	buf.Reset()
	err = json.Compact(&buf, []byte("{ \"a\" :\n [1, 2, \"<x>\"] }"))
	fmt.Printf("%q %v\n", buf.String(), err)
	buf.Reset()
	err = json.Compact(&buf, []byte(`[1,]`))
	fmt.Printf("%q %v\n", buf.String(), err)
	buf.Reset()
	json.HTMLEscape(&buf, []byte(`{"h":"<b>&amp;</b>","s":"`+" "+`"}`))
	fmt.Println(buf.String())
	for _, s := range []string{`{}`, `[1, 2]`, `"x"`, `{"a":}`, `[1 2]`, ``, ` 1 `, `nul`, `01`, `-`, `1.`, `1e`, `"\x"`, "\"\x01\"", `{"a":1}}`} {
		fmt.Printf("valid %q %v\n", s, json.Valid([]byte(s)))
	}

	// Encoder.
	var sb strings.Builder
	enc := json.NewEncoder(&sb)
	enc.Encode(map[string]string{"html": "<&>"})
	enc.SetEscapeHTML(false)
	enc.Encode(map[string]string{"html": "<&>"})
	enc.SetIndent("#", "--")
	enc.Encode([]any{1, map[string]int{"a": 1}})
	fmt.Printf("%q\n", enc.Encode(math.NaN()))
	fmt.Print(sb.String())
	var bb bytes.Buffer
	enc2 := json.NewEncoder(&bb)
	for i := 0; i < 3; i++ {
		enc2.Encode(Point{i, i * i})
	}
	fmt.Print(bb.String())
}
