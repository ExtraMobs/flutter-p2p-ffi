// Control e SyscallConn nos sockets Unix e no IP bruto (plano D10,
// integração do E2 com o E3–E6): na VM no linux eles nascem no socket()
// do Go do shim, com o Control antes do bind (escuta, SO_REUSEADDR já
// ligado no fluxo e no seqpacket) ou antes do connect (discagem), e o
// SyscallConn de UnixConn, UnixListener e IPConn dá o fd real.
//
// No Node (F4/F5, netunixcontrol.node.out) discar com Control falha com
// "socket: operation not supported", escutar ignora o Control, unixgram,
// unixpacket e IP bruto não existem e as opções de socket dão "protocol not
// available". Quando o Control não roda, o fixture imprime o mesmo
// "operation not supported" (notRun), para a linha ser a falha prevista.
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"syscall"
)

type ctxKey struct{}

var base = fmt.Sprintf("@g2d-unixcontrol-%d", os.Getpid())

func name(s string) string { return base + "-" + s }

func clean(s string) string { return strings.ReplaceAll(s, base, "@N") }

func show(label string, err error) {
	if err == nil {
		fmt.Println(label+":", "<nil>")
		return
	}
	fmt.Println(label+":", clean(err.Error()))
}

var notRun = syscall.ENOTSUP.Error()

// skip imprime as linhas de um passo que não pôde rodar (Node), com o
// mesmo "operation not supported", para a saída ter as mesmas linhas.
func skip(labels ...string) {
	for _, l := range labels {
		fmt.Println(l+":", notRun)
	}
}

// opt lê uma opção de socket pelo RawConn.Control.
func opt(c syscall.RawConn, level, o int) string {
	var v int
	var err error
	if cerr := c.Control(func(fd uintptr) { v, err = syscall.GetsockoptInt(int(fd), level, o) }); cerr != nil {
		return clean(cerr.Error())
	}
	if err != nil {
		return err.Error()
	}
	return fmt.Sprint(v)
}

// ctl é um Control que guarda o que viu: a rede, o endereço e o SO_TYPE e
// o SO_REUSEADDR do socket.
func ctl(info *string, fail error) func(string, string, syscall.RawConn) error {
	return func(network, address string, c syscall.RawConn) error {
		*info = fmt.Sprintf("%s %s type=%s reuse=%s", network, clean(address),
			opt(c, syscall.SOL_SOCKET, syscall.SO_TYPE),
			opt(c, syscall.SOL_SOCKET, syscall.SO_REUSEADDR))
		return fail
	}
}

func main() {
	ctx := context.Background()

	// ListenConfig.Control em unix: SO_REUSEADDR já ligado.
	lnInfo := notRun
	lc := net.ListenConfig{Control: ctl(&lnInfo, nil)}
	ln, err := lc.Listen(ctx, "unix", name("s"))
	show("listen unix", err)
	fmt.Println("listen unix control:", lnInfo)
	if err == nil {
		go func() {
			for {
				c, err := ln.Accept()
				if err != nil {
					return
				}
				buf := make([]byte, 16)
				n, _ := c.Read(buf)
				c.Write(append([]byte("eco:"), buf[:n]...))
				c.Close()
			}
		}()
	}

	// Dialer.Control em unix: rede e endereço do Go, antes do connect.
	dInfo := notRun
	d := net.Dialer{Control: ctl(&dInfo, nil)}
	c, err := d.Dial("unix", name("s"))
	show("dial unix", err)
	fmt.Println("dial unix control:", dInfo)
	if err != nil {
		skip("unixconn syscallconn", "unixconn so_type", "raw write", "raw read", "unixconn raw-control after close")
	} else {
		uc := c.(*net.UnixConn)
		rc, err := uc.SyscallConn()
		show("unixconn syscallconn", err)
		if err == nil {
			fmt.Println("unixconn so_type:", opt(rc, syscall.SOL_SOCKET, syscall.SO_TYPE))
			var werr error
			err = rc.Write(func(fd uintptr) bool {
				_, werr = syscall.Write(int(fd), []byte("raw"))
				return werr != syscall.EAGAIN
			})
			fmt.Println("raw write:", err, werr)
			buf := make([]byte, 16)
			var n int
			var rerr error
			err = rc.Read(func(fd uintptr) bool {
				n, rerr = syscall.Read(int(fd), buf)
				return rerr != syscall.EAGAIN
			})
			fmt.Println("raw read:", err, rerr, string(buf[:max(n, 0)]))
		}
		c.Close()
		if err == nil {
			show("unixconn raw-control after close", rc.Control(func(uintptr) {}))
		}
	}

	// Erro do Control: sem embrulho, socket fechado.
	_, err = (&net.Dialer{Control: ctl(new(string), errors.New("recusado"))}).Dial("unix", name("s"))
	show("dial control error", err)

	// ControlContext em unixgram: recebe o ctx.
	gInfo := notRun
	ctxv := context.WithValue(ctx, ctxKey{}, "v")
	srv, err := net.ListenPacket("unixgram", name("g"))
	show("listen unixgram", err)
	dc := net.Dialer{ControlContext: func(ctx context.Context, network, address string, c syscall.RawConn) error {
		gInfo = fmt.Sprintf("%s %s ctx=%v type=%s", network, clean(address), ctx.Value(ctxKey{}),
			opt(c, syscall.SOL_SOCKET, syscall.SO_TYPE))
		return nil
	}}
	gc, err := dc.DialContext(ctxv, "unixgram", name("g"))
	show("dial unixgram", err)
	fmt.Println("dial unixgram control:", gInfo)
	if err != nil {
		skip("unixgram read")
	} else {
		gc.Write([]byte("dg"))
		buf := make([]byte, 8)
		n, _, err := srv.ReadFrom(buf)
		fmt.Println("unixgram read:", string(buf[:n]), err)
		gc.Close()
	}
	if srv != nil {
		srv.Close()
	}

	// ListenConfig.Control em ListenPacket unixgram (sem SO_REUSEADDR) e em
	// unixpacket (com ele).
	pInfo := notRun
	pc, err := (&net.ListenConfig{Control: ctl(&pInfo, nil)}).ListenPacket(ctx, "unixgram", name("p"))
	show("listenpacket unixgram", err)
	fmt.Println("listenpacket unixgram control:", pInfo)
	if pc != nil {
		pc.Close()
	}
	sInfo := notRun
	sp, err := (&net.ListenConfig{Control: ctl(&sInfo, nil)}).Listen(ctx, "unixpacket", name("q"))
	show("listen unixpacket", err)
	fmt.Println("listen unixpacket control:", sInfo)
	if sp != nil {
		sp.Close()
	}
	_, err = (&net.ListenConfig{Control: ctl(new(string), errors.New("negado"))}).Listen(ctx, "unixpacket", name("r"))
	show("listen control error", err)

	// UnixListener.SyscallConn: o rawListener (Read/Write com EINVAL).
	if ln != nil {
		rc, err := ln.(*net.UnixListener).SyscallConn()
		show("listener syscallconn", err)
		if err == nil {
			fmt.Println("listener so_acceptconn:", opt(rc, syscall.SOL_SOCKET, syscall.SO_ACCEPTCONN))
			show("listener raw read", rc.Read(func(uintptr) bool { return true }))
		}
		ln.Close()
		if err == nil {
			show("listener raw-control after close", rc.Control(func(uintptr) {}))
		}
	}

	// IP bruto com Control e SyscallConn (sem privilégio, o EPERM do Go).
	iInfo := notRun
	ic, err := (&net.ListenConfig{Control: ctl(&iInfo, nil)}).ListenPacket(ctx, "ip4:icmp", "127.0.0.1")
	show("listen ip4:icmp", err)
	if err != nil {
		skip("listen ip4:icmp control", "ipconn syscallconn", "ipconn so_type")
	} else {
		fmt.Println("listen ip4:icmp control:", iInfo)
		rc, err := ic.(*net.IPConn).SyscallConn()
		show("ipconn syscallconn", err)
		if err == nil {
			fmt.Println("ipconn so_type:", opt(rc, syscall.SOL_SOCKET, syscall.SO_TYPE))
		}
		ic.Close()
	}
	_, err = new(net.IPConn).SyscallConn()
	show("zero ipconn syscallconn", err)
}
