// Embrulhos do shim io (LimitReader, TeeReader, MultiReader, MultiWriter,
// NopCloser) e Copy/CopyN sobre io.Pipe: as formas $async esperam o leitor
// ou escritor de baixo (D2).
package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"strings"
)

// slowAt é um ReaderAt que espera cada pedaço num canal.
type slowAt struct{ c chan string }

func (a slowAt) ReadAt(p []byte, off int64) (int, error) {
	s := <-a.c
	n := copy(p, s)
	if n < len(p) {
		return n, io.EOF
	}
	return n, nil
}

func main() {
	pr, pw := io.Pipe()
	go func() {
		fmt.Fprint(pw, "hello, pipe world")
		pw.Close()
	}()
	var buf bytes.Buffer
	n, err := io.Copy(&buf, io.LimitReader(pr, 5))
	fmt.Println(n, err, buf.String())
	var sb strings.Builder
	rest, err := io.ReadAll(io.TeeReader(pr, &sb))
	fmt.Printf("%q %v %q\n", rest, err, sb.String())

	pr2, pw2 := io.Pipe()
	go func() {
		pw2.Write([]byte("abc"))
		pw2.CloseWithError(errors.New("boom"))
	}()
	all, err := io.ReadAll(io.MultiReader(strings.NewReader("x-"), pr2, strings.NewReader("-y")))
	fmt.Printf("%q %v\n", all, err)

	pr3, pw3 := io.Pipe()
	done := make(chan string)
	go func() {
		b, _ := io.ReadAll(pr3)
		done <- string(b)
	}()
	var mb bytes.Buffer
	mw := io.MultiWriter(&mb, pw3)
	io.WriteString(mw, "multi")
	fmt.Fprintf(mw, "-%d", 42)
	pw3.Close()
	fmt.Println(<-done, mb.String())

	pr4, pw4 := io.Pipe()
	go func() {
		pw4.Write([]byte("0123456789"))
		pw4.Close()
	}()
	rc := io.NopCloser(pr4)
	var out bytes.Buffer
	n, err = io.CopyN(&out, rc, 4)
	fmt.Println(n, err, out.String())
	n, err = io.Copy(io.Discard, rc)
	fmt.Println(n, err, rc.Close())

	c := make(chan string, 2)
	c <- "sect"
	c <- "ion"
	var r io.Reader = io.NewSectionReader(slowAt{c}, 0, 7)
	p := make([]byte, 4)
	k, err := r.Read(p)
	fmt.Println(k, err, string(p[:k]))
	k, err = r.Read(p)
	fmt.Println(k, err, string(p[:k]))
}
