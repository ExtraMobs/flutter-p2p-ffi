package main

import (
	"go/constant"
	"strconv"
	"unicode/utf8"
)

// constValue serializa um valor constante. Strings vão decodificadas (o
// consumidor nunca interpreta literais Go); ints em decimal exato.
func constValue(v constant.Value) jobject {
	switch v.Kind() {
	case constant.String:
		sv := constant.StringVal(v)
		d := jobject{{"kind", "string"}, {"value", sv}}
		if !utf8.ValidString(sv) {
			// JSON troca bytes inválidos por U+FFFD; os bytes exatos vão à parte.
			bs := make([]int, len(sv))
			for i := range len(sv) {
				bs[i] = int(sv[i])
			}
			d = append(d, jpair{"bytes", bs})
		}
		return d
	case constant.Bool:
		return jobject{{"kind", "bool"}, {"value", constant.BoolVal(v)}}
	case constant.Int:
		return jobject{{"kind", "int"}, {"value", v.ExactString()}}
	case constant.Float:
		f, _ := constant.Float64Val(v)
		return jobject{{"kind", "float"}, {"value", strconv.FormatFloat(f, 'g', -1, 64)}}
	case constant.Complex:
		re, _ := constant.Float64Val(constant.Real(v))
		im, _ := constant.Float64Val(constant.Imag(v))
		return jobject{{"kind", "complex"}, {"real", strconv.FormatFloat(re, 'g', -1, 64)},
			{"imag", strconv.FormatFloat(im, 'g', -1, 64)}}
	default:
		return jobject{{"kind", "unknown"}}
	}
}
