// O resto do shim parcial de bytes (TODO/P0-shim-bytes.md), com casos de
// borda: separador/cutset/old vazio, n negativo ou zero, UTF-8 inválido,
// pânico com recover.
package main

import (
	"bytes"
	"fmt"
	"io"
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

func main() {
	// Reader.
	r := bytes.NewReader([]byte("Hello, 世界!"))
	fmt.Println(r.Len(), r.Size())
	buf := make([]byte, 5)
	n, err := r.Read(buf)
	fmt.Printf("%d %v %q %d\n", n, err, buf[:n], r.Len())
	n2, err2 := r.ReadAt(buf, 1)
	fmt.Printf("%d %v %q %d\n", n2, err2, buf[:n2], r.Len())
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
	r.Reset([]byte("abc"))
	var wbuf bytes.Buffer
	wn, errW := r.WriteTo(&wbuf)
	fmt.Println(wn, errW, wbuf.String())
	var empty bytes.Reader
	_, errEmptyRead := empty.Read(buf)
	fmt.Println(errEmptyRead == io.EOF, empty.Len())

	// TrimPrefix / TrimSuffix / Trim.
	fmt.Printf("%q %q %q\n", bytes.TrimPrefix([]byte("hello"), []byte("he")),
		bytes.TrimPrefix([]byte("hello"), []byte("xx")), bytes.TrimSuffix([]byte("hello"), []byte("lo")))
	fmt.Println(bytes.Trim([]byte(""), "x") == nil, bytes.Trim([]byte("xxhix"), "x"))
	fmt.Printf("%q\n", bytes.Trim([]byte("\xffhi\xff"), "\xff"))

	// Join.
	fmt.Printf("%q %q %q\n", bytes.Join(nil, []byte(",")), bytes.Join([][]byte{[]byte("a")}, []byte(",")),
		bytes.Join([][]byte{[]byte("a"), []byte(""), []byte("b")}, []byte(", ")))

	// Repeat.
	fmt.Printf("%q %q %s\n", bytes.Repeat([]byte("ab"), 0), bytes.Repeat([]byte("ab"), 3),
		tryPanic(func() { bytes.Repeat([]byte("x"), -1) }))
	fmt.Println(bytes.Repeat([]byte("ab"), 0) == nil)

	// IndexAny, LastIndex, Contains, ContainsAny, ContainsRune.
	for _, s := range [][]byte{[]byte(""), []byte("chicken"), []byte("hello, world"), []byte("h\xffllo")} {
		fmt.Println(bytes.IndexAny(s, "aeiou"), bytes.IndexAny(s, ""), bytes.LastIndex(s, []byte("l")),
			bytes.LastIndex(s, []byte("")), bytes.Contains(s, []byte("ll")), bytes.ContainsAny(s, "xyz"),
			bytes.ContainsRune(s, 'l'), bytes.ContainsRune(s, rune(0xfffd)))
	}

	// Clone.
	fmt.Println(bytes.Clone(nil) == nil, string(bytes.Clone([]byte("abc"))))

	// Cut / CutPrefix / CutSuffix.
	bb, ba, bf := bytes.Cut([]byte("a=b=c"), []byte("="))
	fmt.Printf("%q %q %v\n", bb, ba, bf)
	bb2, ba2, bf2 := bytes.Cut([]byte("abc"), []byte("="))
	fmt.Printf("%q %q %v %v\n", bb2, ba2, bf2, ba2 == nil)
	ca1, cf1 := bytes.CutPrefix([]byte("hello"), []byte("he"))
	ca2, cf2 := bytes.CutPrefix([]byte("hello"), []byte("xx"))
	fmt.Printf("%q %v %q %v\n", ca1, cf1, ca2, cf2)
	cb1, cg1 := bytes.CutSuffix([]byte("hello"), []byte("lo"))
	cb2, cg2 := bytes.CutSuffix([]byte("hello"), []byte("xx"))
	fmt.Printf("%q %v %q %v\n", cb1, cg1, cb2, cg2)

	// Replace / ReplaceAll.
	fmt.Printf("%q %q\n", bytes.Replace([]byte("banana"), []byte("a"), []byte("o"), -1),
		bytes.ReplaceAll([]byte("banana"), []byte("a"), []byte("o")))
	fmt.Printf("%q %q\n", bytes.Replace([]byte("banana"), []byte("a"), []byte("o"), 0),
		bytes.Replace([]byte("abc"), []byte(""), []byte("-"), -1))
	fmt.Printf("%q\n", bytes.ReplaceAll([]byte("\xff\xffab"), []byte("\xff"), []byte("!")))

	// SplitN.
	fmt.Printf("%q %q %q\n", bytes.SplitN([]byte("a,b,c"), []byte(","), 2),
		bytes.SplitN([]byte("a,b,c"), []byte(","), 0), bytes.SplitN([]byte("abc"), []byte(""), 2))

	// Map.
	rot13 := func(rr rune) rune {
		switch {
		case rr >= 'a' && rr <= 'z':
			return 'a' + (rr-'a'+13)%26
		case rr >= 'A' && rr <= 'Z':
			return 'A' + (rr-'A'+13)%26
		}
		return rr
	}
	fmt.Printf("%q\n", bytes.Map(rot13, []byte("Hello, World!")))
	identity := func(rr rune) rune { return rr }
	fmt.Printf("%q\n", bytes.Map(identity, []byte("a\xffb")))
}
