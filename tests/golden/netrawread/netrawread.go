// RawConn.Read/Write com syscall.Read/Write numa conexão TCP e Unix de
// fluxo: o padrão do readyreader do gRPC (internal/transport/readyreader),
// que pega o SyscallConn de um *net.TCPConn e lê com
// raw.Read(func(fd) bool { n, err = syscall.Read(fd, buf); return !wouldBlock(err) }).
// Na VM a conexão é do dart:io e o fd é virtual: o syscall.Read lê do
// mesmo RawSocket sem esperar (EAGAIN sem dado, 0 no EOF) e convive com o
// Read normal sem perder bytes; o raw.Read espera a prontidão, respeita o
// prazo (i/o timeout) e o Close.
//
// No Node (F4/F5, netrawread.node.out) não há descritor: syscall.Read/Write
// e o RawConn.Read/Write dão "operation not supported". Cada linha junta o
// que depende do raw, para a divergência ficar na linha da falha.
package main

import (
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"syscall"
	"time"
)

var labels [][2]string

func label(real, name string) { labels = append(labels, [2]string{real, name}) }

func clean(err error) string {
	if err == nil {
		return "<nil>"
	}
	s := err.Error()
	for i := len(labels) - 1; i >= 0; i-- {
		s = strings.ReplaceAll(s, labels[i][0], labels[i][1])
	}
	return s
}

func wouldBlock(err error) bool { return err == syscall.EAGAIN || err == syscall.EWOULDBLOCK }

// readOnReady é o nonBlockingReader.ReadOnReady do gRPC.
func readOnReady(raw syscall.RawConn, size int) (string, error) {
	var buf []byte
	var n int
	var rerr error
	err := raw.Read(func(fd uintptr) bool {
		buf = make([]byte, size)
		n, rerr = syscall.Read(int(fd), buf)
		return !wouldBlock(rerr)
	})
	if err != nil {
		return "", err
	}
	if rerr != nil {
		return "", rerr
	}
	if n == 0 {
		return "", io.EOF
	}
	return string(buf[:n]), nil
}

func show(name string, data string, err error) {
	fmt.Printf("%s: %q %s\n", name, data, clean(err))
}

func main() {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	label(ln.Addr().String(), "SRV")
	acc := make(chan net.Conn)
	go func() {
		c, _ := ln.Accept()
		acc <- c
	}()
	conn, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		panic(err)
	}
	srv := <-acc
	label(conn.LocalAddr().String(), "CL")
	c := conn.(*net.TCPConn)

	raw, err := c.SyscallConn()
	fmt.Println("syscallconn:", err)

	// Sem dado: syscall.Read no fd não bloqueante dá EAGAIN.
	var n int
	var rerr error
	cerr := raw.Control(func(fd uintptr) {
		n, rerr = syscall.Read(int(fd), make([]byte, 8))
	})
	fmt.Println("read vazio:", n, clean(rerr), wouldBlock(rerr), cerr)

	// Dado chegando: raw.Read acorda e lê.
	srv.Write([]byte("hello"))
	d, err := readOnReady(raw, 64)
	show("ready", d, err)

	// Leitura parcial pelo raw e o resto pelo Read normal: nada se perde.
	srv.Write([]byte("abcdef"))
	d, err = readOnReady(raw, 3)
	rest := make([]byte, 16)
	m, err2 := c.Read(rest)
	fmt.Printf("parcial: %q %s / %q %v\n", d, clean(err), rest[:m], err2)

	// O inverso: Read normal parcial, depois o raw.
	srv.Write([]byte("123456"))
	m, err2 = c.Read(rest[:2])
	d, err = readOnReady(raw, 64)
	fmt.Printf("inverso: %q %v / %q %s\n", rest[:m], err2, d, clean(err))

	// Leitor parado no raw.Read; o dado chega depois.
	done := make(chan string)
	go func() {
		d, err := readOnReady(raw, 64)
		done <- fmt.Sprintf("%q %s", d, clean(err))
	}()
	time.Sleep(50 * time.Millisecond)
	srv.Write([]byte("depois"))
	fmt.Println("espera:", <-done)

	// Prazo vencido: falha antes do f.
	calls := 0
	c.SetReadDeadline(time.Now().Add(-time.Second))
	err = raw.Read(func(uintptr) bool { calls++; return true })
	fmt.Println("prazo vencido:", calls, clean(err), errors.Is(err, os.ErrDeadlineExceeded))

	// Prazo durante a espera: o f roda uma vez (EAGAIN) e o prazo vence.
	calls = 0
	c.SetReadDeadline(time.Now().Add(50 * time.Millisecond))
	err = raw.Read(func(fd uintptr) bool {
		calls++
		_, e := syscall.Read(int(fd), make([]byte, 8))
		return !wouldBlock(e)
	})
	fmt.Println("prazo na espera:", calls, clean(err), errors.Is(err, os.ErrDeadlineExceeded))
	c.SetReadDeadline(time.Time{})

	// raw.Write com syscall.Write; o servidor lê pelo Read normal.
	var wn int
	var werr error
	err = raw.Write(func(fd uintptr) bool {
		wn, werr = syscall.Write(int(fd), []byte("cru"))
		return !wouldBlock(werr)
	})
	got := make([]byte, 16)
	k := 0
	if err == nil && wn > 0 { // no Node nada foi escrito: ler travaria
		k, _ = srv.Read(got)
	}
	fmt.Printf("raw write: %d %v %s / %q\n", wn, werr, clean(err), got[:k])

	// Encher o buffer de escrita: EAGAIN; o raw.Write então espera até o prazo.
	big := make([]byte, 1<<16)
	var ferr error
	raw.Control(func(fd uintptr) {
		for i := 0; i < 4096; i++ {
			if _, ferr = syscall.Write(int(fd), big); ferr != nil {
				break
			}
		}
	})
	c.SetWriteDeadline(time.Now().Add(50 * time.Millisecond))
	calls = 0
	err = raw.Write(func(fd uintptr) bool {
		calls++
		_, e := syscall.Write(int(fd), big)
		return !wouldBlock(e)
	})
	fmt.Println("buffer cheio:", clean(ferr), wouldBlock(ferr), "/", calls, clean(err))

	// EOF: o par fecha; syscall.Read dá 0 e o leitor vê io.EOF. Antes, o
	// cliente para de escrever e o servidor descarta o que sobrou.
	c.SetWriteDeadline(time.Time{})
	c.CloseWrite()
	io.Copy(io.Discard, srv)
	srv.Close()
	d, err = readOnReady(raw, 64)
	show("eof", d, err)

	// Depois do Close: use of closed network connection.
	c.Close()
	err = raw.Read(func(uintptr) bool { return true })
	fmt.Println("fechado:", clean(err), errors.Is(err, net.ErrClosed))
	ln.Close()

	// Unix de fluxo: o mesmo padrão.
	path := fmt.Sprintf("/tmp/g2d-netrawread-%d.sock", os.Getpid())
	label(path, "SOCK")
	uln, err := net.Listen("unix", path)
	if err != nil {
		panic(err)
	}
	go func() {
		c, _ := uln.Accept()
		acc <- c
	}()
	uc, err := net.Dial("unix", path)
	if err != nil {
		panic(err)
	}
	us := <-acc
	uraw, err := uc.(*net.UnixConn).SyscallConn()
	fmt.Println("unix syscallconn:", err)
	us.Write([]byte("unix hello"))
	d, err = readOnReady(uraw, 64)
	us.Close()
	d2, err2 := readOnReady(uraw, 64)
	fmt.Printf("unix: %q %s / %q %s\n", d, clean(err), d2, clean(err2))
	uc.Close()
	uln.Close()
}
