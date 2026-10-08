// net.Buffers (net.go): WriteTo para um io.Writer comum (bytes.Buffer), para
// um Writer que falha no meio (consumo parcial, com o array de fora vendo o
// v[i] recortado), Read em pedaços até EOF, io.Copy/io.ReadAll pelo
// *Buffers, e o writev das conexões: TCP local (fluxo), UDP conectado (um
// datagrama só com todos os pedaços) e conexão fechada (*OpError "writev").
// As portas mudam a cada execução: nada aqui as imprime.
package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
)

// shortWriter aceita no máximo max bytes e depois falha.
type shortWriter struct {
	buf bytes.Buffer
	max int
}

var errFull = errors.New("cheio")

func (w *shortWriter) Write(p []byte) (int, error) {
	if w.buf.Len()+len(p) > w.max {
		n := w.max - w.buf.Len()
		w.buf.Write(p[:n])
		return n, errFull
	}
	return w.buf.Write(p)
}

func show(label string, v net.Buffers) {
	fmt.Printf("%s: len=%d %q\n", label, len(v), [][]byte(v))
}

func main() {
	// WriteTo num bytes.Buffer: tudo vai, v fica vazio.
	var buf bytes.Buffer
	v := net.Buffers{[]byte("ab"), []byte("cd"), nil, []byte("ef")}
	n, err := v.WriteTo(&buf)
	fmt.Println("writeTo:", n, err, buf.String())
	show("depois", v)

	// Writer que falha no meio: consome só o que foi.
	v = net.Buffers{[]byte("hello"), []byte(" "), []byte("world")}
	orig := v
	w := &shortWriter{max: 8}
	n, err = v.WriteTo(w)
	fmt.Println("parcial:", n, err, w.buf.String())
	show("resto", v)
	show("orig", orig)

	// Read em pedaços de 3 até EOF.
	v = net.Buffers{[]byte("abcd"), []byte("e"), []byte("fghij")}
	p := make([]byte, 3)
	for {
		n, err := v.Read(p)
		fmt.Printf("read %d %q %v len=%d\n", n, p[:n], err, len(v))
		if err != nil {
			break
		}
	}
	n2, err := v.Read(nil)
	fmt.Println("read vazio:", n2, err)

	// *Buffers como io.WriterTo (io.Copy) e io.Reader (io.ReadAll).
	buf.Reset()
	v = net.Buffers{[]byte("x"), []byte("yz")}
	n, err = io.Copy(&buf, &v)
	fmt.Println("copy:", n, err, buf.String(), len(v))
	v = net.Buffers{[]byte("rea"), []byte("dall")}
	all, err := io.ReadAll(&v)
	fmt.Printf("readAll: %q %v %d\n", all, err, len(v))

	// TCP local: WriteTo na conexão usa o writev.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	got := make(chan string)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			panic(err)
		}
		b, err := io.ReadAll(c)
		got <- fmt.Sprintf("%q %v", b, err)
		c.Close()
	}()
	c, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		panic(err)
	}
	big := bytes.Repeat([]byte("0123456789"), 100000)
	v = net.Buffers{[]byte("tcp:"), nil, []byte("um"), []byte("dois"), big[:10]}
	n, err = v.WriteTo(c)
	fmt.Println("tcp writeTo:", n, err, len(v))
	v = net.Buffers{big, []byte("fim")}
	n, err = v.WriteTo(c)
	fmt.Println("tcp grande:", n, err, len(v))
	c.(*net.TCPConn).CloseWrite()
	s := <-got
	fmt.Println("servidor:", len(s), s[:30], s[len(s)-12:])
	c.Close()
	v = net.Buffers{[]byte("x")}
	n, err = v.WriteTo(c)
	var oe *net.OpError
	fmt.Println("fechada:", n, errors.As(err, &oe), errors.Is(err, net.ErrClosed), len(v))
	fmt.Println("op:", oe.Op, oe.Net, oe.Err)
	ln.Close()

	// UDP conectado: os pedaços saem num datagrama só.
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	uc, err := net.DialUDP("udp", nil, pc.LocalAddr().(*net.UDPAddr))
	if err != nil {
		panic(err)
	}
	v = net.Buffers{[]byte("a"), []byte("bc"), nil, []byte("def")}
	n, err = v.WriteTo(uc)
	fmt.Println("udp writeTo:", n, err, len(v))
	d := make([]byte, 64)
	m, _, err := pc.ReadFrom(d)
	fmt.Printf("udp datagrama: %d %q %v\n", m, d[:m], err)
	uc.Close()
	pc.Close()
}
