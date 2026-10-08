// UDP conectado (DialUDP, Dial("udp")): o socket faz connect de verdade,
// então LocalAddr traz o IP de origem escolhido pelo kernel, o kernel só
// entrega o que vem do par, e o ECONNREFUSED do ICMP fica pendente no socket
// e sai na próxima operação, seja ela Read ("read: connection refused") ou
// Write ("write: connection refused"). Na VM no linux pela rede FFI; no Node
// pelo dgram.connect, com o evento "error" do ECONNREFUSED guardado para a
// próxima operação.
package main

import (
	"fmt"
	"net"
	"strings"
	"time"
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

func main() {
	srv, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	show("listen", err)
	label(srv.LocalAddr().String(), "SRV")

	c, err := net.DialUDP("udp", nil, srv.LocalAddr().(*net.UDPAddr))
	show("dial", err)
	la := c.LocalAddr().(*net.UDPAddr)
	label(la.String(), "CL")
	fmt.Println("local ip:", la.IP, la.Port > 0)
	fmt.Println("remote:", clean(c.RemoteAddr().String()))

	_, err = c.Write([]byte("oi"))
	show("write", err)
	buf := make([]byte, 64)
	n, from, err := srv.ReadFromUDP(buf)
	fmt.Println("srv got:", string(buf[:n]), clean(from.String()), err)

	// Um terceiro socket manda para o cliente: o kernel descarta.
	other, _ := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	label(other.LocalAddr().String(), "OTHER")
	other.WriteTo([]byte("intruso"), la)
	time.Sleep(50 * time.Millisecond)
	srv.WriteTo([]byte("resposta"), from)
	c.SetReadDeadline(time.Now().Add(2 * time.Second))
	n, err = c.Read(buf)
	fmt.Println("client read:", string(buf[:n]), err)
	other.Close()

	// O par fecha: o ICMP volta e o erro sai na próxima operação.
	srv.Close()
	_, err = c.Write([]byte("x"))
	show("write to closed", err)
	time.Sleep(100 * time.Millisecond)
	_, err = c.Read(buf)
	show("read after icmp", err)
	c.SetReadDeadline(time.Now().Add(50 * time.Millisecond))
	_, err = c.Read(buf)
	show("read again", err)

	_, err = c.Write([]byte("y"))
	show("write again", err)
	time.Sleep(100 * time.Millisecond)
	_, err = c.Write([]byte("z"))
	show("write after icmp", err)
	time.Sleep(100 * time.Millisecond)
	c.SetReadDeadline(time.Now().Add(50 * time.Millisecond))
	n, _, err = c.ReadFromUDP(buf)
	show("readfrom after icmp", err)
	c.Close()

	// net.Dial("udp") também conecta.
	d, err := net.Dial("udp", "127.0.0.1:9")
	show("dial port 9", err)
	label(d.LocalAddr().String(), "D")
	fmt.Println("dial local ip:", d.LocalAddr().(*net.UDPAddr).IP)
	d.Write([]byte("x"))
	time.Sleep(100 * time.Millisecond)
	d.SetReadDeadline(time.Now().Add(time.Second))
	_, err = d.Read(buf)
	show("dial read", err)
	d.Close()
}
