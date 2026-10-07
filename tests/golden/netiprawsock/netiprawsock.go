// IP bruto no shim net, pela rede FFI da VM (etapa E6): ListenPacket e
// DialIP de ip4:icmp no loopback, eco ICMP (o ReadFrom tira o cabeçalho
// IPv4, o Read não), endereços, os erros do sendto e do bind, prazo e
// Close.
//
// Cada linha é "rótulo: resultado". O socket bruto exige privilégio: sem
// ele, o Go (e a VM) dão "socket: operation not permitted" em cada linha;
// no Node não há IP bruto (F4) e a linha é "socket: operation not
// supported" (regra F5, netiprawsock.node.out). Só pacotes ICMP de eco com
// o identificador deste processo são considerados (o loopback pode ter
// outro tráfego ICMP).
package main

import (
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

var ident = os.Getpid() & 0xffff

func er(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func ad(a net.Addr) string {
	if a == nil {
		return "<nil>"
	}
	if u, ok := a.(*net.IPAddr); ok && u == nil {
		return "nil"
	}
	return a.Network() + " " + a.String()
}

var lo = &net.IPAddr{IP: net.IPv4(127, 0, 0, 1)}

// echo: pedido de eco ICMP com o identificador do processo.
func echo(seq int, payload string) []byte {
	m := []byte{8, 0, 0, 0, byte(ident >> 8), byte(ident), byte(seq >> 8), byte(seq)}
	m = append(m, payload...)
	var s uint32
	for i := 0; i+1 < len(m); i += 2 {
		s += uint32(m[i])<<8 | uint32(m[i+1])
	}
	if len(m)%2 == 1 {
		s += uint32(m[len(m)-1]) << 8
	}
	for s>>16 != 0 {
		s = s&0xffff + s>>16
	}
	m[2], m[3] = byte(^s>>8), byte(^s)
	return m
}

// mine: a mensagem ICMP é uma resposta de eco deste processo.
func mine(m []byte) bool {
	return len(m) >= 8 && m[0] == 0 && int(m[4])<<8|int(m[5]) == ident
}

func eco() string {
	c, err := net.ListenPacket("ip4:icmp", "127.0.0.1")
	if err != nil {
		return er(err)
	}
	defer c.Close()
	ic := c.(*net.IPConn)
	out := fmt.Sprintf("%T %v | %v", c, ad(c.LocalAddr()), ad(ic.RemoteAddr()))
	n, err := c.WriteTo(echo(1, "g2d"), lo)
	out += fmt.Sprintf("; write %d %v", n, er(err))
	c.SetReadDeadline(time.Now().Add(3 * time.Second))
	b := make([]byte, 128)
	for {
		n, from, err := c.ReadFrom(b)
		if err != nil {
			return out + "; " + er(err)
		}
		if mine(b[:n]) {
			return out + fmt.Sprintf("; resposta de %v: %d bytes seq=%d %q", ad(from), n, int(b[6])<<8|int(b[7]), b[8:n])
		}
	}
}

// dial: o Read de um IPConn conectado traz o cabeçalho IPv4.
func dial() string {
	c, err := net.DialIP("ip4:icmp", nil, lo)
	if err != nil {
		return er(err)
	}
	defer c.Close()
	out := fmt.Sprintf("%v | %v", ad(c.LocalAddr()), ad(c.RemoteAddr()))
	n, err := c.Write(echo(2, "dial"))
	out += fmt.Sprintf("; write %d %v", n, er(err))
	c.SetReadDeadline(time.Now().Add(3 * time.Second))
	b := make([]byte, 128)
	for {
		n, err := c.Read(b)
		if err != nil {
			return out + "; " + er(err)
		}
		if n >= 20 && mine(b[20:n]) {
			return out + fmt.Sprintf("; read %d bytes, versão %d, protocolo %d, %q", n, b[0]>>4, b[9], b[28:n])
		}
	}
}

func erros() string {
	c, err := net.ListenIP("ip4:icmp", &net.IPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		return er(err)
	}
	defer c.Close()
	var out []string
	_, err = c.Write([]byte{1})
	out = append(out, er(err))
	_, err = c.WriteToIP([]byte{1}, &net.IPAddr{IP: net.ParseIP("2001:db8::1")})
	out = append(out, er(err))
	_, err = c.WriteToIP([]byte{1}, nil)
	out = append(out, er(err))
	_, err = c.WriteTo([]byte{1}, &net.TCPAddr{})
	out = append(out, er(err))
	d, err := net.DialIP("ip4:1", nil, lo)
	if err == nil {
		_, err = d.WriteToIP([]byte{1}, lo)
		out = append(out, er(err))
		_, _, err = d.WriteMsgIP([]byte{1}, nil, lo)
		out = append(out, er(err))
		d.Close()
	} else {
		out = append(out, er(err))
	}
	_, err = net.ListenIP("ip4:icmp", &net.IPAddr{IP: net.IPv4(192, 0, 2, 1)})
	out = append(out, er(err))
	_, err = net.ListenIP("ip4:icmp", &net.IPAddr{IP: net.ParseIP("2001:db8::1")})
	out = append(out, er(err))
	return strings.Join(out, " | ")
}

func fechar() string {
	c, err := net.ListenIP("ip4:255", nil)
	if err != nil {
		return er(err)
	}
	out := ad(c.LocalAddr())
	c.SetReadDeadline(time.Now().Add(20 * time.Millisecond))
	_, _, err = c.ReadFromIP(make([]byte, 64))
	out += fmt.Sprintf("; prazo %v %v", er(err), os.IsTimeout(err))
	res := make(chan string)
	c.SetReadDeadline(time.Time{})
	go func() {
		_, _, err := c.ReadFrom(make([]byte, 64))
		res <- er(err)
	}()
	time.Sleep(20 * time.Millisecond)
	out += fmt.Sprintf("; close %v; pendente %v", er(c.Close()), <-res)
	_, err = c.Write([]byte{1})
	out += fmt.Sprintf("; write %v; close %v", er(err), er(c.Close()))
	return out
}

func main() {
	fmt.Println("eco:", eco())
	fmt.Println("dial:", dial())
	fmt.Println("erros:", erros())
	fmt.Println("fechar:", fechar())
	fmt.Println("fim")
}
