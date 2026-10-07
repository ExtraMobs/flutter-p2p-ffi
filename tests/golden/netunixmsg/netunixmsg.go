// Extras de sockets Unix no shim net (etapa E5 da rede FFI):
// SetUnlinkOnClose(false), autobind (Listen("unix", "")), DialUnix com
// laddr nomeado, ReadMsgUnix/WriteMsgUnix com dados de controle
// (SCM_RIGHTS, byte fictício, MSG_CTRUNC/MSG_TRUNC, MSG_CMSG_CLOEXEC nas
// flags) e as funções do syscall UnixRights, ParseSocketControlMessage,
// ParseUnixRights, CmsgLen e CmsgSpace.
//
// Cada linha é "rótulo: resultado". No Node (F4/F5, netunixmsg.node.out)
// o autobind e o SetUnlinkOnClose(false) são emulados; laddr nomeado,
// dados de controle e unixgram dão "operation not supported". Os nomes têm
// o pid (o texto troca o prefixo por SOCK); sem o pacote os de arquivos no
// shim, a existência do arquivo é vista pelo connect, e o arquivo do
// SetUnlinkOnClose(false) fica em /tmp.
package main

import (
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"syscall"
)

var (
	base = fmt.Sprintf("/tmp/g2d-netunixmsg-%d", os.Getpid())
	abs  = fmt.Sprintf("@g2d-netunixmsg-%d", os.Getpid())
)

func clean(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, base, "SOCK"), abs, "@SOCK")
}

func er(err error) string {
	if err == nil {
		return "<nil>"
	}
	return clean(err.Error())
}

func ad(a net.Addr) string {
	if a == nil {
		return "<nil>"
	}
	if u, ok := a.(*net.UnixAddr); ok && u == nil {
		return "nil"
	}
	return a.Network() + " " + clean(a.String())
}

func ua(name, network string) *net.UnixAddr {
	return &net.UnixAddr{Name: name, Net: network}
}

// par: listener de fluxo em name, conexão discada (com laddr opcional) e a
// aceita.
func par(name string, laddr *net.UnixAddr) (*net.UnixListener, *net.UnixConn, *net.UnixConn, error) {
	ln, err := net.ListenUnix("unix", ua(name, "unix"))
	if err != nil {
		return nil, nil, nil, err
	}
	acc := make(chan *net.UnixConn, 1)
	go func() {
		c, _ := ln.AcceptUnix()
		acc <- c
	}()
	c, err := net.DialUnix("unix", laddr, ua(name, "unix"))
	if err != nil {
		ln.Close()
		return nil, nil, nil, err
	}
	return ln, c, <-acc, nil
}

func unlink() string {
	keep, gone := base+"-keep", base+"-gone"
	l1, err := net.ListenUnix("unix", ua(keep, "unix"))
	if err != nil {
		return er(err)
	}
	l1.SetUnlinkOnClose(false)
	out := fmt.Sprintf("close %v", er(l1.Close()))
	_, err = net.Dial("unix", keep)
	out += "; false: " + er(err)
	_, err = net.Listen("unix", keep)
	out += " | " + er(err)
	l2, err := net.ListenUnix("unix", ua(gone, "unix"))
	if err != nil {
		return er(err)
	}
	l2.SetUnlinkOnClose(false)
	l2.SetUnlinkOnClose(true)
	l2.Close()
	_, err = net.Dial("unix", gone)
	return out + "; true: " + er(err)
}

func autobind() string {
	ln, err := net.Listen("unix", "")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	name := ln.Addr().String()
	acc := make(chan string, 1)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			acc <- er(err)
			return
		}
		b := make([]byte, 2)
		io.ReadFull(c, b)
		c.Write(b)
		acc <- fmt.Sprintf("aceito %q remoto %v", b, ad(c.RemoteAddr()))
		c.Close()
	}()
	c, err := net.Dial("unix", name)
	if err != nil {
		return er(err)
	}
	defer c.Close()
	c.Write([]byte("oi"))
	b := make([]byte, 2)
	io.ReadFull(c, b)
	return fmt.Sprintf("nome %d %q %s; %s; volta %q", len(name), name[:1], ln.Addr().Network(), <-acc, b)
}

func laddr() string {
	ln, c, s, err := par(abs+"-b", ua(abs+"-c", "unix"))
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	out := fmt.Sprintf("cli %v | %v ; aceito %v | %v", ad(c.LocalAddr()), ad(c.RemoteAddr()),
		ad(s.LocalAddr()), ad(s.RemoteAddr()))
	c.Write([]byte("x"))
	b := make([]byte, 4)
	n, from, err := s.ReadFromUnix(b)
	out += fmt.Sprintf("; ReadFrom %q de %v %v", b[:n], ad(from), er(err))
	_, err = net.DialUnix("unix", ua(abs+"-c", "unix"), ua(abs+"-b", "unix"))
	return out + "; ocupado: " + er(err)
}

func rights() string {
	r := syscall.UnixRights(1, 2)
	msgs, err := syscall.ParseSocketControlMessage(r)
	if err != nil {
		return er(err)
	}
	m := msgs[0]
	fds, err := syscall.ParseUnixRights(&m)
	return fmt.Sprintf("%d %v; %d msg: len=%d level=%d type=%d data=%v; fds %v %v",
		len(r), r, len(msgs), m.Header.Len, m.Header.Level, m.Header.Type, m.Data, fds, er(err))
}

func parse() string {
	var out []string
	_, err := syscall.ParseSocketControlMessage([]byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16})
	out = append(out, er(err))
	m0, err := syscall.ParseSocketControlMessage(nil)
	out = append(out, fmt.Sprint(len(m0), m0 == nil, er(err)))
	two := append(syscall.UnixRights(7), syscall.UnixRights(8, 9, 10)...)
	ms, err := syscall.ParseSocketControlMessage(two)
	for _, m := range ms {
		fds, _ := syscall.ParseUnixRights(&m)
		out = append(out, fmt.Sprint(m.Header.Len, fds))
	}
	_, err = syscall.ParseUnixRights(&syscall.SocketControlMessage{})
	out = append(out, er(err))
	var h syscall.Cmsghdr
	h.SetLen(syscall.CmsgLen(4))
	h.Level = syscall.SOL_SOCKET
	h.Type = syscall.SCM_CREDENTIALS
	_, err = syscall.ParseUnixRights(&syscall.SocketControlMessage{Header: h, Data: []byte{1, 0, 0, 0}})
	out = append(out, fmt.Sprint(h.Len, er(err)))
	out = append(out, fmt.Sprint(syscall.CmsgLen(4), syscall.CmsgSpace(4), syscall.CmsgSpace(0), syscall.SizeofCmsghdr))
	return strings.Join(out, " | ")
}

func msgOob() string {
	ln, c, s, err := par(abs+"-d", nil)
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	n, oobn, err := c.WriteMsgUnix([]byte("dados"), syscall.UnixRights(1, 2), nil)
	if err != nil {
		return er(err)
	}
	out := fmt.Sprintf("write %d %d", n, oobn)
	b, oob := make([]byte, 8), make([]byte, 64)
	n, oobn, flags, from, err := s.ReadMsgUnix(b, oob)
	if err != nil {
		return er(err)
	}
	out += fmt.Sprintf("; read %d %q %d %#x %v", n, b[:n], oobn, flags, ad(from))
	msgs, err := syscall.ParseSocketControlMessage(oob[:oobn])
	fds, ferr := syscall.ParseUnixRights(&msgs[0])
	return out + fmt.Sprintf("; %d msg %v, %d fds novos=%v %v", len(msgs), er(err), len(fds),
		len(fds) == 2 && fds[0] > 2 && fds[1] > 2, er(ferr))
}

// soOob: sem dados, o fluxo manda e lê um byte fictício.
func soOob() string {
	ln, c, s, err := par(abs+"-e", ua(abs+"-f", "unix"))
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	n, oobn, err := c.WriteMsgUnix(nil, syscall.UnixRights(0), nil)
	if err != nil {
		return er(err)
	}
	out := fmt.Sprintf("write %d %d", n, oobn)
	oob := make([]byte, 64)
	n, oobn, flags, from, err := s.ReadMsgUnix(nil, oob)
	if err != nil {
		return er(err)
	}
	out += fmt.Sprintf("; read %d %d %#x %v", n, oobn, flags, ad(from))
	// Controle curto: MSG_CTRUNC.
	c.WriteMsgUnix([]byte("x"), syscall.UnixRights(1, 2), nil)
	b := make([]byte, 4)
	n, oobn, flags, _, err = s.ReadMsgUnix(b, oob[:20])
	return out + fmt.Sprintf("; curto %d %d %#x %v", n, oobn, flags, er(err))
}

// semOob: sem dados de controle, a mensagem é a leitura/escrita do fluxo.
func semOob() string {
	ln, c, s, err := par(abs+"-g", nil)
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	n, oobn, err := c.WriteMsgUnix([]byte("123456789"), nil, nil)
	out := fmt.Sprintf("write %d %d %v", n, oobn, er(err))
	b := make([]byte, 5)
	n, oobn, flags, from, err := s.ReadMsgUnix(b, nil)
	out += fmt.Sprintf("; read %q %d %#x %v %v", b[:n], oobn, flags, ad(from), er(err))
	rest := make([]byte, 4)
	io.ReadFull(s, rest)
	out += fmt.Sprintf("; resto %q", rest)
	var errs []string
	_, _, err = c.WriteMsgUnix([]byte("x"), nil, ua("y", "unixgram"))
	errs = append(errs, er(err))
	_, _, err = c.WriteMsgUnix([]byte("x"), nil, ua("y", "unix"))
	errs = append(errs, er(err))
	c.CloseWrite()
	_, _, _, _, err = s.ReadMsgUnix(b, nil)
	errs = append(errs, er(err))
	c.Close()
	_, _, err = c.WriteMsgUnix([]byte("x"), nil, nil)
	errs = append(errs, er(err))
	_, _, _, _, err = c.ReadMsgUnix(b, nil)
	errs = append(errs, er(err))
	return out + "; erros " + strings.Join(errs, " | ")
}

func gram() string {
	g1, err := net.ListenUnixgram("unixgram", ua(abs+"-h", "unixgram"))
	if err != nil {
		return er(err)
	}
	defer g1.Close()
	g2, err := net.ListenUnixgram("unixgram", ua(abs+"-i", "unixgram"))
	if err != nil {
		return er(err)
	}
	defer g2.Close()
	to := ua(abs+"-i", "unixgram")
	n, oobn, err := g1.WriteMsgUnix(nil, syscall.UnixRights(1), to)
	out := fmt.Sprintf("só oob %d %d %v", n, oobn, er(err))
	oob := make([]byte, 64)
	n, oobn, flags, from, err := g2.ReadMsgUnix(nil, oob)
	out += fmt.Sprintf("; read %d %d %#x %v %v", n, oobn, flags, ad(from), er(err))
	g1.WriteMsgUnix([]byte("abcdef"), nil, to)
	b := make([]byte, 3)
	n, oobn, flags, from, err = g2.ReadMsgUnix(b, nil)
	out += fmt.Sprintf("; truncado %q %d %#x %v %v", b[:n], oobn, flags, ad(from), er(err))
	_, _, err = g1.WriteMsgUnix([]byte("x"), nil, nil)
	out += "; sem destino " + er(err)
	d, err := net.DialUnix("unixgram", nil, to)
	if err != nil {
		return out + "; " + er(err)
	}
	defer d.Close()
	_, _, err = d.WriteMsgUnix([]byte("x"), nil, nil)
	return out + "; conectado " + er(err)
}

func main() {
	fmt.Println("unlink:", unlink())
	fmt.Println("autobind:", autobind())
	fmt.Println("laddr:", laddr())
	fmt.Println("rights:", rights())
	fmt.Println("parse:", parse())
	fmt.Println("oob:", msgOob())
	fmt.Println("só oob:", soOob())
	fmt.Println("sem oob:", semOob())
	fmt.Println("unixgram:", gram())
	fmt.Println("fim")
}
