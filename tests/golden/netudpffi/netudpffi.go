// UDP da VM no linux pela rede FFI (plano D10, etapa E7): o socket nasce na
// ordem do Go (SO_BROADCAST e o Control antes do bind), DialUDP conecta de
// verdade, SyscallConn dá o fd real (opções, RawConn.Read/Write com
// syscall.Read/Write) e ReadMsgUDP/WriteMsgUDP levam dados de controle
// (IP_RECVTOS, IP_TOS por mensagem) e as flags do recvmsg (MSG_TRUNC).
//
// No Node (F4/F5, netudpffi.node.out) não há fd: o Control da escuta é
// ignorado, discar com Control falha com "socket: operation not
// supported", as opções dão "protocol not available", o RawConn.Read/Write
// e a escrita com oob dão "operation not supported", e a leitura volta sem
// dados de controle. Quando a plataforma não tem isso, o fixture imprime o
// erro da opção (ou notRun) no lugar, para a linha ser a falha prevista.
package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"net"
	"strings"
	"syscall"
)

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

var notRun = syscall.ENOTSUP.Error()

func main() {
	ctx := context.Background()

	// ListenConfig.Control em UDP: SO_BROADCAST já ligado quando ele roda.
	info := notRun
	lc := net.ListenConfig{Control: func(network, address string, c syscall.RawConn) error {
		var bc, typ int
		var e1, e2 error
		cerr := c.Control(func(fd uintptr) {
			bc, e1 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_BROADCAST)
			typ, e2 = syscall.GetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_TYPE)
		})
		info = fmt.Sprint(network, " ", address, " broadcast=", bc, " type=", typ, " ", e1, " ", e2, " ", cerr)
		return nil
	}}
	pc, err := lc.ListenPacket(ctx, "udp", "127.0.0.1:0")
	show("listen", err)
	fmt.Println("listen control:", info)
	srv := pc.(*net.UDPConn)
	label(srv.LocalAddr().String(), "SRV")

	// Cliente conectado.
	cl, err := net.DialUDP("udp", nil, srv.LocalAddr().(*net.UDPAddr))
	show("dial", err)
	label(cl.LocalAddr().String(), "CL")
	fmt.Println("dial remote:", clean(cl.RemoteAddr().String()))

	// SyscallConn com fd real: IP_RECVTOS no servidor, IP_TOS no cliente.
	sraw, err := srv.SyscallConn()
	show("syscallconn", err)
	var recvtos error
	sraw.Control(func(fd uintptr) {
		recvtos = syscall.SetsockoptInt(int(fd), syscall.IPPROTO_IP, syscall.IP_RECVTOS, 1)
	})
	show("recvtos", recvtos)
	craw, _ := cl.SyscallConn()
	var tos int
	var e1, e2 error
	craw.Control(func(fd uintptr) {
		e1 = syscall.SetsockoptInt(int(fd), syscall.IPPROTO_IP, syscall.IP_TOS, 0x28)
		tos, e2 = syscall.GetsockoptInt(int(fd), syscall.IPPROTO_IP, syscall.IP_TOS)
	})
	fmt.Println("tos:", tos, e1, e2)

	// ReadMsgUDP: o TOS chega num cmsg (IPPROTO_IP, IP_TOS).
	cl.Write([]byte("com tos"))
	buf := make([]byte, 64)
	oob := make([]byte, 64)
	n, oobn, flags, from, err := srv.ReadMsgUDP(buf, oob)
	fmt.Println("readmsg:", string(buf[:n]), flags, from.Port == cl.LocalAddr().(*net.UDPAddr).Port, err)
	if recvtos != nil {
		fmt.Println("oob:", recvtos)
	} else {
		fmt.Printf("oob: %d %x\n", oobn, oob[:oobn])
	}

	// Datagrama maior que o buffer: MSG_TRUNC nas flags.
	cl.Write([]byte("0123456789"))
	small := make([]byte, 4)
	n, _, flags, _, err = srv.ReadMsgUDP(small, oob)
	fmt.Println("truncated:", string(small[:n]), n, err)
	if recvtos != nil {
		fmt.Println("msg_trunc:", recvtos)
	} else {
		fmt.Println("msg_trunc:", flags&syscall.MSG_TRUNC != 0)
	}

	// WriteMsgUDP com IP_TOS por mensagem (cmsghdr de 24 bytes no amd64).
	cm := make([]byte, 24)
	binary.LittleEndian.PutUint64(cm[0:], 17)
	binary.LittleEndian.PutUint32(cm[8:], syscall.IPPROTO_IP)
	binary.LittleEndian.PutUint32(cm[12:], syscall.IP_TOS)
	cm[16] = 0x48
	n, oobn, err = cl.WriteMsgUDP([]byte("tos por mensagem"), cm, nil)
	fmt.Println("writemsg:", n, oobn, func() string {
		if err != nil {
			return clean(err.Error())
		}
		return "<nil>"
	}())
	if err == nil {
		n, oobn, _, _, err = srv.ReadMsgUDP(buf, oob)
		if recvtos != nil {
			fmt.Println("readmsg tos:", string(buf[:n]), recvtos)
		} else {
			fmt.Printf("readmsg tos: %s %x %v\n", buf[:n], oob[:oobn], err)
		}
	} else {
		show("readmsg tos", err)
	}

	// Erros de destino.
	_, err = cl.WriteToUDP([]byte("x"), srv.LocalAddr().(*net.UDPAddr))
	show("writeto connected", err)
	_, _, err = cl.WriteMsgUDP([]byte("x"), nil, srv.LocalAddr().(*net.UDPAddr))
	show("writemsg connected", err)
	_, _, err = srv.WriteMsgUDP([]byte("x"), nil, nil)
	show("writemsg sem destino", err)

	// Resposta do servidor (sem oob) e leitura do cliente conectado.
	_, _, err = srv.WriteMsgUDP([]byte("resposta"), nil, from)
	show("writemsg resposta", err)
	n, err = cl.Read(buf)
	fmt.Println("client read:", string(buf[:n]), err)

	// RawConn.Write/Read com syscall.Write/Read no fd real.
	var werr error
	err = craw.Write(func(fd uintptr) bool {
		_, werr = syscall.Write(int(fd), []byte("cru"))
		return werr != syscall.EAGAIN
	})
	fmt.Println("raw write:", werr, func() string {
		if err != nil {
			return clean(err.Error())
		}
		return "<nil>"
	}())
	var rn int
	var rerr error
	if err == nil {
		err = sraw.Read(func(fd uintptr) bool {
			rn, rerr = syscall.Read(int(fd), buf)
			return rerr != syscall.EAGAIN
		})
	}
	fmt.Println("raw read:", string(buf[:max(rn, 0)]), rerr, func() string {
		if err != nil {
			return clean(err.Error())
		}
		return "<nil>"
	}())

	// Dialer.Control em UDP: a rede com a família.
	dinfo := notRun
	d := net.Dialer{Control: func(network, address string, c syscall.RawConn) error {
		dinfo = network + " " + clean(address)
		return nil
	}}
	c2, err := d.Dial("udp", srv.LocalAddr().String())
	show("dial control", err)
	fmt.Println("dial control info:", dinfo)
	if c2 != nil {
		c2.Close()
	}

	// Escuta sem host: a família sai da pilha do processo (udp4 sem IPv6).
	anyInfo := notRun
	lc2 := net.ListenConfig{Control: func(network, address string, c syscall.RawConn) error {
		anyInfo = network + " " + address
		return nil
	}}
	p2, err := lc2.ListenPacket(ctx, "udp", ":0")
	show("listen any", err)
	fmt.Println("listen any control:", anyInfo)
	p2.Close()

	cl.Close()
	srv.Close()
	show("raw-control after close", sraw.Control(func(uintptr) {}))
}
