// Rede de verdade no shim net (decisão D4): TCP em loopback com eco por
// goroutine, io.Copy sobre a conexão, deadline que estoura, conexão
// recusada, CloseWrite, Close durante Read e um tipo gerado que embrulha
// net.Conn. As portas mudam a cada execução: nada aqui as imprime.
package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"time"
)

// countingConn embrulha a conexão (como os wrappers do libp2p).
type countingConn struct {
	net.Conn
	read, written int
}

func (c *countingConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	c.read += n
	return n, err
}

func (c *countingConn) Write(p []byte) (int, error) {
	n, err := c.Conn.Write(p)
	c.written += n
	return n, err
}

func echoServer(ln net.Listener, wg *sync.WaitGroup) {
	defer wg.Done()
	for {
		c, err := ln.Accept()
		if err != nil {
			fmt.Println("accept parou:", errors.Is(err, net.ErrClosed))
			return
		}
		wg.Add(1)
		go func(c net.Conn) {
			defer wg.Done()
			defer c.Close()
			if _, err := io.Copy(c, c); err != nil {
				fmt.Println("eco:", err)
			}
		}(c)
	}
}

// ping recebe a conexão como io.ReadWriter (como o socks do x/net).
func ping(rw io.ReadWriter) {
	io.WriteString(rw, "oi!")
	b := make([]byte, 3)
	_, err := io.ReadFull(rw, b)
	fmt.Printf("ping %q %v\n", b, err)
}

func describe(err error) {
	var op *net.OpError
	if errors.As(err, &op) {
		fmt.Printf("OpError op=%s net=%s timeout=%v err=%v\n", op.Op, op.Net, op.Timeout(), op.Err)
	} else {
		fmt.Println("erro:", err)
	}
	var ne net.Error
	fmt.Println("  net.Error:", errors.As(err, &ne) && ne.Timeout(), os.IsTimeout(err),
		errors.Is(err, os.ErrDeadlineExceeded), errors.Is(err, net.ErrClosed))
}

func main() {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	fmt.Println("listen:", ln.Addr().Network(), ln.Addr().(*net.TCPAddr).IP)
	var wg sync.WaitGroup
	wg.Add(1)
	go echoServer(ln, &wg)

	c, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		panic(err)
	}
	tc := c.(*net.TCPConn)
	fmt.Println("remote igual:", tc.RemoteAddr().String() == ln.Addr().String())
	fmt.Fprintf(c, "olá %d\n", 42)
	line := make([]byte, 8)
	n0, err := io.ReadFull(c, line)
	fmt.Printf("%q %v\n", line[:n0], err)
	ping(c)

	// Conexão embrulhada por tipo gerado: as chamadas passam pela interface.
	cc := &countingConn{Conn: c}
	big := bytes.Repeat([]byte("0123456789abcdef"), 1<<16) // 1 MiB
	go func() {
		if _, err := cc.Write(big); err != nil {
			fmt.Println("write:", err)
		}
	}()
	got := make([]byte, len(big))
	n, err := io.ReadFull(cc, got)
	fmt.Println("1 MiB de volta:", n, err, bytes.Equal(got, big), cc.read == len(big))

	// Deadline que estoura numa leitura parada.
	c.SetReadDeadline(time.Now().Add(30 * time.Millisecond))
	_, err = c.Read(got[:10])
	describe(err)
	c.SetReadDeadline(time.Time{})

	// CloseWrite: o eco devolve o que falta e fecha; a leitura vê EOF.
	io.WriteString(c, "fim")
	tc.CloseWrite()
	rest, err := io.ReadAll(c)
	fmt.Printf("resto %q %v\n", rest, err)
	c.Close()
	_, err = c.Read(got[:1])
	describe(err)

	// Close durante um Read pendente em outra goroutine.
	c2, err := net.DialTimeout("tcp", ln.Addr().String(), time.Second)
	if err != nil {
		panic(err)
	}
	done := make(chan error)
	go func() {
		_, err := c2.Read(make([]byte, 1))
		done <- err
	}()
	time.Sleep(20 * time.Millisecond)
	c2.Close()
	describe(<-done)

	// Porta fechada: conexão recusada.
	tmp, _ := net.Listen("tcp", "127.0.0.1:0")
	addr := tmp.Addr().String()
	tmp.Close()
	_, err = net.Dial("tcp", addr)
	describe(err)
	fmt.Println(strings.HasSuffix(err.Error(), "connect: connection refused"))

	// Endereço inválido e rede desconhecida.
	_, err = net.Dial("tcp", "sem-porta")
	fmt.Println(err)
	_, err = net.Dial("ipx", "1.2.3.4:5")
	fmt.Println(err)

	ln.Close()
	wg.Wait()
}
