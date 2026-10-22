// O valor dinâmico do protocolo (WIRE.md, "Value encoding"): `any` do Go,
// num formato com etiqueta que o Dart lê como Object?. Etiquetas: 0 nulo,
// 1 bool, 2 i64, 3 f64, 4 string, 5 bytes, 6 lista (i32 n + itens), 7 mapa
// (i32 n + pares str chave + item).
package main

import (
	"encoding"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"time"
)

const (
	anyNull = iota
	anyBool
	anyInt
	anyFloat
	anyString
	anyBytes
	anyList
	anyMap
)

func encAny(w *writer, v any) { encAnyValue(w, reflect.ValueOf(v)) }

var textMarshaler = reflect.TypeFor[encoding.TextMarshaler]()

// encAnyValue: ponteiros e interfaces são seguidos; tipos com MarshalText
// (CID, peer ID, multiaddr...) e time.Time saem como string; structs como
// mapa dos campos exportados (o nome do json, se houver); mapas com as
// chaves em ordem, para a saída ser estável.
func encAnyValue(w *writer, v reflect.Value) {
	for v.IsValid() && (v.Kind() == reflect.Interface || v.Kind() == reflect.Pointer) {
		if v.IsNil() {
			w.u8(anyNull)
			return
		}
		v = v.Elem()
	}
	if !v.IsValid() {
		w.u8(anyNull)
		return
	}
	if v.CanInterface() {
		switch x := v.Interface().(type) {
		case time.Time:
			w.u8(anyString)
			w.str(x.Format(time.RFC3339Nano))
			return
		case []byte:
			w.u8(anyBytes)
			w.bytes(x)
			return
		}
		if v.Type().Implements(textMarshaler) && v.Kind() != reflect.String {
			if b, err := v.Interface().(encoding.TextMarshaler).MarshalText(); err == nil {
				w.u8(anyString)
				w.str(string(b))
				return
			}
		}
	}
	switch v.Kind() {
	case reflect.Bool:
		w.u8(anyBool)
		w.bool(v.Bool())
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		w.u8(anyInt)
		w.i64(v.Int())
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		w.u8(anyInt) // ponytail: acima de 2^63 o Dart (int de 64 bits) vê negativo
		w.i64(int64(v.Uint()))
	case reflect.Float32, reflect.Float64:
		w.u8(anyFloat)
		w.f64(v.Float())
	case reflect.String:
		w.u8(anyString)
		w.str(v.String())
	case reflect.Slice, reflect.Array:
		if v.Kind() == reflect.Slice && v.IsNil() {
			w.u8(anyNull)
			return
		}
		w.u8(anyList)
		w.i32(int32(v.Len()))
		for i := range v.Len() {
			encAnyValue(w, v.Index(i))
		}
	case reflect.Map:
		if v.IsNil() {
			w.u8(anyNull)
			return
		}
		keys := v.MapKeys()
		names := make([]string, len(keys))
		for i, k := range keys {
			names[i] = anyKey(k)
		}
		order := make([]int, len(keys))
		for i := range order {
			order[i] = i
		}
		sort.Slice(order, func(a, b int) bool { return names[order[a]] < names[order[b]] })
		w.u8(anyMap)
		w.i32(int32(len(keys)))
		for _, i := range order {
			w.str(names[i])
			encAnyValue(w, v.MapIndex(keys[i]))
		}
	case reflect.Struct:
		var fields []int
		for i := range v.NumField() {
			if f := v.Type().Field(i); f.IsExported() && jsonName(f) != "-" {
				fields = append(fields, i)
			}
		}
		w.u8(anyMap)
		w.i32(int32(len(fields)))
		for _, i := range fields {
			w.str(jsonName(v.Type().Field(i)))
			encAnyValue(w, v.Field(i))
		}
	default:
		w.u8(anyString)
		w.str(fmt.Sprint(v))
	}
}

// anyKey: a chave de um mapa como string (MarshalText, ou o texto do valor).
func anyKey(k reflect.Value) string {
	if k.Kind() == reflect.String {
		return k.String()
	}
	if k.CanInterface() && k.Type().Implements(textMarshaler) {
		if b, err := k.Interface().(encoding.TextMarshaler).MarshalText(); err == nil {
			return string(b)
		}
	}
	return fmt.Sprint(k)
}

// jsonName: o nome do campo no json (a tag), ou o nome Go.
func jsonName(f reflect.StructField) string {
	if tag, ok := f.Tag.Lookup("json"); ok {
		if name, _, _ := strings.Cut(tag, ","); name != "" {
			return name
		}
	}
	return f.Name
}

// decAny: o valor dinâmico como os tipos do encoding/json (nil, bool, int64,
// float64, string, []byte, []any, map[string]any).
func decAny(r *reader) (any, error) {
	switch t := r.u8(); t {
	case anyNull:
		return nil, r.err
	case anyBool:
		return r.bool(), r.err
	case anyInt:
		return r.i64(), r.err
	case anyFloat:
		return r.f64(), r.err
	case anyString:
		return r.str(), r.err
	case anyBytes:
		return r.bytes(), r.err
	case anyList:
		n := r.count()
		out := make([]any, 0, max(n, 0))
		for range n {
			v, err := decAny(r)
			if err != nil {
				return nil, err
			}
			out = append(out, v)
		}
		return out, r.err
	case anyMap:
		n := r.count()
		out := make(map[string]any, max(n, 0))
		for range n {
			k := r.str()
			v, err := decAny(r)
			if err != nil {
				return nil, err
			}
			out[k] = v
		}
		return out, r.err
	default:
		return nil, fmt.Errorf("ipfs_host: unknown dynamic value tag %d", t)
	}
}
