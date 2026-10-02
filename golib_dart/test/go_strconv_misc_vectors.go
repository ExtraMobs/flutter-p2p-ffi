// Oráculo de strconv (bool, Quote*, Unquote*, Append*, FormatFloat, ParseFloat):
// imprime as entradas (hex, o JSON trocaria UTF-8 inválido) e a saída do Go.
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"os"
	"strconv"
)

func errText(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func fbits(f float64) string {
	if f != f {
		return "NaN"
	}
	return fmt.Sprintf("%016x", math.Float64bits(f))
}

func main() {
	strs := []string{"", "1", "t", "T", "true", "TRUE", "True", "tRUE", "0", "f", "F", "false", "FALSE", "False", "yes",
		"a", "abc", "hello, world", "tab\there", "nl\nx", "q\"uote", "s'ingle", "back\\slash", "`raw`", "ünï", "日本語",
		"\x00\x01\x1f\x7f", "\xff\xfe", "a\xffb", "\u00a0nbsp", "\u200b", "\U0001F600", "\ufeff", "\uffff", "\U0010ffff",
		"\a\b\f\r\v", "\"\"", "''", "'a'", "'\\n'", "\"a\\tb\"", "\"\\x41\\u00e9\\U0001F600\"", "\"\\101\"", "\"\\400\"",
		"\"\\xz\"", "\"\\u12\"", "\"\\ud800\"", "\"\\U00110000\"", "\"\\'\"", "'\\\"'", "'\\''", "'ab'", "'", "\"", "\"abc",
		"`a\r\nb`", "`a`b`", "`", "``", "\"a\nb\"", "\"\xff\"", "'\xff'", "\"\\xff\"", "\"é\"", "'é'", "\"x\" ", "x",
		"\"\\\"", "\"\\", "\"\\8\"", "\"\\z\""}
	runes := []rune{0, 7, 8, 9, 10, 11, 12, 13, 27, 31, 32, 34, 39, 92, 96, 126, 127, 128, 159, 160, 173, 0xe9, 0x100,
		0x2028, 0x200b, 0x3000, 0xd7ff, 0xd800, 0xdfff, 0xe000, 0xfeff, 0xfffc, 0xfffd, 0xffff, 0x10000, 0x1f600,
		0x10ffff, 0x110000, -1, 0x65e5}
	rng := rand.New(rand.NewSource(7))
	floats := []float64{0, math.Copysign(0, -1), 1, -1, 0.5, 0.1, 0.2, 0.3, 1.5, 2.5, 10, 100, 123456789, 1e6, 1e20,
		1e21, 1e22, 1e23, 1e-4, 1e-5, 1e-7, 123.456, 5e-324, math.MaxFloat64, math.SmallestNonzeroFloat64,
		math.MaxFloat32, 1.0 / 3, 2.0 / 3, math.Pi, math.E, 0.000123, 999999.5, 9.5, 0.95, 99.5, 4.35, 8.41,
		math.Inf(1), math.Inf(-1), math.NaN(), 1e100, 123456.7, 0.9999999}
	for i := 0; i < 300; i++ {
		floats = append(floats, math.Float64frombits(rng.Uint64()))
	}
	for i := 0; i < 200; i++ {
		floats = append(floats, float64(rng.Int63n(1e9))/float64(int64(1)<<uint(rng.Intn(20))))
	}
	for i := 0; i < 200; i++ {
		strs = append(strs, strconv.FormatFloat(floats[i], "eEfgG"[rng.Intn(5)], rng.Intn(25)-1, 64))
	}
	fl := []string{"0", "-0", "+0", "1", "-1", "1.5", ".5", "5.", ".", "+", "-", "e5", "1e", "1e+", "1e5", "1E5", "1e-5",
		"1.e3", "0x", "0x1p0", "0x1p-2", "0X1P+3", "0x.8p1", "0x1.8p1", "0x1", "0xp1", "0x_1p0", "0x1_0p0", "1_0", "1__0",
		"_1", "1_", "1_0.5", "1.5_5", "1e1_0", "0b1", "0o7", "inf", "Inf", "INF", "+inf", "-Inf", "infinity", "-Infinity",
		"infinit", "infx", "nan", "NaN", "+nan", "-nan", "nanx", "1e308", "1.7976931348623157e308", "1.7976931348623159e308",
		"1.797693134862315807e308", "1e309", "-1e309", "1e400", "1e-324", "2.4703282292062327e-324", "2.4703282292062328e-324",
		"4.9e-324", "5e-324", "1e-325", "1e-400", "-1e-400", "1e99999", "1e-99999", "1e100000000000", "3.4028235e38",
		"3.4028236e38", "3.4028235677973366e38", "3.4028235677973367e38", "1e39", "1.4e-45", "7e-46", "7.006492321624085e-46",
		"7.006492321624086e-46", "0.1", "0.2", "0.3", "9007199254740993", "9007199254740992", "9007199254740991",
		"123456789012345678901234567890", "0.000000000000000000000000000001", "1e0",
		"2.2250738585072014e-308", "2.2250738585072011e-308", "4503599627370496.5", "4503599627370497.5", "16777217", "16777216.5",
		"0x1p1023", "0x1p1024", "0x1.fffffffffffffp1023", "0x1.fffffffffffff8p1023", "0x1p-1074", "0x1p-1075", "0x1.8p-1074",
		"0x1.0000000000000001p0", "0x123456789abcdef01p0", " 1", "1 ", "1.5x", "١"}
	for i := 0; i < 400; i++ {
		var b []byte
		nd := 1 + rng.Intn(25)
		for j := 0; j < nd; j++ {
			b = append(b, byte('0'+rng.Intn(10)))
		}
		if rng.Intn(2) == 0 {
			p := rng.Intn(len(b) + 1)
			b = append(b[:p], append([]byte{'.'}, b[p:]...)...)
		}
		if rng.Intn(3) != 0 {
			b = append(b, []byte(fmt.Sprintf("e%d", rng.Intn(700)-350))...)
		}
		if rng.Intn(5) == 0 {
			b = append([]byte{'-'}, b...)
		}
		fl = append(fl, string(b))
	}
	for i := 0; i < 150; i++ { // quase empates: 17+ dígitos de floats aleatórios
		f := math.Float64frombits(rng.Uint64()&^(0x7ff<<52) | uint64(rng.Intn(2046)+1)<<52)
		fl = append(fl, strconv.FormatFloat(f, 'e', 17+rng.Intn(5), 64))
	}
	var out []string
	for _, s := range strs {
		b, be := strconv.ParseBool(s)
		out = append(out, fmt.Sprintf("pb %v %s", b, errText(be)))
		out = append(out, "q "+strconv.Quote(s)+"|"+strconv.QuoteToASCII(s)+"|"+fmt.Sprint(strconv.CanBackquote(s)))
		u, ue := strconv.Unquote(s)
		out = append(out, fmt.Sprintf("uq %x %s", u, errText(ue)))
		for _, q := range []byte{0, '\'', '"'} {
			v, mb, tail, err := strconv.UnquoteChar(s, q)
			out = append(out, fmt.Sprintf("uc %d %d %v %x %s", q, v, mb, tail, errText(err)))
		}
		out = append(out, fmt.Sprintf("ab %x", strconv.AppendBool([]byte("x"), len(s)%2 == 0))+
			fmt.Sprintf(" %x %x", strconv.AppendQuote([]byte("<"), s), strconv.AppendQuoteToASCII(nil, s)))
	}
	for _, r := range runes {
		out = append(out, fmt.Sprintf("r %d %s %s %v %s %s", r, strconv.QuoteRune(r), strconv.QuoteRuneToASCII(r),
			strconv.IsPrint(r), strconv.AppendQuoteRune([]byte("["), r), strconv.AppendQuoteRuneToASCII(nil, r)))
	}
	for _, v := range []int64{0, 1, -1, 35, -36, 255, math.MaxInt64, math.MinInt64} {
		for _, b := range []int{2, 8, 10, 16, 36} {
			out = append(out, string(strconv.AppendInt([]byte("i:"), v, b))+" "+string(strconv.AppendUint([]byte("u:"), uint64(v), b)))
		}
	}
	for _, f := range floats {
		for _, fm := range []byte{'e', 'E', 'f', 'F', 'g', 'G', 'z'} {
			for _, prec := range []int{-1, 0, 1, 3, 6, 17, 30} {
				for _, bits := range []int{32, 64} {
					out = append(out, strconv.FormatFloat(f, fm, prec, bits)+" "+
						string(strconv.AppendFloat([]byte("<"), f, fm, prec, bits)))
				}
			}
		}
	}
	for _, s := range fl {
		for _, bits := range []int{32, 64, 0} {
			f, err := strconv.ParseFloat(s, bits)
			out = append(out, fmt.Sprintf("pf %s %s", fbits(f), errText(err)))
		}
	}
	hex := func(ss []string) []string {
		var r []string
		for _, s := range ss {
			r = append(r, fmt.Sprintf("%x", s))
		}
		return r
	}
	var fbs []string
	for _, f := range floats {
		fbs = append(fbs, fmt.Sprintf("%016x", math.Float64bits(f)))
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]any{"strs": hex(strs), "fl": hex(fl),
		"runes": runes, "floats": fbs, "out": out}); err != nil {
		panic(err)
	}
}
