// Package cmdschema decide como o valor que um comando do kubo emite atravessa
// o canal (WIRE.md, "Comandos"): o gerador (go/gen) o usa para escrever os
// DTOs Dart e o host para codificar o valor, pelo mesmo reflect.Type. Os dois
// lados leem daqui o tipo de cada campo e a ordem deles, e por isso não
// divergem.
package cmdschema

import (
	"encoding"
	"fmt"
	"reflect"
	"time"
)

// Kind: como um tipo atravessa.
type Kind int

const (
	Skip     Kind = iota // func, chan, complex, unsafe: não atravessa
	Bool                 // u8
	Int                  // i64 (inteiros com sinal)
	Uint                 // i64 (sem sinal; acima de 2^63 o Dart vê negativo)
	Float                // f64
	String               // string
	Bytes                // []byte: i32 n + bytes, -1 = nil
	Text                 // MarshalText/String (CID, peer ID, multiaddr...): string
	Time                 // time.Time: u8 presente + i64 nanossegundos Unix
	Duration             // time.Duration: i64 nanossegundos
	List                 // slice/array: i32 n + itens, -1 = nil
	Map                  // map: i32 n + (string chave, valor), -1 = nil; chaves em ordem
	Struct               // os campos de Fields, em ordem, sem presença
	Ptr                  // u8 presente + o valor apontado
	Any                  // interface: o valor dinâmico (WIRE.md, kAny)
)

var (
	textMarshaler = reflect.TypeFor[encoding.TextMarshaler]()
	stringer      = reflect.TypeFor[fmt.Stringer]()
	timeType      = reflect.TypeFor[time.Time]()
	durationType  = reflect.TypeFor[time.Duration]()
)

// Of: como [t] atravessa.
func Of(t reflect.Type) Kind {
	switch {
	case t == timeType:
		return Time
	case t == durationType:
		return Duration
	case t.Kind() != reflect.Interface && t.Kind() != reflect.Pointer && isText(t):
		return Text
	}
	switch t.Kind() {
	case reflect.Bool:
		return Bool
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return Int
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		return Uint
	case reflect.Float32, reflect.Float64:
		return Float
	case reflect.String:
		return String
	case reflect.Slice, reflect.Array:
		if t.Elem().Kind() == reflect.Uint8 {
			return Bytes
		}
		return List
	case reflect.Map:
		return Map
	case reflect.Struct:
		return Struct
	case reflect.Pointer:
		return Ptr
	case reflect.Interface:
		return Any
	}
	return Skip
}

// isText: tipo que se escreve como texto: MarshalText (peer.ID, multiaddr,
// cid.Cid), ou um struct sem campo exportado que só tem String().
func isText(t reflect.Type) bool {
	if t.Implements(textMarshaler) || reflect.PointerTo(t).Implements(textMarshaler) {
		return true
	}
	if t.Kind() == reflect.Struct && len(Fields(t)) == 0 {
		return t.Implements(stringer) || reflect.PointerTo(t).Implements(stringer)
	}
	return false
}

// Field: um campo que atravessa; Index é o caminho do reflect (embutidos
// achatados, como no JSON).
type Field struct {
	Name  string
	Index []int
	Type  reflect.Type
}

// Fields: os campos exportados de [t] que atravessam, em ordem; um struct
// embutido por valor é achatado; `json:"-"` fica de fora.
func Fields(t reflect.Type) []Field {
	var out []Field
	for i := range t.NumField() {
		f := t.Field(i)
		if f.Tag.Get("json") == "-" {
			continue
		}
		if f.Anonymous && f.Type.Kind() == reflect.Struct && !isTextStruct(f.Type) {
			for _, g := range Fields(f.Type) {
				out = append(out, Field{g.Name, append([]int{i}, g.Index...), g.Type})
			}
			continue
		}
		if !f.IsExported() || Of(f.Type) == Skip {
			continue
		}
		out = append(out, Field{f.Name, []int{i}, f.Type})
	}
	return out
}

// isTextStruct: struct embutido que é texto (não se achata).
func isTextStruct(t reflect.Type) bool {
	return t.Implements(textMarshaler) || reflect.PointerTo(t).Implements(textMarshaler)
}

// TextOf: o texto de um valor Text.
func TextOf(v reflect.Value) string {
	if v.CanInterface() {
		if m, ok := v.Interface().(encoding.TextMarshaler); ok {
			if b, err := m.MarshalText(); err == nil {
				return string(b)
			}
			return ""
		}
		if v.CanAddr() {
			if m, ok := v.Addr().Interface().(encoding.TextMarshaler); ok {
				if b, err := m.MarshalText(); err == nil {
					return string(b)
				}
				return ""
			}
		}
		if s, ok := v.Interface().(fmt.Stringer); ok {
			return s.String()
		}
	}
	return fmt.Sprint(v)
}
