// Sockets Unix de fluxo no shim net (decisão D4): eco por goroutine sobre
// um socket em /tmp, endereços dos dois lados (o lado que disca é "@"),
// io.Copy sobre a conexão, CloseWrite, deadlines, Close, o unlink do
// listener no Close, os métodos de net.PacketConn do UnixConn e os erros
// (caminho ausente, caminho ocupado, rede desconhecida, sem endereço).
// O caminho tem o pid: nada aqui o imprime (o texto dos erros troca o
// caminho por SOCK). Tudo que uma goroutine descobre volta por canal, para
// a ordem da saída não depender do escalonador.
package main

import (
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"time"
)

var sock = fmt.Sprintf("/tmp/g2d-netunix-%d.sock", os.Getpid())

// clean troca o caminho do socket pelo texto fixo SOCK.
func clean(err error) string {
	if err == nil {
		return "<nil>"
	}
	return strings.ReplaceAll(err.Error(), sock, "SOCK")
}

func addr(a net.Addr) string {
	if a == nil {
		return "<nil>"
	}
	return a.Network() + " " + strings.ReplaceAll(a.String(), sock, "SOCK")
}

// echoServer aceita até o listener fechar; o que descobre vai por canal.
func echoServer(ln net.Listener, wg *sync.WaitGroup, aceitos chan<- string, parou chan<- string) {
	defer wg.Done()
	for {
		c, err := ln.Accept()
		if err != nil {
			parou <- fmt.Sprintf("accept parou: %v %v", errors.Is(err, net.ErrClosed), clean(err))
			return
		}
		aceitos <- fmt.Sprintf("aceito local: %v remoto: %v", addr(c.LocalAddr()), addr(c.RemoteAddr()))
		wg.Add(1)
		go func(c net.Conn) {
			defer wg.Done()
			defer c.Close()
			io.Copy(c, c)
		}(c)
	}
}

// ping recebe a conexão como io.ReadWriter (como os wrappers do libp2p).
func ping(rw io.ReadWriter) {
	io.WriteString(rw, "oi!")
	b := make([]byte, 3)
	_, err := io.ReadFull(rw, b)
	fmt.Printf("ping %q %v\n", b, err)
}

func main() {
	ln, err := net.Listen("unix", sock)
	if err != nil {
		panic(err)
	}
	fmt.Printf("listener %T %v\n", ln, addr(ln.Addr()))

	// Caminho já ocupado.
	_, err = net.Listen("unix", sock)
	fmt.Println("listen de novo:", clean(err))

	// Caminho que não existe.
	_, err = net.Dial("unix", sock+"-ausente")
	fmt.Println("dial ausente:", clean(err))
	var op *net.OpError
	fmt.Println("  OpError:", errors.As(err, &op), op.Op, op.Net, addr(op.Addr), op.Source == nil, op.Timeout())

	var wg sync.WaitGroup
	aceitos, parou := make(chan string, 4), make(chan string, 1)
	wg.Add(1)
	go echoServer(ln, &wg, aceitos, parou)

	c, err := net.Dial("unix", sock)
	if err != nil {
		panic(err)
	}
	fmt.Println("cliente local:", addr(c.LocalAddr()), "remoto:", addr(c.RemoteAddr()))
	uc, ok := c.(*net.UnixConn)
	fmt.Println("é *net.UnixConn:", ok)
	ping(c)
	fmt.Println(<-aceitos)

	// CloseWrite: o eco termina e o cliente lê tudo até o EOF.
	io.WriteString(c, "tchau")
	uc.CloseWrite()
	rest, err := io.ReadAll(c)
	fmt.Printf("resto %q %v\n", rest, err)

	// Deadline vencido e Close.
	c.SetReadDeadline(time.Now().Add(-time.Second))
	_, err = c.Read(make([]byte, 1))
	fmt.Println("read com prazo vencido:", clean(err), os.IsTimeout(err))
	fmt.Println("close:", clean(c.Close()), "| de novo:", clean(c.Close()))
	_, err = c.Read(make([]byte, 1))
	fmt.Println("read depois do close:", clean(err), errors.Is(err, net.ErrClosed))

	// net.PacketConn no UnixConn, com um par novo (DialUnix).
	ul, ok := ln.(*net.UnixListener)
	fmt.Println("é *net.UnixListener:", ok)
	raddr, rerr := net.ResolveUnixAddr("unix", sock)
	fmt.Println("ResolveUnixAddr:", addr(raddr), clean(rerr))
	dialed, err := net.DialUnix("unix", nil, raddr)
	fmt.Println("DialUnix:", clean(err))
	n, werr := dialed.WriteTo([]byte("x"), raddr)
	fmt.Println("WriteTo do lado que discou:", n, clean(werr), errors.Is(werr, net.ErrWriteToConnected))
	dialed.Write([]byte("pacote"))
	dialed.CloseWrite()
	fmt.Println(<-aceitos)
	buf := make([]byte, 10)
	got, from, perr := dialed.ReadFrom(buf)
	fmt.Printf("ReadFrom %q de %v %v\n", buf[:got], addr(from), clean(perr))
	got, from, perr = dialed.ReadFrom(buf)
	fmt.Println("ReadFrom no EOF:", got, addr(from), clean(perr), errors.Is(perr, io.EOF))
	n, werr = dialed.WriteTo([]byte("x"), nil)
	fmt.Println("WriteTo com addr nil:", n, clean(werr))
	n, werr = dialed.WriteTo([]byte("x"), &net.TCPAddr{})
	fmt.Println("WriteTo com outro tipo:", n, clean(werr))
	dialed.Close()

	// Close do listener: apaga o arquivo do socket e para o accept.
	fmt.Println("close do listener:", clean(ul.Close()), "| de novo:", clean(ul.Close()))
	fmt.Println(<-parou)
	wg.Wait()
	_, err = net.Dial("unix", sock)
	fmt.Println("dial depois do unlink:", clean(err))

	// Redes e endereços recusados.
	_, err = net.DialUnix("unix", nil, nil)
	fmt.Println("DialUnix sem raddr:", clean(err))
	_, err = net.DialUnix("tcp", nil, raddr)
	fmt.Println("DialUnix em tcp:", clean(err))
	_, err = net.ListenUnix("unixgram", raddr)
	fmt.Println("ListenUnix em unixgram:", clean(err))
	_, err = net.ListenUnix("unix", nil)
	fmt.Println("ListenUnix sem laddr:", clean(err))
	_, err = net.Dial("tulipa", sock)
	fmt.Println("rede desconhecida:", clean(err))

	// ListenUnix/AcceptUnix, prazo do accept e o Dialer.
	l2, err := net.ListenUnix("unix", raddr)
	fmt.Println("ListenUnix:", clean(err), addr(l2.Addr()))
	l2.SetDeadline(time.Now().Add(-time.Second))
	_, err = l2.Accept()
	fmt.Println("accept com prazo vencido:", clean(err), os.IsTimeout(err))
	l2.SetDeadline(time.Time{})
	aceito := make(chan string, 1)
	go func() {
		a, err := l2.AcceptUnix()
		if err != nil {
			aceito <- "accept: " + clean(err)
			return
		}
		b := make([]byte, 5)
		k, _ := io.ReadFull(a, b)
		a.Write(b[:k])
		a.CloseWrite()
		aceito <- fmt.Sprintf("aceito %q remoto %v", b[:k], addr(a.RemoteAddr()))
		a.Close()
	}()
	d := &net.Dialer{Timeout: 2 * time.Second}
	c2, err := d.Dial("unix", sock)
	fmt.Println("Dialer.Dial:", clean(err))
	io.WriteString(c2, "ciclo")
	volta, _ := io.ReadAll(c2)
	fmt.Printf("volta %q\n", volta)
	fmt.Println(<-aceito)
	c2.Close()
	l2.Close()
	fmt.Println("fim")
}
