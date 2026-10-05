// SetLinger e keepalive do TCPConn no shim net (decisão D4): o Close
// normal manda FIN (o par lê EOF); com SetLinger(0) o Close descarta e
// manda RST (o par lê "connection reset by peer", e depois EOF). Os
// ajustes de keepalive (SetKeepAlive, SetKeepAlivePeriod com zero,
// negativo e fração de segundo) e SetLinger com prazo devolvem nil numa
// conexão aberta e o erro do Go numa fechada. As portas mudam a cada
// execução: nada aqui as imprime.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"time"
)

func describe(what string, err error) {
	if err == nil {
		fmt.Println(what+":", "nil")
		return
	}
	var op *net.OpError
	if errors.As(err, &op) {
		fmt.Printf("%s: op=%s net=%s err=%v closed=%v\n", what, op.Op, op.Net, op.Err,
			errors.Is(err, net.ErrClosed))
		return
	}
	fmt.Printf("%s: %v eof=%v\n", what, err, errors.Is(err, io.EOF))
}

type accepted struct {
	c   *net.TCPConn
	err error
}

// pair devolve o cliente e o lado aceito de uma conexão em loopback.
func pair(ln *net.TCPListener) (*net.TCPConn, *net.TCPConn) {
	ch := make(chan accepted)
	go func() {
		c, err := ln.AcceptTCP()
		ch <- accepted{c, err}
	}()
	c, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		panic(err)
	}
	r := <-ch
	if r.err != nil {
		panic(r.err)
	}
	return c.(*net.TCPConn), r.c
}

// closeAndRead fecha o servidor (com linger zero, se pedido) e lê duas
// vezes no cliente.
func closeAndRead(name string, ln *net.TCPListener, linger bool) {
	c, s := pair(ln)
	defer c.Close()
	// O par conversa antes: a conexão está firme dos dois lados.
	io.WriteString(s, "oi")
	b := make([]byte, 2)
	io.ReadFull(c, b)
	if linger {
		describe(name+" SetLinger(0)", s.SetLinger(0))
	}
	describe(name+" Close", s.Close())
	_, err := c.Read(b)
	describe(name+" 1a leitura", err)
	_, err = c.Read(b)
	describe(name+" 2a leitura", err)
}

func main() {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	ln := l.(*net.TCPListener)
	defer ln.Close()

	closeAndRead("normal", ln, false)
	closeAndRead("linger", ln, true)

	// Ajustes numa conexão aberta: todos nil.
	c, s := pair(ln)
	describe("SetLinger(5)", s.SetLinger(5))
	describe("SetLinger(-1)", s.SetLinger(-1))
	describe("SetKeepAlive(false)", c.SetKeepAlive(false))
	describe("SetKeepAlivePeriod(0)", c.SetKeepAlivePeriod(0))
	describe("SetKeepAlivePeriod(1500ms)", c.SetKeepAlivePeriod(1500*time.Millisecond))
	describe("SetKeepAlivePeriod(-1)", c.SetKeepAlivePeriod(-1))
	describe("SetKeepAlive(true)", c.SetKeepAlive(true))
	// Sem linger zero, o Close entrega ao par o que foi escrito antes.
	io.WriteString(s, "tchau")
	describe("Close com SetLinger(-1)", s.Close())
	rest, err := io.ReadAll(c)
	fmt.Printf("par leu %q %v\n", rest, err)

	// Numa conexão fechada: o erro do Go.
	c.Close()
	describe("fechada SetLinger(0)", c.SetLinger(0))
	describe("fechada SetKeepAlivePeriod", c.SetKeepAlivePeriod(time.Second))
	describe("fechada SetKeepAlive", c.SetKeepAlive(true))

	// Dialer e ListenConfig com KeepAlive negativo (desliga) ou próprio.
	d := net.Dialer{KeepAlive: -1}
	c2, err := d.Dial("tcp", ln.Addr().String())
	describe("Dial KeepAlive=-1", err)
	s2, _ := ln.Accept()
	c2.Close()
	s2.Close()
	lc := net.ListenConfig{KeepAlive: 30 * time.Second}
	l3, err := lc.Listen(context.Background(), "tcp", "127.0.0.1:0")
	describe("Listen KeepAlive=30s", err)
	l3.Close()
}
