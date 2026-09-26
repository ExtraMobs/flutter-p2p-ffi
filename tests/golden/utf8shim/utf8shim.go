// unicode/utf8: decodificação com as regras do Go (inválido, curto, overlong,
// surrogate, acima de U+10FFFF), codificação, contagem e validação.
package main

import (
	"fmt"
	"unicode/utf8"
)

func main() {
	cases := [][]byte{
		nil, []byte("a"), []byte("é"), []byte("€"), []byte("𝄞"), []byte("aé€𝄞"),
		{0x80}, {0xc0, 0x80}, {0xc2}, {0xe0, 0x80, 0x80}, {0xed, 0xa0, 0x80}, {0xf4, 0x90, 0x80, 0x80},
		{0xf0, 0x9f}, {0xe2, 0x82}, {0xff, 'x'}, {'a', 0xe2, 0x82, 0xac, 0xe2}, {0xef, 0xbf, 0xbd},
	}
	for _, b := range cases {
		r, n := utf8.DecodeRune(b)
		lr, ln := utf8.DecodeLastRune(b)
		sr, sn := utf8.DecodeRuneInString(string(b))
		slr, sln := utf8.DecodeLastRuneInString(string(b))
		fmt.Println(b, r, n, lr, ln, sr, sn, slr, sln, utf8.RuneCount(b), utf8.RuneCountInString(string(b)),
			utf8.Valid(b), utf8.ValidString(string(b)), utf8.FullRune(b), utf8.FullRuneInString(string(b)))
	}
	for _, r := range []rune{0, 'a', 0x7f, 0x80, 0x7ff, 0x800, 0xd7ff, 0xd800, 0xdfff, 0xe000, 0xfffd, 0xffff, 0x10000, 0x10ffff, 0x110000, -1} {
		buf := make([]byte, 4)
		n := utf8.EncodeRune(buf, r)
		fmt.Println(r, utf8.RuneLen(r), utf8.ValidRune(r), n, buf[:n], utf8.AppendRune([]byte("x"), r))
	}
	fmt.Println(utf8.RuneStart(0x80), utf8.RuneStart('a'), utf8.RuneStart(0xe2))
	fmt.Println(utf8.RuneError, utf8.UTFMax, utf8.RuneSelf, utf8.MaxRune)
	defer func() { fmt.Println("recover:", recover()) }()
	utf8.EncodeRune(make([]byte, 2), '€')
}
