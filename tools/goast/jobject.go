package main

import (
	"bytes"
	"encoding/json"
)

// jobject é um objeto JSON com ordem de campos preservada (json.Marshal de
// mapas ordenaria alfabeticamente; a AST exige a ordem de declaração).
type jobject []jpair

type jpair struct {
	key string
	val any
}

func (j jobject) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, p := range j {
		if i > 0 {
			b.WriteByte(',')
		}
		k, err := json.Marshal(p.key)
		if err != nil {
			return nil, err
		}
		b.Write(k)
		b.WriteByte(':')
		v, err := json.Marshal(p.val)
		if err != nil {
			return nil, err
		}
		b.Write(v)
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}
