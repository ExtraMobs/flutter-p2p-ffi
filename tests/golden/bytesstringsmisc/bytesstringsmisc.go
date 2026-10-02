// Símbolos "baratos" de strings e bytes (porta direta do fonte do Go), com
// bordas: vazio, n<0, UTF-8 inválido e runas multibyte. Repros do grafo do
// kubo: go-logfmt (strings.Map), klauspost/cpuid (Trim), pion/rtcp
// (ReplaceAll), go-ipld-prime/datamodel (FieldsFunc), blang/semver (Replace),
// btreemap (Repeat).
package main

import (
	"bytes"
	"fmt"
	"strings"
)

const bad = "a\xffb\xc0\xafc"

func isDigit(r rune) bool { return r >= '0' && r <= '9' }
func isSep(r rune) bool   { return r == ',' || r == ';' || r == 'é' }

func up(r rune) rune {
	switch {
	case r == 'x':
		return -1
	case r >= 'a' && r <= 'z':
		return r - 32
	case r == 'é':
		return 0x1F600
	case r == 0xFFFD:
		return 'F'
	}
	return r
}

func try(name string, f func()) {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("%s: panic %v\n", name, r)
		}
	}()
	f()
}

func nl(b []byte) string {
	if b == nil {
		return "nil"
	}
	return "nonnil"
}

func stringsCases() {
	ss := []string{"", "a", "abc", "héllo wörld", "ééé", bad, "a,b;;c,é,d"}
	olds := []string{"", "a", "é", "b", "\xff", "ab"}
	for _, s := range ss {
		for _, o := range olds {
			for _, n := range []int{-1, 0, 1, 2, 100} {
				fmt.Printf("Replace(%q,%q,%q,%d)=%q\n", s, o, "XY", n, strings.Replace(s, o, "XY", n))
			}
			fmt.Printf("ReplaceAll(%q,%q)=%q\n", s, o, strings.ReplaceAll(s, o, ""))
		}
		for _, sep := range []string{"", ",", "é", "\xff", "zz"} {
			before, after, ok := strings.Cut(s, sep)
			fmt.Printf("Cut(%q,%q)=%q %q %v\n", s, sep, before, after, ok)
			a, ok1 := strings.CutPrefix(s, sep)
			b, ok2 := strings.CutSuffix(s, sep)
			fmt.Printf("CutPrefix/Suffix=%q %v %q %v\n", a, ok1, b, ok2)
			fmt.Printf("SplitAfter(%q,%q)=%q\n", s, sep, strings.SplitAfter(s, sep))
			fmt.Printf("SplitAfterN=%q %q\n", strings.SplitAfterN(s, sep, 2), strings.SplitAfterN(s, sep, 0))
		}
		for _, cs := range []string{"", "a", "ab", "é", "aé", "\xff", "\xc0", "�", ",;"} {
			fmt.Printf("Trim(%q,%q)=%q %q %q\n", s, cs, strings.Trim(s, cs), strings.TrimLeft(s, cs), strings.TrimRight(s, cs))
			fmt.Printf("IndexAny=%d LastIndexAny=%d ContainsAny=%v\n", strings.IndexAny(s, cs), strings.LastIndexAny(s, cs), strings.ContainsAny(s, cs))
		}
		for _, r := range []rune{'a', 'é', 0xFFFD, -1, 0xD800, 0x110000, 0x1F600, 0} {
			fmt.Printf("IndexRune(%q,%d)=%d\n", s, r, strings.IndexRune(s, r))
		}
		fmt.Printf("IndexFunc=%d %d LastIndexFunc=%d %d\n", strings.IndexFunc(s, isSep), strings.IndexFunc(s, isDigit),
			strings.LastIndexFunc(s, isSep), strings.LastIndexFunc(s, func(r rune) bool { return r == 0xFFFD }))
		fmt.Printf("LastIndexByte=%d %d\n", strings.LastIndexByte(s, 'b'), strings.LastIndexByte(s, 0xff))
		fmt.Printf("Map=%q\n", strings.Map(up, s))
		f := strings.FieldsFunc(s, isSep)
		fmt.Printf("FieldsFunc=%q len=%d nil=%v\n", f, len(f), f == nil)
		for _, t := range ss {
			fmt.Printf("Compare(%q,%q)=%d\n", s, t, strings.Compare(s, t))
		}
	}
	for _, c := range []int{0, 1, 2, 5} {
		fmt.Printf("Repeat=%q %q %q\n", strings.Repeat("", c), strings.Repeat("é", c), strings.Repeat("ab\xff", c))
	}
	try("Repeat-neg", func() { strings.Repeat("x", -1) })
	try("Repeat-big", func() { strings.Repeat("xx", 1<<62) })
}

func bs(s string) []byte { return []byte(s) }

func bytesCases() {
	ss := []string{"", "a", "abc", "héllo wörld", "ééé", bad, "a,b;;c,é,d"}
	olds := []string{"", "a", "é", "b", "\xff", "ab"}
	for _, s := range ss {
		for _, o := range olds {
			for _, n := range []int{-1, 0, 1, 2, 100} {
				r := bytes.Replace(bs(s), bs(o), bs("XY"), n)
				fmt.Printf("Replace(%q,%q,%d)=%q %s\n", s, o, n, r, nl(r))
			}
			fmt.Printf("ReplaceAll=%q\n", bytes.ReplaceAll(bs(s), bs(o), nil))
			fmt.Printf("Contains=%v LastIndex=%d\n", bytes.Contains(bs(s), bs(o)), bytes.LastIndex(bs(s), bs(o)))
		}
		for _, sep := range []string{"", ",", "é", "\xff", "zz"} {
			before, after, ok := bytes.Cut(bs(s), bs(sep))
			fmt.Printf("Cut(%q,%q)=%q %s %q %s %v\n", s, sep, before, nl(before), after, nl(after), ok)
			a, ok1 := bytes.CutPrefix(bs(s), bs(sep))
			b, ok2 := bytes.CutSuffix(bs(s), bs(sep))
			fmt.Printf("CutPrefix/Suffix=%q %v %q %v\n", a, ok1, b, ok2)
			fmt.Printf("TrimPrefix/Suffix=%q %q\n", bytes.TrimPrefix(bs(s), bs(sep)), bytes.TrimSuffix(bs(s), bs(sep)))
			x := bytes.SplitAfter(bs(s), bs(sep))
			fmt.Printf("SplitAfter(%q,%q)=%q len=%d\n", s, sep, x, len(x))
			y := bytes.SplitN(bs(s), bs(sep), 2)
			z := bytes.SplitN(bs(s), bs(sep), 0)
			fmt.Printf("SplitN=%q %q %v\n", y, z, z == nil)
			fmt.Printf("SplitAfterN=%q\n", bytes.SplitAfterN(bs(s), bs(sep), 3))
		}
		for _, cs := range []string{"", "a", "ab", "é", "aé", "\xff", "\xc0", "�", ",;"} {
			t := bytes.Trim(bs(s), cs)
			fmt.Printf("Trim(%q,%q)=%q %s\n", s, cs, t, nl(t))
			fmt.Printf("IndexAny=%d LastIndexAny=%d ContainsAny=%v\n", bytes.IndexAny(bs(s), cs), bytes.LastIndexAny(bs(s), cs), bytes.ContainsAny(bs(s), cs))
		}
		for _, r := range []rune{'a', 'é', 0xFFFD, -1, 0xD800, 0x110000, 0x1F600, 0} {
			fmt.Printf("IndexRune(%q,%d)=%d %v\n", s, r, bytes.IndexRune(bs(s), r), bytes.ContainsRune(bs(s), r))
		}
		fmt.Printf("IndexFunc=%d %d LastIndexFunc=%d %d ContainsFunc=%v\n", bytes.IndexFunc(bs(s), isSep), bytes.IndexFunc(bs(s), isDigit),
			bytes.LastIndexFunc(bs(s), isSep), bytes.LastIndexFunc(bs(s), func(r rune) bool { return r == 0xFFFD }),
			bytes.ContainsFunc(bs(s), isSep))
		l := bytes.TrimLeftFunc(bs(s), isSep)
		r := bytes.TrimRightFunc(bs(s), isSep)
		t := bytes.TrimFunc(bs(s), isSep)
		fmt.Printf("TrimFuncs=%q %s %q %s %q %s\n", l, nl(l), r, nl(r), t, nl(t))
		m := bytes.Map(up, bs(s))
		fmt.Printf("Map=%q cap=%d\n", m, cap(m))
		f := bytes.FieldsFunc(bs(s), isSep)
		fmt.Printf("FieldsFunc=%q len=%d nil=%v\n", f, len(f), f == nil)
		c := bytes.Clone(bs(s))
		fmt.Printf("Clone=%q %s %s\n", c, nl(c), nl(bytes.Clone(nil)))
	}
	src := make([]byte, 5, 16)
	copy(src, "a,b,c")
	fmt.Println(caps(bytes.SplitAfter(src, bs(","))), caps(bytes.Split(src, bs(","))), caps(bytes.SplitN(src, bs(","), 2)), caps(bytes.FieldsFunc(src, isSep)), caps(bytes.Split(src, nil)))
	parts := [][]byte{bs("a"), bs(""), bs("é"), bs("\xff")}
	for k := 0; k <= len(parts); k++ {
		j := bytes.Join(parts[:k], bs("--"))
		fmt.Printf("Join=%q %s len=%d\n", j, nl(j), len(j))
	}
	for _, c := range []int{0, 1, 2, 5} {
		fmt.Printf("Repeat=%q %q %q\n", bytes.Repeat(nil, c), bytes.Repeat(bs("é"), c), bytes.Repeat(bs("ab\xff"), c))
	}
	try("Repeat-neg", func() { bytes.Repeat(bs("x"), -1) })
	try("Repeat-big", func() { bytes.Repeat(bs("xx"), 1<<62) })
}

func caps(x [][]byte) []int {
	var c []int
	for _, e := range x {
		c = append(c, cap(e))
	}
	return c
}


func main() {
	stringsCases()
	bytesCases()
}
