// Repros de strconv (bool, Quote/Unquote, Append*, FormatFloat/ParseFloat) no grafo do kubo:
// go.uber.org/zap/buffer (AppendInt/AppendUint), go-logr/logr/funcr (IsPrint),
// miekg/dns (QuoteToASCII), grpc-gateway/v2/runtime (ParseBool),
// munnerz/goautoneg (ParseFloat), dunglas/httpsfv (FormatFloat).
package main

import (
	"fmt"
	"strconv"
)

func main() {
	for _, s := range []string{"1", "t", "TRUE", "False", "0", "yes", ""} {
		b, err := strconv.ParseBool(s)
		fmt.Println(s, b, err)
	}
	fmt.Println(strconv.FormatBool(true), strconv.FormatBool(false), strconv.IntSize)

	buf := []byte("n=")
	buf = strconv.AppendInt(buf, -255, 16)
	buf = append(buf, ' ')
	buf = strconv.AppendUint(buf, 1<<63, 2)
	buf = strconv.AppendBool(buf, true)
	fmt.Println(string(buf))

	for _, s := range []string{"plain", "tab\there", "q\"uote", "ünï", "日本", "\x00\x7f", "\xff", "\U0001F600", "a`b"} {
		fmt.Println(strconv.Quote(s), strconv.QuoteToASCII(s), strconv.CanBackquote(s))
	}
	fmt.Println(strconv.QuoteRune('x'), strconv.QuoteRune('\n'), strconv.QuoteRune('\''), strconv.QuoteRuneToASCII('é'))
	fmt.Println(string(strconv.AppendQuote([]byte("> "), "hi\n")), string(strconv.AppendQuoteRune(nil, '☺')))
	for _, r := range []rune{'a', ' ', '\t', 0x7f, 0xa0, 'é', 0x200b, '日', 0x1F600, 0x10ffff} {
		fmt.Print(strconv.IsPrint(r), " ")
	}
	fmt.Println()

	for _, s := range []string{`"a\tb"`, `'x'`, "`raw\\n`", `"é\x41\101"`, `"bad`, `'ab'`, `"\z"`, `plain`, `""`} {
		u, err := strconv.Unquote(s)
		fmt.Printf("%q %q %v\n", s, u, err)
	}
	v, mb, tail, err := strconv.UnquoteChar(`☺ rest`, '"')
	fmt.Println(v, mb, tail, err)
	v, mb, tail, err = strconv.UnquoteChar(`é!`, '"')
	fmt.Println(v, mb, tail, err)
	_, _, _, err = strconv.UnquoteChar(`"`, '"')
	fmt.Println(err)

	for _, f := range []float64{0, 1, -2.5, 0.1, 1.0 / 3, 1e21, 1e-7, 123456789.125, 5e-324} {
		fmt.Println(strconv.FormatFloat(f, 'g', -1, 64), strconv.FormatFloat(f, 'f', 2, 64),
			strconv.FormatFloat(f, 'e', 3, 64), strconv.FormatFloat(f, 'g', -1, 32))
	}
	fb := strconv.AppendFloat([]byte("f="), 3.14159, 'f', 3, 64)
	fmt.Println(string(fb))

	for _, s := range []string{"0", "1.5", "-2.25e3", ".5", "1e400", "-1e400", "1e-400", "0x1p-2", "1_0.5", "inf", "-Infinity", "nan",
		"0.1", "9007199254740993", "3.4028236e38", "abc", "1e", ""} {
		f, err := strconv.ParseFloat(s, 64)
		f32, _ := strconv.ParseFloat(s, 32)
		fmt.Println(s, f, f32, err)
	}
	q, err := strconv.ParseFloat("q=0.8", 64)
	fmt.Println(q, err)
}
