// Funções e tipos de io.go/multi.go do Go 1.26 (Pipe fica de fora: depende
// de goroutines): ReadFull/ReadAtLeast, ReadAll, WriteString, Copy/CopyN/
// CopyBuffer (com e sem os caminhos rápidos WriterTo/ReaderFrom), Discard,
// NopCloser, LimitReader/LimitedReader (literal composto com R e N),
// MultiReader/MultiWriter, TeeReader, SectionReader/NewSectionReader, e as
// interfaces ByteScanner/RuneScanner/ReaderFrom/WriterTo/ReadSeekCloser sobre
// tipos próprios.
package main

import (
	"bytes"
	"fmt"
	"io"
	"strings"
)

// chunkReader entrega no máximo 4 bytes por Read; EOF quando esgota.
type chunkReader struct{ data []byte }

func (c *chunkReader) Read(p []byte) (int, error) {
	if len(c.data) == 0 {
		return 0, io.EOF
	}
	n := copy(p, c.data[:min(4, len(c.data))])
	c.data = c.data[n:]
	return n, nil
}

// countWriter conta bytes escritos, sem implementar StringWriter.
type countWriter struct{ n int }

func (w *countWriter) Write(p []byte) (int, error) {
	w.n += len(p)
	return len(p), nil
}

// shortWriter aceita só metade do que pedem (produz ErrShortWrite via Copy).
type shortWriter struct{}

func (shortWriter) Write(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	return len(p) / 2, nil
}

// wtReader implementa WriterTo: caminho rápido de Copy/CopyBuffer.
type wtReader struct{ s string }

func (r wtReader) Read(p []byte) (int, error) { return copy(p, r.s), io.EOF }
func (r wtReader) WriteTo(w io.Writer) (int64, error) {
	n, err := w.Write([]byte(r.s))
	return int64(n), err
}

// rfWriter implementa ReaderFrom: caminho rápido de Copy/CopyBuffer.
type rfWriter struct{ got string }

func (w *rfWriter) Write(p []byte) (int, error) {
	w.got += string(p)
	return len(p), nil
}
func (w *rfWriter) ReadFrom(r io.Reader) (int64, error) {
	buf, err := io.ReadAll(r)
	w.got += "[via ReadFrom]" + string(buf)
	return int64(len(buf)), err
}

// byteArray é um ReaderAt sobre um []byte, para SectionReader.
type byteArray struct{ data []byte }

func (b *byteArray) ReadAt(p []byte, off int64) (int, error) {
	if off >= int64(len(b.data)) {
		return 0, io.EOF
	}
	n := copy(p, b.data[off:])
	if n < len(p) {
		return n, io.EOF
	}
	return n, nil
}

// scanner implementa io.ByteScanner e io.RuneScanner sobre uma string.
type scanner struct {
	s   string
	pos int
}

func (s *scanner) ReadByte() (byte, error) {
	if s.pos >= len(s.s) {
		return 0, io.EOF
	}
	b := s.s[s.pos]
	s.pos++
	return b, nil
}
func (s *scanner) UnreadByte() error {
	if s.pos == 0 {
		return io.ErrShortBuffer // qualquer erro serve; só testamos != nil
	}
	s.pos--
	return nil
}
func (s *scanner) ReadRune() (rune, int, error) {
	if s.pos >= len(s.s) {
		return 0, 0, io.EOF
	}
	r := rune(s.s[s.pos])
	s.pos++
	return r, 1, nil
}
func (s *scanner) UnreadRune() error { return s.UnreadByte() }

// rsClose implementa io.ReadSeekCloser sobre um []byte.
type rsClose struct {
	data []byte
	pos  int64
}

func (r *rsClose) Read(p []byte) (int, error) {
	if r.pos >= int64(len(r.data)) {
		return 0, io.EOF
	}
	n := copy(p, r.data[r.pos:])
	r.pos += int64(n)
	return n, nil
}
func (r *rsClose) Seek(offset int64, whence int) (int64, error) {
	switch whence {
	case io.SeekStart:
		r.pos = offset
	case io.SeekCurrent:
		r.pos += offset
	case io.SeekEnd:
		r.pos = int64(len(r.data)) + offset
	}
	return r.pos, nil
}
func (r *rsClose) Close() error { return nil }

// try roda f e devolve o valor recuperado de um panic (nil se não houve).
func try(f func()) (r any) {
	defer func() { r = recover() }()
	f()
	return
}

func main() {
	// ReadFull / ReadAtLeast.
	buf := make([]byte, 8)
	n, err := io.ReadFull(&chunkReader{[]byte("abcdefgh")}, buf)
	fmt.Println(n, err, string(buf))
	n, err = io.ReadFull(&chunkReader{[]byte("abc")}, buf)
	fmt.Println(n, err == io.ErrUnexpectedEOF)
	n, err = io.ReadAtLeast(&chunkReader{[]byte("abcdefgh")}, buf, 3)
	fmt.Println(n, err)
	_, err = io.ReadAtLeast(&chunkReader{[]byte("ab")}, buf, 10)
	fmt.Println(err == io.ErrShortBuffer)

	// ReadAll.
	all, err := io.ReadAll(&chunkReader{[]byte("the quick brown fox")})
	fmt.Println(string(all), err)

	// WriteString: com StringWriter (strings.Builder) e sem (countWriter).
	var sb strings.Builder
	wn, werr := io.WriteString(&sb, "hola")
	fmt.Println(wn, werr, sb.String())
	cw := &countWriter{}
	wn, werr = io.WriteString(cw, "adios")
	fmt.Println(wn, werr, cw.n)

	// Copy: devagar (bytes.Buffer não tem os caminhos rápidos no shim) e com
	// WriterTo/ReaderFrom dos dois lados.
	var dst bytes.Buffer
	cn, cerr := io.Copy(&dst, &chunkReader{[]byte("copiado devagar")})
	fmt.Println(cn, cerr, dst.String())

	cw2 := &countWriter{}
	cn, cerr = io.Copy(cw2, wtReader{"fast path do lado do leitor"})
	fmt.Println(cn, cerr, cw2.n)

	rf := &rfWriter{}
	cn, cerr = io.Copy(rf, &chunkReader{[]byte("fast path do lado do escritor")})
	fmt.Println(cn, cerr, rf.got)

	// CopyN: completo e curto (EOF antes do fim).
	dst.Reset()
	cn, cerr = io.CopyN(&dst, &chunkReader{[]byte("0123456789")}, 6)
	fmt.Println(cn, cerr, dst.String())
	_, cerr = io.CopyN(&dst, &chunkReader{[]byte("ab")}, 6)
	fmt.Println(cerr == io.EOF)

	// CopyBuffer: ErrShortWrite e pânico com buffer vazio (não nil).
	cn, cerr = io.CopyBuffer(shortWriter{}, &chunkReader{[]byte("abcdefgh")}, make([]byte, 4))
	fmt.Println(cn, cerr == io.ErrShortWrite)
	fmt.Println(try(func() { io.CopyBuffer(&dst, &chunkReader{nil}, []byte{}) }))

	// Discard.
	dn, derr := io.Copy(io.Discard, &chunkReader{[]byte("vai pro buraco negro")})
	fmt.Println(dn, derr)
	wn, werr = io.WriteString(io.Discard, "tambem some")
	fmt.Println(wn, werr)

	// NopCloser: com e sem WriterTo encaminhado.
	nc := io.NopCloser(&chunkReader{[]byte("nc")})
	nb, _ := io.ReadAll(nc)
	fmt.Println(string(nb), nc.Close())
	ncw := io.NopCloser(wtReader{"nc com writeto"})
	if wt, ok := ncw.(io.WriterTo); ok {
		var wb bytes.Buffer
		wt.WriteTo(&wb)
		fmt.Println(wb.String())
	}

	// LimitReader / LimitedReader (literal composto com os campos R e N).
	lr := &io.LimitedReader{R: &chunkReader{[]byte("0123456789")}, N: 5}
	lb, lerr := io.ReadAll(lr)
	fmt.Println(string(lb), lerr, lr.N)
	lim := io.LimitReader(&chunkReader{[]byte("abcdefgh")}, 3)
	lb2, _ := io.ReadAll(lim)
	fmt.Println(string(lb2))

	// MultiReader / MultiWriter / TeeReader.
	mr := io.MultiReader(&chunkReader{[]byte("uno-")}, &chunkReader{[]byte("dos-")}, &chunkReader{[]byte("tres")})
	mb, _ := io.ReadAll(mr)
	fmt.Println(string(mb))

	var b1, b2 bytes.Buffer
	mw := io.MultiWriter(&b1, &b2)
	io.WriteString(mw, "para os dois")
	fmt.Println(b1.String(), b2.String())

	var teeBuf bytes.Buffer
	tr := io.TeeReader(&chunkReader{[]byte("espiado")}, &teeBuf)
	tb, _ := io.ReadAll(tr)
	fmt.Println(string(tb), teeBuf.String())

	// SectionReader.
	arr := &byteArray{[]byte("0123456789abcdef")}
	sr := io.NewSectionReader(arr, 4, 6)
	srBuf := make([]byte, 3)
	sn, serr := sr.Read(srBuf)
	fmt.Println(sn, serr, string(srBuf))
	pos, serr := sr.Seek(1, io.SeekCurrent)
	fmt.Println(pos, serr)
	all2, _ := io.ReadAll(sr)
	fmt.Println(string(all2), sr.Size())
	outer, off, on := sr.Outer()
	fmt.Println(outer == arr, off, on)
	atBuf := make([]byte, 4)
	an, aerr := sr.ReadAt(atBuf, 4)
	fmt.Println(an, aerr, string(atBuf))

	// ByteScanner / RuneScanner sobre um tipo próprio.
	sc := &scanner{s: "xy"}
	var bs io.ByteScanner = sc
	b, _ := bs.ReadByte()
	fmt.Println(string(b), bs.UnreadByte() != nil)
	b, _ = bs.ReadByte()
	c, _ := bs.ReadByte()
	fmt.Println(string(b), string(c))
	var rns io.RuneScanner = sc
	_, _, rerr := rns.ReadRune()
	fmt.Println(rerr == io.EOF)

	// ReadSeekCloser sobre um tipo próprio.
	var rsc io.ReadSeekCloser = &rsClose{data: []byte("readseekcloser")}
	got := make([]byte, 4)
	rsc.Read(got)
	rsc.Seek(0, io.SeekStart)
	rsc.Read(got)
	fmt.Println(string(got), rsc.Close())
}
