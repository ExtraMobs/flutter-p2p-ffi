// Package attr imita go.opentelemetry.io/otel/attribute: constantes `BOOL`,
// `INT64`, `STRING` e funções `Bool`, `Int64`, `String` no mesmo pacote.
package attr

import "fmt"

type Type int

const (
	INVALID Type = iota
	BOOL
	INT64
	STRING
)

type KeyValue struct {
	Key   string
	Type  Type
	Value any
}

func Bool(k string, v bool) KeyValue    { return KeyValue{k, BOOL, v} }
func Int64(k string, v int64) KeyValue  { return KeyValue{k, INT64, v} }
func String(k, v string) KeyValue       { return KeyValue{k, STRING, v} }
func (kv KeyValue) Describe() string    { return fmt.Sprint(kv.Key, "=", kv.Value, " (", kv.Type, ")") }

var PDF, Pdf = "application/pdf", "pdf"
