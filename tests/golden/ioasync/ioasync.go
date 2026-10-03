// I/O que suspende atrás das interfaces de io (decisão D2, versão dupla):
// Reader/Writer/Closer gerados que esperam outra goroutine, io.Pipe e as
// funções do shim que os chamam (io.ReadAll, fmt.Fprintf...) na forma $async;
// tipos concretos do shim seguem síncronos.
package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"sort"
	"strings"
	"sync"
)

// chanReader espera os pedaços de uma goroutine (o repro do D2).
type chanReader struct{ ch chan []byte }

func (r *chanReader) Read(p []byte) (int, error) {
	b, ok := <-r.ch
	if !ok {
		return 0, io.EOF
	}
	return copy(p, b), nil
}

// chanWriter entrega cada Write a um consumidor e espera a confirmação.
type chanWriter struct {
	ch   chan string
	done chan int
}

func (w *chanWriter) Write(p []byte) (int, error) {
	w.ch <- string(p)
	return <-w.done, nil
}

// sliceReader nunca suspende, mas está no mesmo grupo de io.Reader.
type sliceReader struct {
	data []byte
	pos  int
}

func (r *sliceReader) Read(p []byte) (int, error) {
	if r.pos >= len(r.data) {
		return 0, io.EOF
	}
	n := copy(p, r.data[r.pos:])
	r.pos += n
	return n, nil
}

// prefixed embute a interface: Read promovido nas duas formas.
type prefixed struct {
	io.Reader
	tag string
}

type nopCloser struct{}

func (nopCloser) Close() error { return nil }

type upperReader struct{ r io.Reader }

func (u upperReader) Read(p []byte) (int, error) {
	n, err := u.r.Read(p)
	copy(p, bytes.ToUpper(p[:n]))
	return n, err
}

// worker: Close espera as goroutines (io.Closer que suspende).
type worker struct {
	wg  sync.WaitGroup
	out []string
	mu  sync.Mutex
}

func (w *worker) start(names ...string) {
	for _, n := range names {
		w.wg.Add(1)
		go func() {
			defer w.wg.Done()
			w.mu.Lock()
			w.out = append(w.out, n)
			w.mu.Unlock()
		}()
	}
}

func (w *worker) Close() error {
	w.wg.Wait()
	return nil
}

// label fica síncrono: String() escreve num *strings.Builder (shim concreto).
type label struct{ name string }

func (l label) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "<%s>", l.name)
	return sb.String()
}

// multi escreve por um io.Writer (async no grafo): Error() fica síncrono
// chamando a gêmea síncrona de writeAll (um *bytes.Buffer não suspende).
type multi struct{ items []string }

func (m *multi) writeAll(w io.Writer) {
	for i, s := range m.items {
		if i > 0 {
			w.Write([]byte("; "))
		}
		io.WriteString(w, s)
	}
}

func (m *multi) Error() string {
	var b bytes.Buffer
	m.writeAll(&b)
	return b.String()
}

func feed(parts ...string) *chanReader {
	r := &chanReader{ch: make(chan []byte)}
	go func() {
		for _, p := range parts {
			r.ch <- []byte(p)
		}
		close(r.ch)
	}()
	return r
}

func readAll(r io.Reader) string {
	b, err := io.ReadAll(r)
	if err != nil {
		return "erro: " + err.Error()
	}
	return string(b)
}

// sortedClose guarda Close (async no grafo) numa func() error que o shim
// sort força síncrona: vale a forma síncrona do Close de um nopCloser.
func sortedClose(c io.Closer) error {
	fs := []func() error{c.Close}
	sort.Slice(fs, func(i, j int) bool { return false })
	return fs[0]()
}

func closeAll(cs ...io.Closer) {
	for _, c := range cs {
		c.Close()
	}
}

func main() {
	// 1. O repro do D2: Read que espera um canal, lido pelo shim.
	fmt.Println(readAll(feed("oi", " ", "mundo")))

	// 2. io.Pipe: o escritor numa goroutine, fmt.Fprintf no PipeWriter.
	pr, pw := io.Pipe()
	go func() {
		for i := 1; i <= 3; i++ {
			fmt.Fprintf(pw, "linha %d\n", i)
		}
		pw.Close()
	}()
	fmt.Print(readAll(pr))

	// Pipe fechado pelo leitor: o Write falha com ErrClosedPipe.
	pr2, pw2 := io.Pipe()
	pr2.Close()
	_, err := pw2.Write([]byte("x"))
	fmt.Println(err)
	pr3, pw3 := io.Pipe()
	pw3.CloseWithError(fmt.Errorf("parou"))
	_, err = pr3.Read(make([]byte, 4))
	fmt.Println(err)

	// 3. Writer gerado que suspende, via fmt.Fprintln e io.WriteString.
	cw := &chanWriter{ch: make(chan string), done: make(chan int)}
	got := make(chan []string)
	go func() {
		var all []string
		for s := range cw.ch {
			all = append(all, s)
			cw.done <- len(s)
		}
		got <- all
	}()
	var w io.Writer = cw
	n, _ := fmt.Fprintln(w, "a", 1, true)
	m, _ := io.WriteString(w, "fim")
	(&multi{items: []string{"p", "q"}}).writeAll(w)
	close(cw.ch)
	fmt.Printf("%q %d %d\n", <-got, n, m)

	// 4. Shim concreto continua síncrono, mesmo com io.Writer async.
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "%d+%d", 2, 3)
	buf.Write([]byte("=5"))
	fmt.Println(buf.String(), label{"x"})
	var e error = &multi{items: []string{"um", "dois"}}
	fmt.Println(e)

	// 5. Embedding da interface e wrapper sobre leitor que suspende.
	pf := &prefixed{Reader: feed("abc", "def"), tag: "up"}
	fmt.Println(pf.tag, readAll(upperReader{pf}))
	fmt.Println(readAll(&sliceReader{data: []byte("fatia")}))

	// 6. Method value de Read que suspende, chamado pelo valor.
	read := feed("xyz").Read
	p := make([]byte, 8)
	k, _ := read(p)
	fmt.Println(string(p[:k]))

	// 7. io.ReadFull, bytes.Buffer.ReadFrom e binary sobre leitor que suspende.
	full := make([]byte, 4)
	k, err = io.ReadFull(feed("ab", "cd", "ef"), full)
	fmt.Println(string(full), k, err)
	var into bytes.Buffer
	into.ReadFrom(feed("de", "pois"))
	fmt.Println(into.String())
	var x uint32
	err = binary.Read(feed("\x01\x02", "\x03\x04"), binary.BigEndian, &x)
	fmt.Printf("%#x %v\n", x, err)

	// 8. io.Closer cujo Close espera um WaitGroup.
	wk := &worker{}
	wk.start("a", "b", "c")
	closeAll(wk, nopCloser{})
	fmt.Println(sortedClose(nopCloser{}))
	fmt.Println(len(wk.out))
}
