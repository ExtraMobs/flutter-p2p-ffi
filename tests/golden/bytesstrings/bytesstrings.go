// Repros dos shims parciais de bytes, strings e sort no grafo do kubo:
// syndtr/goleveldb/leveldb/comparer (bytes.Compare), polydawn/refmt/tok
// (bytes.Equal), gabriel-vasile/mimetype/internal/mp3 (bytes.IndexByte),
// protobuf/internal/version (strings.Contains) e x/text/internal/tag
// (sort.Search); getsentry/sentry-go/internal/traceparser (bytes.HasPrefix,
// Split, TrimLeft), gabriel-vasile/mimetype/internal/scan (bytes.Index),
// x/crypto/internal/poly1305 (subtle.ConstantTimeCompare),
// munnerz/goautoneg (strings.SplitN, TrimFunc), rs/cors/internal
// (strings.Join) e cockroachdb/pebble/v2/internal/treeprinter
// (strings.ContainsRune).
package main

import (
	"bytes"
	"crypto/subtle"
	"fmt"
	"sort"
	"strings"
)

type bytesComparer struct{}

func (bytesComparer) Compare(a, b []byte) int { return bytes.Compare(a, b) }

// Index de x/text/internal/tag: busca binária em blocos de 4 bytes.
type Index string

func (s Index) Index(key []byte) int {
	n := len(key)
	index := sort.Search(len(s)/4, func(i int) bool {
		return cmp(s[i*4:i*4+n], key) != -1
	})
	i := index * 4
	if cmp(s[i:i+len(key)], key) != 0 {
		return -1
	}
	return index
}

func cmp(a Index, b []byte) int {
	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	for i, c := range b[:n] {
		switch {
		case a[i] > c:
			return 1
		case a[i] < c:
			return -1
		}
	}
	switch {
	case len(a) < len(b):
		return -1
	case len(a) > len(b):
		return 1
	}
	return 0
}

// cutAtComma de rs/cors/internal: resultados nomeados que nunca são lidos
// (antes, `unused_local_variable` no Dart gerado).
func cutAtComma(s string, n int) (before, after string, found bool) {
	end := min(len(s), n)
	if i := strings.IndexByte(s[:end], ','); i != -1 {
		after = s[i+1:]
		return s[:i], after, true
	}
	return s, "", false
}

func main() {
	fmt.Println(cutAtComma("a,b,c", 3))
	fmt.Println(cutAtComma("abc,d", 2))
	var c bytesComparer
	bs := [][]byte{nil, {}, {0}, {1}, {1, 2}, {1, 3}, {0xff}}
	for _, a := range bs {
		for _, b := range bs {
			fmt.Print(c.Compare(a, b), bytes.Equal(a, b), " ")
		}
		fmt.Println(bytes.IndexByte(a, 1), bytes.IndexByte(a, 0xff))
	}
	for _, s := range []string{"", "go", "devel", "v1.2.3-devel", "dev", "ação-devel"} {
		fmt.Println(strings.Contains(s, "devel"), strings.Contains(s, ""), strings.HasPrefix(s, "dev"),
			strings.HasSuffix(s, "devel"), strings.Index(s, "e"), strings.IndexByte(s, 'l'))
	}
	idx := Index("aa  bb  cc  dd  ee  ")
	for _, k := range []string{"aa", "cc", "ee", "b", "dd  ", ""} {
		fmt.Print(idx.Index([]byte(k)), " ")
	}
	var calls []int
	i := sort.Search(100, func(i int) bool { calls = append(calls, i); return i >= 37 })
	fmt.Println(i, calls, sort.Search(0, nil))

	bad := "a\xffé\xe2\x82"
	for _, sep := range []string{",", "", "é", ",,"} {
		for _, in := range []string{"", "a,b,,c,", "é,x", bad} {
			p := strings.Split(in, sep)
			q := strings.SplitN(in, sep, 2)
			z := strings.SplitN(in, sep, 0)
			fmt.Printf("%q %d %q %d %q %v\n", p, cap(p), q, cap(q), z, z == nil)
		}
	}
	fmt.Printf("%q %q %q\n", strings.Join(nil, ","), strings.Join([]string{"a"}, ","), strings.Join([]string{"a", "", "b"}, ", "))
	isSp := func(r rune) bool { return r == ' ' || r == ';' || r == 0xfffd }
	for _, in := range []string{"", "  ", " a; b ;", "\xff x \xe2\x82", "é é"} {
		fmt.Printf("%q %q %q\n", strings.TrimFunc(in, isSp), strings.TrimLeftFunc(in, isSp), strings.TrimRightFunc(in, isSp))
		fmt.Println(strings.ContainsRune(in, ' '), strings.ContainsRune(in, 'é'), strings.ContainsRune(in, 0xfffd), strings.ContainsRune(in, -1),
			strings.Count(in, " "), strings.Count(in, ""), strings.LastIndex(in, " "), strings.TrimPrefix(in, " "), strings.TrimSuffix(in, " "))
	}

	line := []byte("goroutine 1 [running]:\n\tmain.go:12 +0x1d\n\n")
	parts := bytes.Split(line, []byte("\n"))
	fmt.Println(len(parts), cap(parts), cap(parts[0]), bytes.HasPrefix(parts[0], []byte("goroutine ")), bytes.HasSuffix(line, []byte("\n")))
	fmt.Printf("%q %q\n", bytes.TrimLeft(parts[1], "\t"), bytes.TrimLeft(parts[1], "\tmaé"))
	grown := append(parts[0], '!') // cap limitado: não sobrescreve o '\n'
	fmt.Printf("%q %q\n", grown, line[:24])
	fmt.Println(bytes.TrimLeft(nil, "x") == nil, bytes.TrimLeft([]byte("xx"), "x") == nil, bytes.TrimLeft([]byte("\xffé!"), "é�"))
	fmt.Printf("%q %q\n", bytes.Split([]byte(bad), nil), bytes.Split([]byte("a,b"), []byte(",")))
	fmt.Println(bytes.Index(line, []byte("main")), bytes.Index(line, nil), bytes.Index(nil, []byte("x")))
	fmt.Println(subtle.ConstantTimeCompare([]byte("abc"), []byte("abc")), subtle.ConstantTimeCompare([]byte("abc"), []byte("abd")),
		subtle.ConstantTimeCompare(nil, []byte{}), subtle.ConstantTimeCompare([]byte("a"), nil))
}
