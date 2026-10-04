// Fixture do shim encoding/json (streams): Decoder com vários valores,
// Token/More, InputOffset/Buffered, EOF, UseNumber, DisallowUnknownFields,
// leitor em pedaços e ida e volta com o Encoder.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
)

type Msg struct {
	Name string `json:"name"`
	N    int    `json:"n"`
}

// chunky entrega no máximo k bytes por Read e registra os pedidos.
type chunky struct {
	data []byte
	k    int
	log  []int
}

func (c *chunky) Read(p []byte) (int, error) {
	c.log = append(c.log, len(p))
	if len(c.data) == 0 {
		return 0, io.EOF
	}
	n := c.k
	if n > len(p) {
		n = len(p)
	}
	if n > len(c.data) {
		n = len(c.data)
	}
	copy(p, c.data[:n])
	c.data = c.data[n:]
	return n, nil
}

func describe(t json.Token) string {
	switch v := t.(type) {
	case json.Delim:
		return "Delim(" + v.String() + ")"
	case string:
		return fmt.Sprintf("string(%q)", v)
	case float64:
		return fmt.Sprintf("float64(%v)", v)
	case json.Number:
		return "Number(" + v.String() + ")"
	case bool:
		return fmt.Sprintf("bool(%v)", v)
	case nil:
		return "nil"
	}
	return "?"
}

func main() {
	// Vários valores seguidos, separados por espaço.
	dec := json.NewDecoder(strings.NewReader(`{"name":"a","n":1} {"name":"b","n":2}
	[1,2] "fim" 3.5 null`))
	for {
		var v any
		err := dec.Decode(&v)
		if err == io.EOF {
			fmt.Println("EOF", dec.InputOffset())
			break
		}
		fmt.Println(v, err, dec.InputOffset(), dec.More())
	}

	// Decode tipado + Buffered.
	dec = json.NewDecoder(strings.NewReader(`{"name":"x","n":7} resto`))
	var m Msg
	fmt.Println(dec.Decode(&m), m)
	rest, _ := io.ReadAll(dec.Buffered())
	fmt.Printf("%q\n", rest)

	// Tokens.
	dec = json.NewDecoder(strings.NewReader(` {"a": [1, "dois", true, null, {"b": -2.5e1}], "c": {}} [] `))
	for {
		t, err := dec.Token()
		if err != nil {
			fmt.Println("Token:", err)
			break
		}
		fmt.Println(describe(t), dec.More(), dec.InputOffset())
	}

	// Tokens + Decode de um array grande, elemento a elemento.
	dec = json.NewDecoder(strings.NewReader(`[{"name":"p","n":1},{"name":"q","n":2},{"name":"r","n":3}]`))
	t, err := dec.Token()
	fmt.Println(describe(t), err)
	for dec.More() {
		var mm Msg
		err := dec.Decode(&mm)
		fmt.Println(mm, err)
	}
	t, err = dec.Token()
	fmt.Println(describe(t), err)
	t, err = dec.Token()
	fmt.Println(describe(t), err)

	// Erros de sintaxe nos tokens.
	for _, s := range []string{`{"a" 1}`, `[1 2]`, `{1:2}`, `]`, `{"a":1,}`, `[,]`, `}`} {
		dec = json.NewDecoder(strings.NewReader(s))
		var out []string
		for {
			t, err := dec.Token()
			if err != nil {
				out = append(out, "erro: "+err.Error())
				break
			}
			out = append(out, describe(t))
		}
		fmt.Printf("%s -> %s\n", s, strings.Join(out, " "))
	}

	// EOF no meio do valor.
	for _, s := range []string{``, `   `, `{"a":`, `[1,2`, `"abc`, `tru`} {
		dec = json.NewDecoder(strings.NewReader(s))
		var v any
		err := dec.Decode(&v)
		fmt.Printf("%q -> %v %v %v\n", s, err, errors.Is(err, io.EOF), errors.Is(err, io.ErrUnexpectedEOF))
	}
	dec = json.NewDecoder(strings.NewReader(`{"a": 1}  x`))
	var v1, v2 any
	fmt.Println(dec.Decode(&v1), v1)
	fmt.Println(dec.Decode(&v2), v2)

	// UseNumber e DisallowUnknownFields.
	dec = json.NewDecoder(strings.NewReader(`{"big": 12345678901234567890, "f": 1.50, "l": [1e2]}`))
	dec.UseNumber()
	var nv map[string]any
	fmt.Println(dec.Decode(&nv))
	fmt.Println(describe(nv["big"]), describe(nv["f"]), nv["l"])
	dec = json.NewDecoder(strings.NewReader(`{"name":"a","zzz":1}`))
	dec.DisallowUnknownFields()
	var dm Msg
	fmt.Println(dec.Decode(&dm), dm)
	dec = json.NewDecoder(strings.NewReader(`{"name":"a","n":1}`))
	dec.DisallowUnknownFields()
	fmt.Println(dec.Decode(&dm), dm)
	dec = json.NewDecoder(strings.NewReader(`[1, 2]`))
	dec.UseNumber()
	for {
		t, err := dec.Token()
		if err != nil {
			break
		}
		fmt.Print(describe(t), " ")
	}
	fmt.Println()

	// Leitor em pedaços: a sequência de len(p) segue o crescimento do buffer.
	big := strings.Repeat(`{"name":"item","n":12345} `, 40)
	c := &chunky{data: []byte(big), k: 7}
	dec = json.NewDecoder(c)
	count := 0
	for {
		var mm Msg
		if err := dec.Decode(&mm); err != nil {
			fmt.Println(err, count, mm)
			break
		}
		count++
	}
	fmt.Println(c.log)

	// Encoder -> Decoder.
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	for i, name := range []string{"um", "dois", "<três>"} {
		enc.Encode(Msg{name, i})
	}
	enc.SetIndent("", " ")
	enc.SetEscapeHTML(false)
	enc.Encode(map[string]any{"z": []int{1}, "a": "<&>"})
	fmt.Print(buf.String())
	dec = json.NewDecoder(&buf)
	for dec.More() {
		var v any
		err := dec.Decode(&v)
		fmt.Println(v, err)
	}

	// RawMessage no stream (como campo: no Dart, json.RawMessage solto numa
	// interface é indistinguível de []byte).
	dec = json.NewDecoder(strings.NewReader(`{"R": {"k": [1, {"x": 2}]}} {"R": 5}`))
	var raw struct{ R json.RawMessage }
	fmt.Println(dec.Decode(&raw), string(raw.R))
	fmt.Println(dec.Decode(&raw), string(raw.R))
}
