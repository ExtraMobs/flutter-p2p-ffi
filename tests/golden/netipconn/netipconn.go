// Shim net: ResolveIPAddr (literais v4/v6 com zona, localhost, erros de
// rede e de protocolo como os do Go) e o tipo *net.IPConn em type switch,
// embutido e por interface. Nada abre socket bruto (como root o Go abriria).
package main

import (
	"errors"
	"fmt"
	"net"
	"syscall"
	"time"
)

// rawEndpoint embute *net.IPConn (como o maEndpoint do manet).
type rawEndpoint struct {
	*net.IPConn
	label string
}

func resolve(network, address string) {
	a, err := net.ResolveIPAddr(network, address)
	if err != nil {
		var ae *net.AddrError
		var un net.UnknownNetworkError
		fmt.Printf("%q %q: erro %v (AddrError=%v Unknown=%v)\n", network, address, err,
			errors.As(err, &ae), errors.As(err, &un))
		return
	}
	fmt.Printf("%q %q: %v ip=%v zone=%q network=%s\n", network, address, a, a.IP, a.Zone, a.Network())
}

func kind(c any) string {
	switch v := c.(type) {
	case *net.TCPConn:
		return "tcp"
	case *net.UDPConn:
		return "udp"
	case *net.IPConn:
		if v == nil {
			return "ip(nil)"
		}
		return "ip"
	case *net.UnixConn:
		return "unix"
	case net.PacketConn:
		return "packet"
	case net.Conn:
		return "conn"
	default:
		return fmt.Sprintf("outro %T", v)
	}
}

func main() {
	resolve("ip", "127.0.0.1")
	resolve("ip4", "192.0.2.7")
	resolve("ip6", "2001:db8::1")
	resolve("ip", "fe80::1%eth0")
	resolve("ip6", "fe80::abcd%7")
	resolve("", "10.1.2.3")
	resolve("ip", "")
	resolve("ip:icmp", "::1")
	resolve("ip4:1", "203.0.113.9")
	resolve("ip6:ipv6-icmp", "::")
	resolve("ip", "localhost")
	resolve("ip4", "localhost")
	resolve("ip4", "2001:db8::1")
	resolve("ip6", "192.0.2.1")
	resolve("tcp", "127.0.0.1")
	resolve("udp6", "::1")
	resolve("ip4:nope", "127.0.0.1")
	resolve("ip4:", "127.0.0.1")
	resolve("ip4:ICMP", "127.0.0.1")
	resolve("ipx", "127.0.0.1")
	resolve("ipx:1", "127.0.0.1")

	// Redes IP nos Dial/Listen: só os erros de rede (sem socket).
	_, err := net.Dial("ip", "127.0.0.1")
	fmt.Println(err)
	_, err = net.Dial("ip4:nope", "127.0.0.1")
	fmt.Println(err)
	_, err = net.Dial("ip4:1", "")
	fmt.Println(err)
	_, err = net.ListenPacket("ip6:tcpx", "::1")
	fmt.Println(err)
	_, err = net.DialIP("ip4:1", nil, nil)
	fmt.Println(err)
	_, err = net.DialIP("tcp", nil, &net.IPAddr{IP: net.IPv4(192, 0, 2, 1)})
	fmt.Println(err)
	_, err = net.ListenIP("udp", &net.IPAddr{IP: net.IPv4(192, 0, 2, 1)})
	fmt.Println(err)
	_, err = net.ListenIP("ip", nil)
	fmt.Println(err)

	// Tipos: type switch, embutimento e interfaces.
	var nilIP *net.IPConn
	var conns []any = []any{nilIP, &net.IPConn{}, (*net.TCPConn)(nil), (*net.UDPConn)(nil), (*net.UnixConn)(nil), 42}
	for _, c := range conns {
		fmt.Println(kind(c))
	}
	var pc net.PacketConn = nilIP
	_, isConn := pc.(net.Conn)
	_, isSys := pc.(syscall.Conn)
	fmt.Println("IPConn é Conn:", isConn, "syscall.Conn:", isSys)
	ep := rawEndpoint{label: "raw"}
	fmt.Println(ep.label, ep.IPConn == nil)

	// IPConn sem descritor (o único que existe sem socket bruto): EINVAL.
	z := &net.IPConn{}
	fmt.Println(z.Close(), z.LocalAddr() == nil, z.RemoteAddr() == nil, z.SetDeadline(time.Time{}))
	n, err := z.Write([]byte("x"))
	fmt.Println(n, err, errors.Is(err, syscall.EINVAL))
	n, from, err := z.ReadFromIP(make([]byte, 4))
	fmt.Println(n, from == nil, err)
	_, err = z.WriteTo([]byte("x"), &net.IPAddr{})
	fmt.Println(err)
	rc, err := z.SyscallConn()
	fmt.Println(rc == nil, err)
	func() {
		defer func() { fmt.Println("nil IPConn:", recover()) }()
		nilIP.WriteToIP(nil, nil)
	}()
	ep.IPConn = z
	fmt.Println(ep.Close(), ep.SetReadBuffer(1))
	n, _, err = ep.ReadFrom(make([]byte, 1))
	fmt.Println(n, err)
	var c net.Conn = ep
	_, isRaw := c.(rawEndpoint)
	fmt.Println("rawEndpoint é Conn:", isRaw)
}
