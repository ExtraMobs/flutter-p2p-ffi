// Sockets Unix de seqpacket (unixpacket) no shim net, pela rede FFI da VM
// (etapa E4): fronteira de mensagem preservada (com o excesso descartado),
// mensagem vazia lida como EOF (o ZeroReadIsEOF do Go) e embrulhada num
// *OpError pelo ReadFrom, endereços dos dois lados, WriteTo, mensagem
// grande demais, CloseWrite, Close do par, prazo, Accept com prazo e os
// erros de dial/listen.
//
// Cada linha é "rótulo: resultado". No Node não há unixpacket (F4): a
// linha vira o erro "operation not supported" da operação que abre o
// socket (regra F5, netunixpacket.node.out). Os nomes são abstratos, com o
// pid; o texto troca o prefixo por @SOCK.
package main

import (
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"
)

var abs = fmt.Sprintf("@g2d-netunixpacket-%d", os.Getpid())

func er(err error) string {
	if err == nil {
		return "<nil>"
	}
	return strings.ReplaceAll(err.Error(), abs, "@SOCK")
}

func ad(a net.Addr) string {
	if a == nil {
		return "<nil>"
	}
	if u, ok := a.(*net.UnixAddr); ok && u == nil {
		return "nil"
	}
	return a.Network() + " " + strings.ReplaceAll(a.String(), abs, "@SOCK")
}

// par: listener, conexão discada e conexão aceita (por goroutine).
func par(name string) (*net.UnixListener, *net.UnixConn, *net.UnixConn, error) {
	ln, err := net.ListenUnix("unixpacket", &net.UnixAddr{Name: abs + name, Net: "unixpacket"})
	if err != nil {
		return nil, nil, nil, err
	}
	acc := make(chan *net.UnixConn, 1)
	go func() {
		c, _ := ln.AcceptUnix()
		acc <- c
	}()
	c, err := net.Dial("unixpacket", abs+name)
	if err != nil {
		ln.Close()
		return nil, nil, nil, err
	}
	return ln, c.(*net.UnixConn), <-acc, nil
}

func enderecos() string {
	ln, c, s, err := par("-a")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	return fmt.Sprintf("%T %v ; cli %v | %v ; aceito %v | %v", ln, ad(ln.Addr()), ad(c.LocalAddr()),
		ad(c.RemoteAddr()), ad(s.LocalAddr()), ad(s.RemoteAddr()))
}

func mensagens() string {
	ln, c, s, err := par("-b")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	c.Write([]byte("abc"))
	c.Write([]byte("defghijk"))
	b := make([]byte, 5)
	var out []string
	for i := 0; i < 2; i++ {
		n, err := s.Read(b)
		out = append(out, fmt.Sprintf("%q %v", b[:n], er(err)))
	}
	c.Write([]byte("xy"))
	n, from, err := s.ReadFromUnix(b)
	out = append(out, fmt.Sprintf("ReadFromUnix %q nil=%v %v", b[:n], from == nil, er(err)))
	s.Write([]byte("volta"))
	n, from, err = c.ReadFromUnix(b)
	out = append(out, fmt.Sprintf("cli %q de %v %v", b[:n], ad(from), er(err)))
	// io.ReadFull num seqpacket: cada Read é uma mensagem.
	c.Write([]byte("12"))
	c.Write([]byte("345"))
	full := make([]byte, 5)
	k, err := io.ReadFull(s, full)
	out = append(out, fmt.Sprintf("ReadFull %d %q %v", k, full, er(err)))
	return strings.Join(out, " | ")
}

// vazia: a mensagem de 0 bytes é EOF no Read e *OpError(EOF) no ReadFrom,
// e a conexão continua viva depois.
func vazia() string {
	ln, c, s, err := par("-c")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	n, werr := c.Write(nil)
	b := make([]byte, 4)
	k, rerr := s.Read(b)
	out := fmt.Sprintf("write %d %v; read %d %v eof=%v", n, er(werr), k, er(rerr), rerr == io.EOF)
	c.Write(nil)
	k, from, ferr := s.ReadFromUnix(b)
	out += fmt.Sprintf("; ReadFrom %d %v %v is=%v", k, ad(from), er(ferr), errors.Is(ferr, io.EOF))
	c.Write([]byte("ok"))
	k, rerr = s.Read(b)
	return out + fmt.Sprintf("; depois %q %v", b[:k], er(rerr))
}

func escrita() string {
	ln, c, s, err := par("-d")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer c.Close()
	defer s.Close()
	var out []string
	n, err := s.WriteToUnix([]byte("x"), &net.UnixAddr{Name: abs + "-d", Net: "unixpacket"})
	out = append(out, fmt.Sprintf("aceito WriteTo %d %v", n, er(err)))
	_, err = s.WriteToUnix([]byte("x"), &net.UnixAddr{Name: abs + "-d", Net: "unix"})
	out = append(out, er(err))
	_, err = c.WriteToUnix([]byte("x"), &net.UnixAddr{Name: abs + "-d", Net: "unixpacket"})
	out = append(out, er(err))
	n, err = c.Write(make([]byte, 1<<20))
	out = append(out, fmt.Sprintf("grande %d %v", n, er(err)))
	return strings.Join(out, " | ")
}

func fechamento() string {
	ln, c, s, err := par("-e")
	if err != nil {
		return er(err)
	}
	defer ln.Close()
	defer s.Close()
	b := make([]byte, 4)
	c.CloseWrite()
	n, err := s.Read(b)
	out := fmt.Sprintf("CloseWrite: %d %v", n, er(err))
	s.Write([]byte("ainda"))
	n, err = c.Read(b)
	out += fmt.Sprintf("; cli ainda lê %q %v", b[:n], er(err))
	c.Close()
	n, err = s.Read(b)
	out += fmt.Sprintf("; Close do par: %d %v", n, er(err))
	_, err = s.Write([]byte("z"))
	out += fmt.Sprintf("; write %v", er(err))
	s.SetReadDeadline(time.Now().Add(-time.Second))
	_, err = s.Read(b)
	return out + fmt.Sprintf("; prazo %v", er(err))
}

func listener() string {
	ln, err := net.ListenUnix("unixpacket", &net.UnixAddr{Name: abs + "-f", Net: "unixpacket"})
	if err != nil {
		return er(err)
	}
	var out []string
	ln.SetDeadline(time.Now().Add(20 * time.Millisecond))
	_, err = ln.Accept()
	out = append(out, fmt.Sprintf("accept %v timeout=%v", er(err), os.IsTimeout(err)))
	ln.SetDeadline(time.Time{})
	_, err = net.Listen("unixpacket", abs+"-f")
	out = append(out, er(err))
	_, err = net.Dial("unix", abs+"-f")
	out = append(out, er(err))
	res := make(chan string)
	go func() {
		_, err := ln.Accept()
		res <- fmt.Sprintf("pendente %v closed=%v", er(err), errors.Is(err, net.ErrClosed))
	}()
	time.Sleep(20 * time.Millisecond)
	out = append(out, fmt.Sprintf("close %v", er(ln.Close())), <-res)
	_, err = net.Dial("unixpacket", abs+"-f")
	out = append(out, er(err))
	return strings.Join(out, " | ")
}

func erros() string {
	var out []string
	_, err := net.Dial("unixpacket", abs+"-nada")
	out = append(out, er(err))
	_, err = net.ListenUnixgram("unixpacket", &net.UnixAddr{Name: abs + "-g", Net: "unixpacket"})
	out = append(out, er(err))
	_, err = net.ListenUnix("unixpacket", nil)
	out = append(out, er(err))
	_, err = net.DialUnix("unixpacket", nil, &net.UnixAddr{})
	out = append(out, er(err))
	return strings.Join(out, " | ")
}

// listenPacket: ListenPacket de seqpacket é um *UnixConn sobre o socket
// escutando.
func listenPacket() string {
	pc, err := net.ListenPacket("unixpacket", abs+"-h")
	if err != nil {
		return er(err)
	}
	defer pc.Close()
	_, _, err = pc.ReadFrom(make([]byte, 4))
	return fmt.Sprintf("%T %v; read %v", pc, ad(pc.LocalAddr()), er(err))
}

func main() {
	fmt.Println("endereços:", enderecos())
	fmt.Println("mensagens:", mensagens())
	fmt.Println("vazia:", vazia())
	fmt.Println("escrita:", escrita())
	fmt.Println("fechamento:", fechamento())
	fmt.Println("listener:", listener())
	fmt.Println("erros:", erros())
	fmt.Println("ListenPacket:", listenPacket())
	fmt.Println("fim")
}
