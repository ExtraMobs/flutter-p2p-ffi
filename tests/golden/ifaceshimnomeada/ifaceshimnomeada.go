// Valor de classe de shim convertido para interface NOMEADA do pacote
// (D8): o `*bytes.Buffer` como `LW` e o `*net.UDPConn` como o `UDPConn` com
// a forma do de github.com/pion/transport (o `stdnet` devolve
// `net.ListenUDP(...)` direto). O g2d embrulha o valor num adaptador gerado
// que implementa a interface e é transparente para assertion, `==`, `%T`/`%v`.
package main

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"reflect"
	"time"
)

type LW interface {
	Write([]byte) (int, error)
	Len() int
}

func mk() (LW, error) { return new(bytes.Buffer), nil }

func use(w LW, s string) int {
	n, _ := w.Write([]byte(s))
	return n
}

type holder struct{ w LW }

// UDPConn com a forma do `transport.UDPConn` do pion.
type UDPConn interface {
	Close() error
	LocalAddr() net.Addr
	RemoteAddr() net.Addr
	SetDeadline(t time.Time) error
	SetReadDeadline(t time.Time) error
	SetWriteDeadline(t time.Time) error
	SetReadBuffer(bytes int) error
	SetWriteBuffer(bytes int) error
	Read(b []byte) (n int, err error)
	ReadFrom(p []byte) (n int, addr net.Addr, err error)
	ReadFromUDP(b []byte) (n int, addr *net.UDPAddr, err error)
	ReadMsgUDP(b, oob []byte) (n, oobn, flags int, addr *net.UDPAddr, err error)
	Write(b []byte) (n int, err error)
	WriteTo(p []byte, addr net.Addr) (n int, err error)
	WriteToUDP(b []byte, addr *net.UDPAddr) (int, error)
	WriteMsgUDP(b, oob []byte, addr *net.UDPAddr) (n, oobn int, err error)
}

type Net struct{}

func (n *Net) ListenUDP(network string, locAddr *net.UDPAddr) (UDPConn, error) {
	return net.ListenUDP(network, locAddr)
}

func (n *Net) DialUDP(network string, laddr, raddr *net.UDPAddr) (UDPConn, error) {
	return net.DialUDP(network, laddr, raddr)
}

func lw() {
	l, err := mk()
	fmt.Println(l.Len(), err)
	l.Write([]byte("abc"))
	fmt.Println(use(l, "de"), use(new(bytes.Buffer), "xyz"))
	var l2 LW = &bytes.Buffer{}
	h := holder{w: bytes.NewBufferString("h")}
	ws := []LW{l, l2, h.w}
	fmt.Printf("%T %v %d %s\n", l, l, l.Len(), ws[2])
	b := l.(*bytes.Buffer)
	fmt.Println(b.String())
	if r, ok := l.(io.Reader); ok {
		p := make([]byte, 2)
		n, _ := r.Read(p)
		fmt.Println("reader:", n, string(p), l.Len())
	}
	_, ok := l.(fmt.Stringer)
	fmt.Println("stringer:", ok)
	var a any = l
	_, ok = a.(*bytes.Buffer)
	fmt.Println(ok, l == l, l == l2, l != nil, a == any(b), ws[0] == l)
	switch v := l.(type) {
	case *bytes.Buffer:
		fmt.Println("switch:", v.Len())
	default:
		fmt.Println("switch: outro")
	}
	var nl LW
	fmt.Println(nl == nil)
	var pb *bytes.Buffer
	nl = pb
	fmt.Println(nl == nil, nl != nil)
	fmt.Printf("%T\n", nl)
	fmt.Println(reflect.TypeOf(l), reflect.ValueOf(l).Elem().Type())
}

func udp() {
	nw := &Net{}
	srv, err := nw.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		fmt.Println("listen:", err)
		return
	}
	defer srv.Close()
	cli, err := nw.DialUDP("udp4", nil, srv.LocalAddr().(*net.UDPAddr))
	if err != nil {
		fmt.Println("dial:", err)
		return
	}
	fmt.Printf("%T %T\n", srv, cli)
	srv.SetReadDeadline(time.Now().Add(5 * time.Second))
	cli.SetReadDeadline(time.Now().Add(5 * time.Second))
	if _, err := cli.Write([]byte("ping")); err != nil {
		fmt.Println("write:", err)
	}
	buf := make([]byte, 64)
	n, addr, err := srv.ReadFromUDP(buf)
	fmt.Println("srv:", string(buf[:n]), addr.Port == cli.LocalAddr().(*net.UDPAddr).Port, err)
	srv.WriteToUDP([]byte("pong"), addr)
	n, err = cli.Read(buf)
	fmt.Println("cli:", string(buf[:n]), err)
	srv.WriteTo([]byte("pang"), addr)
	n, from, err := cli.ReadFrom(buf)
	fmt.Println("cli:", string(buf[:n]), from.String() == srv.LocalAddr().String(), err)
	uc, ok := srv.(*net.UDPConn)
	fmt.Println("assert:", ok, uc.LocalAddr().String() == srv.LocalAddr().String())
	c := any(cli).(io.Closer)
	fmt.Println(c.Close(), cli.Close() != nil)
	bad, err := nw.ListenUDP("bogus", nil)
	fmt.Println(bad != nil, err)
}

func main() {
	lw()
	udp()
}
