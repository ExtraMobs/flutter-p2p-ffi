// Dialer.Control/ControlContext, ListenConfig.Control e SyscallConn no shim
// net (plano D10, etapa E2): na VM o socket é montado pela rede FFI na ordem
// do Go (SO_REUSEADDR antes do Control na escuta; o Control antes do
// connect), a conexão discada vai para o dart:io pela ponte e o listener com
// Control fica no FFI. O erro do Control volta sem embrulho no OpError.
//
// No Node (F4/F5, netcontrol.node.out) discar com Control falha com
// "socket: operation not supported", escutar ignora o Control e as opções de
// socket dão "protocol not available". Quando o Control não roda, o
// fixture imprime o mesmo "operation not supported" (notRun), para a linha
// ser a falha prevista e não outra coisa.
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strings"
	"syscall"
)

type ctxKey struct{}

// Endereços com porta aleatória → rótulos estáveis.
var labels [][2]string

func label(real, name string) { labels = append(labels, [2]string{real, name}) }

func clean(s string) string {
	for i := len(labels) - 1; i >= 0; i-- {
		s = strings.ReplaceAll(s, labels[i][0], labels[i][1])
	}
	return s
}

func show(name string, err error) {
	if err == nil {
		fmt.Println(name+":", "<nil>")
		return
	}
	fmt.Println(name+":", clean(err.Error()))
}

// O Control não rodou (Node: a escuta ignora o Control e a discagem falha
// antes dele).
var notRun = syscall.ENOTSUP.Error()

// echo manda o rótulo e imprime a resposta do servidor.
func echo(name string, c net.Conn, err error) {
	if err != nil {
		show(name, err)
		return
	}
	c.Write([]byte(name))
	buf := make([]byte, 64)
	n, err := c.Read(buf)
	fmt.Println(name+":", string(buf[:n]), err)
}

func serve(ln net.Listener) {
	for {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		go func(c net.Conn) {
			buf := make([]byte, 64)
			n, _ := c.Read(buf)
			c.Write(append([]byte("eco:"), buf[:n]...))
			c.Close()
		}(c)
	}
}

func main() {
	ctx := context.Background()

	// ListenConfig.Control: o SO_REUSEADDR já está ligado quando ele roda.
	lnInfo := notRun
	lc := net.ListenConfig{Control: func(network, address string, c syscall.RawConn) error {
		var reuse, typ int
		var e1, e2 error
		err := c.Control(func(fd uintptr) {
			reuse, e1 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_REUSEADDR)
			typ, e2 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_TYPE)
		})
		lnInfo = fmt.Sprint(network, " ", address, " reuseaddr=", reuse, " type=", typ, " ", e1, " ", e2, " ", err)
		return nil
	}}
	ln, err := lc.Listen(ctx, "tcp", "127.0.0.1:0")
	show("listen", err)
	fmt.Println("listen control:", lnInfo)
	label(ln.Addr().String(), "LN")
	go serve(ln)

	// Dialer.Control: a rede com a família e o endereço do destino.
	dialInfo := notRun
	d := net.Dialer{Control: func(network, address string, c syscall.RawConn) error {
		var typ int
		var e error
		cerr := c.Control(func(fd uintptr) {
			typ, e = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_TYPE)
		})
		dialInfo = fmt.Sprint(network, " ", clean(address), " type=", typ, " ", e, " ", cerr)
		return nil
	}}
	c, err := d.DialContext(ctx, "tcp", ln.Addr().String())
	fmt.Println("dial control:", func() string {
		if err != nil {
			return clean(err.Error())
		}
		return "ok"
	}())
	fmt.Println("dial info:", dialInfo)

	// SyscallConn da conexão discada com Control: TCP_NODELAY ligado como no
	// newTCPConn do Go.
	if err == nil {
		raw, rerr := c.(*net.TCPConn).SyscallConn()
		var nd int
		var e error
		cerr := raw.Control(func(fd uintptr) {
			nd, e = syscall.GetsockoptInt(int(fd), syscall.IPPROTO_TCP, syscall.TCP_NODELAY)
		})
		fmt.Println("syscallconn:", nd, e, cerr, rerr)
	} else {
		show("syscallconn", err)
	}
	echo("echo control", c, err)

	// SyscallConn de uma conexão sem Control (no Node também existe; as
	// opções é que dão ENOPROTOOPT).
	p, err := net.Dial("tcp", ln.Addr().String())
	show("plain dial", err)
	label(p.LocalAddr().String(), "LOCAL")
	raw, err := p.(*net.TCPConn).SyscallConn()
	show("plain syscallconn", err)
	var ka, typ int
	var e1, e2, e3 error
	cerr := raw.Control(func(fd uintptr) {
		e1 = syscall.SetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_KEEPALIVE, 0)
		ka, e2 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_KEEPALIVE)
		typ, e3 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_TYPE)
	})
	fmt.Println("plain options:", ka, typ, e1, e2, e3, cerr)
	echo("echo plain", p, nil)
	p.Close()
	show("raw-control after close", raw.Control(func(uintptr) {}))

	// O erro do Control volta como está.
	errBoom := errors.New("control recusou")
	d2 := net.Dialer{Control: func(string, string, syscall.RawConn) error { return errBoom }}
	_, err = d2.Dial("tcp", ln.Addr().String())
	var oe *net.OpError
	fmt.Println("control error:", clean(err.Error()), errors.Is(err, errBoom) && errors.As(err, &oe) && oe.Err == errBoom)

	// ControlContext vence Control e recebe o ctx do DialContext.
	cctx := context.WithValue(ctx, ctxKey{}, "valor do ctx")
	ccInfo := notRun
	d3 := net.Dialer{
		Control: func(string, string, syscall.RawConn) error {
			ccInfo = "Control"
			return nil
		},
		ControlContext: func(ctx context.Context, network, address string, c syscall.RawConn) error {
			ccInfo = fmt.Sprint("ControlContext ", ctx.Value(ctxKey{}), " ", network)
			return nil
		},
	}
	c3, err := d3.DialContext(cctx, "tcp4", ln.Addr().String())
	echo("echo ctx", c3, err)
	fmt.Println("control context:", ccInfo)

	// Origem fixa (bind depois do Control) e destino recusado.
	d4 := net.Dialer{LocalAddr: &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)}, Control: d.Control}
	c4, err := d4.Dial("tcp", ln.Addr().String())
	if err == nil {
		fmt.Println("local addr:", c4.LocalAddr().(*net.TCPAddr).IP)
		c4.Close()
	} else {
		show("local addr", err)
	}
	_, err = d.Dial("tcp", "127.0.0.1:1")
	show("refused", err)

	// Erro do Control na escuta (o Node ignora o Control: notRun).
	lc2 := net.ListenConfig{Control: func(string, string, syscall.RawConn) error { return errBoom }}
	ln2, err := lc2.Listen(ctx, "tcp", "127.0.0.1:0")
	if err == nil {
		ln2.Close()
		err = syscall.ENOTSUP
	}
	show("listen control error", err)

	// Escuta sem host: a família sai da pilha do processo (tcp4 sem IPv6).
	anyInfo := notRun
	lc3 := net.ListenConfig{Control: func(network, address string, c syscall.RawConn) error {
		anyInfo = network + " " + address
		return nil
	}}
	ln3, err := lc3.Listen(ctx, "tcp", ":0")
	show("listen any", err)
	fmt.Println("listen any control:", anyInfo)
	ln3.Close()

	// SyscallConn do listener: Read/Write dão EINVAL (rawListener).
	lraw, err := ln.(*net.TCPListener).SyscallConn()
	show("listener syscallconn", err)
	show("listener raw read", lraw.Read(func(uintptr) bool { return true }))
	ln.Close()
	show("listener raw-control after close", lraw.Control(func(uintptr) {}))
}
