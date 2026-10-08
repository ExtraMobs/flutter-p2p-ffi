// net.Pipe: conexão em memória full duplex (net/pipe.go). Escrita lida em
// pedaços por outra goroutine, Close dos dois lados (EOF e
// ErrClosedPipe), deadlines no passado e no futuro (os.ErrDeadlineExceeded
// embrulhado em *net.OpError, Timeout()) e os endereços "pipe".
package main

import (
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

type res struct {
	n   int
	err error
}

func main() {
	a, b := net.Pipe()
	fmt.Println(a.LocalAddr().Network(), a.LocalAddr(), b.RemoteAddr().String())

	// Escrita grande lida aos pedaços: o Write só volta quando tudo foi lido.
	done := make(chan res)
	go func() {
		n, err := a.Write([]byte("hello, pipe world"))
		done <- res{n, err}
	}()
	buf := make([]byte, 5)
	got := ""
	for len(got) < 17 {
		n, err := b.Read(buf)
		fmt.Printf("read %d %q %v\n", n, buf[:n], err)
		got += string(buf[:n])
	}
	r := <-done
	fmt.Println("write:", r.n, r.err, "got:", got)

	// Full duplex: b escreve, a lê.
	go b.Write([]byte("pong"))
	n, err := io.ReadFull(a, buf[:4])
	fmt.Printf("duplex %d %q %v\n", n, buf[:4], err)

	// Escrita vazia: espera um Read, que lê 0.
	go a.Write([]byte{})
	n, err = b.Read(buf)
	fmt.Println("vazio:", n, err)

	// Deadline no passado: Read e Write falham na hora.
	past := time.Now().Add(-time.Second)
	fmt.Println("set:", b.SetReadDeadline(past))
	n, err = b.Read(buf)
	var ne net.Error
	fmt.Println("read passado:", n, err, errors.Is(err, os.ErrDeadlineExceeded),
		errors.As(err, &ne) && ne.Timeout(), err.(net.Error).Timeout())
	var oe *net.OpError
	if errors.As(err, &oe) {
		fmt.Println("op:", oe.Op, oe.Net, oe.Source == nil, oe.Addr == nil)
	}
	fmt.Println("set:", a.SetWriteDeadline(past))
	n, err = a.Write([]byte("x"))
	fmt.Println("write passado:", n, err)

	// Deadline zero desfaz; no futuro estoura enquanto o Read espera.
	b.SetReadDeadline(time.Time{})
	a.SetDeadline(time.Time{})
	b.SetReadDeadline(time.Now().Add(30 * time.Millisecond))
	n, err = b.Read(buf)
	fmt.Println("read futuro:", n, err, err.(net.Error).Timeout())

	// Deadline renovado no futuro distante não estoura.
	b.SetReadDeadline(time.Now().Add(time.Hour))
	go a.Write([]byte("ok"))
	n, err = b.Read(buf)
	fmt.Printf("read com prazo %d %q %v\n", n, buf[:n], err)

	// Write no meio: o outro lado fecha, o Write devolve o que já foi.
	go func() {
		n, err := a.Write([]byte("abcdefgh"))
		done <- res{n, err}
	}()
	n, _ = b.Read(buf[:3])
	fmt.Printf("lido antes do close %q\n", buf[:n])
	fmt.Println("close b:", b.Close(), b.Close())
	r = <-done
	fmt.Println("write cortado:", r.n, r.err, r.err == io.ErrClosedPipe)

	// Lado fechado: ErrClosedPipe local; EOF lido do outro lado.
	n, err = b.Read(buf)
	fmt.Println("read b fechado:", n, err, err == io.ErrClosedPipe)
	n, err = a.Read(buf)
	fmt.Println("read a:", n, err, err == io.EOF)
	n, err = a.Write([]byte("z"))
	fmt.Println("write a:", n, err)
	fmt.Println("deadline fechado:", a.SetDeadline(time.Now()), b.SetReadDeadline(time.Now()), a.SetWriteDeadline(time.Now()))
	fmt.Println("close a:", a.Close())
}
