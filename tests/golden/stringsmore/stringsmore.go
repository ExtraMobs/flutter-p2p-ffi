// O resto do shim parcial de strings (TODO/P0-shim-strings.md), com casos
// de borda: separador/cutset/old vazio, n negativo ou zero, UTF-8 inválido,
// pânico com recover.
package main

import (
	"bytes"
	"fmt"
	"io"
	"strings"
)

func tryPanic(f func()) (msg string) {
	defer func() {
		if r := recover(); r != nil {
			msg = fmt.Sprint(r)
		}
	}()
	f()
	return "ok"
}

// sink é um io.Writer puro (sem WriteString), para exercitar o fallback de
// io.WriteString/getStringWriter.
type sink struct{ got []byte }

func (s *sink) Write(p []byte) (int, error) {
	s.got = append(s.got, p...)
	return len(p), nil
}

func main() {
	// Trim / TrimLeft / TrimRight: cutset ASCII, Unicode e byte inválido.
	for _, s := range []string{"", "xxhixx", "  hi  ", "\xffhi\xff", "ééháé", "###", "aaa"} {
		fmt.Printf("%q %q %q %q\n", strings.Trim(s, "x #"), strings.TrimLeft(s, "x #"),
			strings.TrimRight(s, "x #"), strings.Trim(s, ""))
	}
	fmt.Printf("%q %q\n", strings.Trim("héllo", "é"), strings.Trim("\xff\xffab\xff", "\xff"))
	fmt.Println(strings.TrimLeft("", "x"), strings.TrimRight("", "x") == "")

	// Replace / ReplaceAll: old==new, n=0, n<0, old vazio, multibyte.
	fmt.Printf("%q %q\n", strings.Replace("banana", "a", "o", -1), strings.ReplaceAll("banana", "a", "o"))
	fmt.Printf("%q %q\n", strings.Replace("banana", "a", "o", 2), strings.Replace("banana", "a", "o", 0))
	fmt.Printf("%q %q\n", strings.Replace("banana", "a", "a", -1), strings.Replace("", "", "x", -1))
	fmt.Printf("%q %q\n", strings.Replace("abc", "", "-", -1), strings.Replace("abc", "", "-", 2))
	fmt.Printf("%q %q\n", strings.ReplaceAll("ação", "ç", "c"), strings.ReplaceAll("aaa", "aa", "b"))
	fmt.Printf("%q\n", strings.ReplaceAll("\xff\xffab", "\xff", "!"))

	// Repeat: 0, 1, n, negativo (pânico), string vazia.
	fmt.Printf("%q %q %q %s\n", strings.Repeat("ab", 0), strings.Repeat("ab", 1), strings.Repeat("ab", 3),
		tryPanic(func() { strings.Repeat("x", -1) }))
	fmt.Printf("%q\n", strings.Repeat("", 5))

	// Cut / CutPrefix / CutSuffix.
	before, after, found := strings.Cut("a=b=c", "=")
	fmt.Printf("%q %q %v\n", before, after, found)
	before, after, found = strings.Cut("abc", "=")
	fmt.Printf("%q %q %v\n", before, after, found)
	before, after, found = strings.Cut("", "=")
	fmt.Printf("%q %q %v\n", before, after, found)
	a1, f1 := strings.CutPrefix("hello", "he")
	a2, f2 := strings.CutPrefix("hello", "xx")
	a3, f3 := strings.CutPrefix("hello", "")
	fmt.Printf("%q %v %q %v %q %v\n", a1, f1, a2, f2, a3, f3)
	b1, g1 := strings.CutSuffix("hello", "lo")
	b2, g2 := strings.CutSuffix("hello", "xx")
	b3, g3 := strings.CutSuffix("hello", "")
	fmt.Printf("%q %v %q %v %q %v\n", b1, g1, b2, g2, b3, g3)

	// Compare.
	fmt.Println(strings.Compare("a", "b"), strings.Compare("b", "a"), strings.Compare("a", "a"),
		strings.Compare("", ""), strings.Compare("a", ""), strings.Compare("abc", "ab"))

	// LastIndexByte, IndexAny, LastIndexAny, IndexRune, ContainsAny.
	for _, s := range []string{"", "chicken", "hello, world", "h\xffllo"} {
		fmt.Println(strings.LastIndexByte(s, 'l'), strings.IndexAny(s, "aeiou"), strings.LastIndexAny(s, "aeiou"),
			strings.IndexAny(s, ""), strings.IndexRune(s, 'l'), strings.ContainsAny(s, "xyz"), strings.ContainsAny(s, ""))
	}
	fmt.Println(strings.IndexRune("héllo", 'é'), strings.IndexRune("h\xffllo", rune(0xfffd)))

	// SplitAfter / SplitAfterN.
	fmt.Printf("%q %q\n", strings.SplitAfter("a,b,c", ","), strings.SplitAfterN("a,b,c", ",", 2))
	fmt.Printf("%q %q\n", strings.SplitAfter("", ","), strings.SplitAfter(",", ","))
	fmt.Printf("%q %q\n", strings.SplitAfter("abc", ""), strings.SplitAfterN("a,,b", ",", 0))

	// Clone: cópia independente (não observável no Go, mas exercita o shim).
	big := strings.Repeat("x", 32) + "TAIL"
	small := big[32:]
	cloned := strings.Clone(small)
	fmt.Println(cloned == small, len(cloned))

	// Map.
	rot13 := func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z':
			return 'a' + (r-'a'+13)%26
		case r >= 'A' && r <= 'Z':
			return 'A' + (r-'A'+13)%26
		}
		return r
	}
	fmt.Printf("%q\n", strings.Map(rot13, "Hello, World! 123"))
	drop := func(r rune) rune {
		if r == 'l' {
			return -1
		}
		return r
	}
	fmt.Printf("%q\n", strings.Map(drop, "hello"))
	identity := func(r rune) rune { return r }
	fmt.Printf("%q %q\n", strings.Map(identity, "a\xffb"), strings.Map(identity, "clean"))
	fmt.Printf("%q\n", strings.Map(identity, "a\xe2\x82\xacb")) // € já válido: sem mudança
	fmt.Printf("%q\n", strings.Map(identity, "\xff\xff"))       // dois bytes inválidos seguidos

	// Reader.
	r := strings.NewReader("Hello, 世界!")
	fmt.Println(r.Len(), r.Size())
	buf := make([]byte, 5)
	n, err := r.Read(buf)
	fmt.Printf("%d %v %q %d\n", n, err, buf[:n], r.Len())
	n2, err2 := r.ReadAt(buf, 1)
	fmt.Printf("%d %v %q %d\n", n2, err2, buf[:n2], r.Len()) // ReadAt não muda o estado
	rb, errB := r.ReadByte()
	fmt.Println(rb, errB)
	fmt.Println(r.UnreadByte(), r.UnreadByte() != nil)
	rn, size, errR := r.ReadRune()
	fmt.Println(string(rn), size, errR)
	fmt.Println(r.UnreadRune())
	pos, errS := r.Seek(0, io.SeekEnd)
	fmt.Println(pos, errS)
	_, errS2 := r.Seek(-1, 99)
	fmt.Println(errS2)
	_, errS3 := r.Seek(-100, io.SeekStart)
	fmt.Println(errS3)
	pos2, errS4 := r.Seek(-3, io.SeekCurrent)
	fmt.Println(pos2, errS4)
	r.Reset("abc")
	var wbuf bytes.Buffer
	wn, errW := r.WriteTo(&wbuf)
	fmt.Println(wn, errW, wbuf.String())
	var empty strings.Reader // zero value: lê como string vazia
	_, errEmptyRead := empty.Read(buf)
	_, errEmptyByte := empty.ReadByte()
	_, _, errEmptyRune := empty.ReadRune()
	fmt.Println(errEmptyRead == io.EOF, errEmptyByte == io.EOF, errEmptyRune == io.EOF, empty.Len())
	fmt.Println(empty.UnreadByte() != nil, empty.UnreadRune() != nil)

	// Replacer.
	rep := strings.NewReplacer("<", "&lt;", ">", "&gt;", "&", "&amp;")
	fmt.Println(rep.Replace("<b>x & y</b>"))
	rep2 := strings.NewReplacer("aa", "X", "a", "Y") // prioridade: "aa" antes de "a"
	fmt.Println(rep2.Replace("aaa a aaaa"))
	rep3 := strings.NewReplacer("", "-") // old vazio: casa em toda posição
	fmt.Println(rep3.Replace("ab"))
	rep4 := strings.NewReplacer() // sem pares: identidade
	fmt.Println(rep4.Replace("xyz"))
	var wb bytes.Buffer
	n3, err3 := rep.WriteString(&wb, "<<>>&")
	fmt.Println(n3, err3, wb.String())
	sk := &sink{}
	n4, err4 := rep2.WriteString(sk, "aaaa")
	fmt.Println(n4, err4, string(sk.got))
	fmt.Println(tryPanic(func() { strings.NewReplacer("a") }))
}
