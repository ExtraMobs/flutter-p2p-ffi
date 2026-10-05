// UDP de verdade no shim net (decisão D4): eco por ListenUDP, ReadFrom/WriteTo
// pela interface net.PacketConn, DialUDP conectado, datagrama truncado,
// deadline e resolução de nomes (localhost) e interfaces de rede.
package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"sort"
	"time"
)

// tagged embrulha um PacketConn (implementação gerada da interface do shim).
type tagged struct {
	net.PacketConn
	n int
}

func (t *tagged) ReadFrom(p []byte) (int, net.Addr, error) {
	n, a, err := t.PacketConn.ReadFrom(p)
	t.n++
	return n, a, err
}

func serve(pc net.PacketConn, done chan<- int) {
	buf := make([]byte, 1500)
	count := 0
	for {
		n, from, err := pc.ReadFrom(buf)
		if err != nil {
			fmt.Println("servidor parou:", errors.Is(err, net.ErrClosed))
			done <- count
			return
		}
		count++
		pc.WriteTo(append([]byte("eco:"), buf[:n]...), from)
	}
}

func main() {
	srv, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	t := &tagged{PacketConn: srv}
	done := make(chan int)
	go serve(t, done)
	fmt.Println("local:", srv.LocalAddr().Network(), srv.LocalAddr().(*net.UDPAddr).IP)

	raddr, err := net.ResolveUDPAddr("udp", srv.LocalAddr().String())
	if err != nil {
		panic(err)
	}
	c, err := net.DialUDP("udp", nil, raddr)
	if err != nil {
		panic(err)
	}
	for i := 0; i < 3; i++ {
		fmt.Fprintf(c, "msg %d", i)
		buf := make([]byte, 64)
		n, err := c.Read(buf)
		fmt.Printf("%q %v\n", buf[:n], err)
	}

	// Datagrama maior que o buffer: o resto se perde.
	c.Write([]byte("0123456789"))
	small := make([]byte, 6)
	n, err := c.Read(small)
	fmt.Printf("truncado %q %v\n", small[:n], err)

	// Socket não conectado: WriteToUDP/ReadFromUDP.
	u, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		panic(err)
	}
	u.WriteToUDP([]byte("direto"), raddr)
	buf := make([]byte, 64)
	n, from, err := u.ReadFromUDP(buf)
	fmt.Printf("%q de servidor=%v %v\n", buf[:n], from.String() == raddr.String(), err)

	// Deadline sem nada chegando.
	u.SetReadDeadline(time.Now().Add(30 * time.Millisecond))
	_, _, err = u.ReadFromUDP(buf)
	fmt.Println("timeout:", os.IsTimeout(err), errors.Is(err, os.ErrDeadlineExceeded))
	u.Close()
	c.Close()
	srv.Close()
	fmt.Println("datagramas:", <-done, t.n)

	// Nomes: localhost vem do /etc/hosts.
	addrs, err := net.LookupHost("localhost")
	sort.Strings(addrs)
	has := false
	for _, a := range addrs {
		has = has || a == "127.0.0.1"
	}
	fmt.Println("localhost:", has, err)
	ta, err := net.ResolveTCPAddr("tcp4", "localhost:8080")
	fmt.Println(ta, err)
	_, err = net.ResolveTCPAddr("tcp", "localhost:porta")
	fmt.Println(err)

	// Interfaces: a de loopback existe e tem 127.0.0.1.
	ifs, err := net.Interfaces()
	loop := false
	for _, ifc := range ifs {
		if ifc.Flags&net.FlagLoopback == 0 {
			continue
		}
		as, _ := ifc.Addrs()
		for _, a := range as {
			if ipn, ok := a.(*net.IPNet); ok && ipn.IP.Equal(net.IPv4(127, 0, 0, 1)) {
				loop = true
			}
		}
	}
	fmt.Println("loopback:", loop, err)
}
