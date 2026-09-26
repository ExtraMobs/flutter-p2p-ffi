package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"strconv"
)

func errText(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func main() {
	inputs := []string{"", "0", "-0", "+0", "1", "-1", "+", "-", "42", "-42", "007", "0x", "0x1f", "0X1F",
		"0b101", "0B2", "0o17", "0O8", "017", "08", "1_000", "_1", "1__0", "0x_1f", "0_x1", "1_", "0b_1_0",
		"255", "256", "-128", "-129", "127", "128", "4294967295", "4294967296", "-2147483648", "-2147483649",
		"9223372036854775807", "9223372036854775808", "-9223372036854775808", "-9223372036854775809",
		"18446744073709551615", "18446744073709551616", "99999999999999999999", "zz", "ZZ", "z1", "1.5",
		" 1", "1 ", "é", "\xff", "12345678901234567", "123456789012345678", "1234567890123456789",
		"-123456789012345678", "\"q\""}
	bases := []int{0, 2, 8, 10, 16, 36, 1, 37}
	bits := []int{0, 8, 32, 64, 65, -1}
	var out []string
	for _, s := range inputs {
		for _, b := range bases {
			for _, bs := range bits {
				u, ue := strconv.ParseUint(s, b, bs)
				i, ie := strconv.ParseInt(s, b, bs)
				out = append(out, fmt.Sprintf("%d %s|%d %s", u, errText(ue), i, errText(ie)))
			}
		}
		a, ae := strconv.Atoi(s)
		out = append(out, fmt.Sprintf("%d %s", a, errText(ae)))
	}
	for _, v := range []int64{0, 1, -1, 35, -36, 255, math.MaxInt64, math.MinInt64} {
		for _, b := range []int{2, 8, 10, 16, 36} {
			out = append(out, strconv.FormatInt(v, b)+" "+strconv.FormatUint(uint64(v), b))
		}
		out = append(out, strconv.Itoa(int(v)))
	}
	var hexIn []string // hex: o JSON trocaria bytes UTF-8 inválidos por U+FFFD
	for _, s := range inputs {
		hexIn = append(hexIn, fmt.Sprintf("%x", s))
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]any{"in": hexIn, "out": out}); err != nil {
		panic(err)
	}
}
