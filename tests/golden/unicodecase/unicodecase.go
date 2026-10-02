// Repro do shim unicode (predicados e conversões de caixa sobre as tabelas
// geradas) e das funções de strings/bytes que dependem dele:
// ToUpper/ToLower/ToTitle/Title, EqualFold, TrimSpace, Fields/FieldsFunc,
// ToValidUTF8, IndexFunc/LastIndexFunc/ContainsFunc (strings) e
// ToUpper/ToLower/Title/EqualFold/TrimSpace/Fields/FieldsFunc/IndexFunc/
// LastIndexFunc/ContainsFunc/Runes (bytes). Casos especiais do Unicode: ß
// (não dobra 1:1 para maiúscula), İ/ı (I turco sem a regra especial), ſ
// (long s) e o Kelvin K (U+212A), todos em EqualFold/SimpleFold.
package main

import (
	"bytes"
	"fmt"
	"strings"
	"unicode"
)

func main() {
	runes := []rune{'a', 'A', '0', ' ', '\t', 'ß', 'İ', 'ı', 'ſ', 'K', 'K', 'γ', '中', '�'}
	for _, r := range runes {
		fmt.Printf(
			"%q letter=%v digit=%v space=%v upper=%v lower=%v title=%v control=%v mark=%v number=%v punct=%v symbol=%v graphic=%v print=%v\n",
			r, unicode.IsLetter(r), unicode.IsDigit(r), unicode.IsSpace(r), unicode.IsUpper(r), unicode.IsLower(r), unicode.IsTitle(r),
			unicode.IsControl(r), unicode.IsMark(r), unicode.IsNumber(r), unicode.IsPunct(r), unicode.IsSymbol(r), unicode.IsGraphic(r), unicode.IsPrint(r),
		)
		fmt.Printf("%q upper=%q lower=%q title=%q fold=%q\n", r, unicode.ToUpper(r), unicode.ToLower(r), unicode.ToTitle(r), unicode.SimpleFold(r))
	}
	fmt.Println(unicode.Is(unicode.Greek, 'γ'), unicode.Is(unicode.Greek, 'a'))
	fmt.Println(unicode.Is(unicode.Soft_Dotted, 'i'), unicode.Is(unicode.Soft_Dotted, 'I'))
	fmt.Println(unicode.MaxRune, unicode.MaxASCII, unicode.ReplacementChar)

	strCases := []string{
		"Hello, World!",
		"café STRASSE ß",
		"İstanbul, ıstanbul",
		"GO gopher ſinger",
		"  \t foo   bar\nbaz qux  ",
		"KKk",
		"",
		"   ",
	}
	for _, s := range strCases {
		fmt.Printf("%q upper=%q lower=%q toTitle=%q Title=%q\n", s, strings.ToUpper(s), strings.ToLower(s), strings.ToTitle(s), strings.Title(s))
		fmt.Printf("%q trimSpace=%q fields=%q\n", s, strings.TrimSpace(s), strings.Fields(s))
	}
	foldPairs := [][2]string{
		{"Go", "GO"}, {"k", "K"}, {"K", "K"}, {"ſ", "S"}, {"ſ", "s"},
		{"abc", "abd"}, {"", ""}, {"a", "ab"}, {"İ", "İ"}, {"straße", "STRASSE"},
	}
	for _, p := range foldPairs {
		fmt.Println(strings.EqualFold(p[0], p[1]))
	}
	isDigit := func(r rune) bool { return unicode.IsDigit(r) }
	isPunct := func(r rune) bool { return unicode.IsPunct(r) }
	fmt.Println(strings.IndexFunc("abc123", isDigit), strings.LastIndexFunc("a1b2c3", isDigit), strings.ContainsFunc("hello!", isPunct))
	fmt.Printf("%q\n", strings.ToValidUTF8("a\xffb\xffc\xff", "?"))
	fmt.Printf("%q\n", strings.ToValidUTF8("\xffab\xff", ""))
	fmt.Println(strings.FieldsFunc("a,b,,c,", func(r rune) bool { return r == ',' }))

	byteCases := [][]byte{
		[]byte("Hello, World!"),
		[]byte("café STRASSE ß"),
		[]byte("  \t foo   bar\nbaz  "),
		[]byte("KKk"),
		[]byte(""),
		[]byte("   "),
	}
	for _, b := range byteCases {
		fmt.Printf(
			"%q upper=%q lower=%q Title=%q trimSpace=%q fields=%q\n",
			b, bytes.ToUpper(b), bytes.ToLower(b), bytes.Title(b), bytes.TrimSpace(b), bytes.Fields(b),
		)
		fmt.Println(bytes.Runes(b))
	}
	fmt.Println(bytes.TrimSpace([]byte("   ")) == nil)
	fmt.Println(bytes.EqualFold([]byte("Go"), []byte("GO")), bytes.EqualFold([]byte("k"), []byte("K")), bytes.EqualFold([]byte("abc"), []byte("abd")))
	fmt.Println(bytes.IndexFunc([]byte("abc123"), isDigit), bytes.LastIndexFunc([]byte("a1b2c3"), isDigit), bytes.ContainsFunc([]byte("hello!"), isPunct))
	fmt.Println(bytes.FieldsFunc([]byte("a,b,,c,"), func(r rune) bool { return r == ',' }))
}
