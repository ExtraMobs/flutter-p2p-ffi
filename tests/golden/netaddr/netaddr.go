// Shim net (sem rede): IP/IPMask/IPNet/HardwareAddr com a forma de tipo
// nomeado gerado (conversões, índice, len, append, fatia, `*IP`), endereços
// TCP/UDP/IP/Unix em net.Addr, SplitHostPort/JoinHostPort e os erros do
// pacote impressos como o Go os formata.
package main

import (
	"bytes"
	"errors"
	"fmt"
	"net"
	"net/netip"
)

type peer struct {
	ID   string
	Addr net.Addr
	IPs  []net.IP
}

func describe(a net.Addr) string {
	switch v := a.(type) {
	case *net.TCPAddr:
		return fmt.Sprintf("tcp ip=%v port=%d zone=%q", v.IP, v.Port, v.Zone)
	case *net.UDPAddr:
		return fmt.Sprintf("udp ip=%v port=%d", v.IP, v.Port)
	case *net.IPAddr:
		return "ip " + v.String()
	case nil:
		return "nil"
	default:
		return "outro " + a.Network() + " " + a.String()
	}
}

func main() {
	for _, s := range []string{"192.168.1.10", "::1", "fe80::1", "::ffff:10.0.0.1", "2001:db8::68", "1.2.3", "300.1.1.1", "", "fe80::1%eth0"} {
		ip := net.ParseIP(s)
		fmt.Println(s, "=>", ip, len(ip), ip == nil, ip.To4() != nil, ip.To16() != nil)
		if ip != nil {
			fmt.Println("  ", ip.IsLoopback(), ip.IsPrivate(), ip.IsGlobalUnicast(), ip.IsLinkLocalUnicast(), ip.IsUnspecified(), ip.IsMulticast(), ip.DefaultMask())
		}
	}

	ip := net.IPv4(10, 1, 2, 3)
	fmt.Println(ip, len(ip), ip[12], ip.To4(), len(ip.To4()), ip.Equal(net.ParseIP("10.1.2.3").To4()))
	b := []byte(ip.To4())
	b[0] = 99
	fmt.Println(ip, b)
	raw := net.IP(b)
	raw = append(raw, 0)
	fmt.Println(raw, len(raw), raw[:4], bytes.Equal(raw[:4], []byte{99, 1, 2, 3}))
	fmt.Printf("%v %s %d\n", ip.To4(), ip, []byte(ip.To4()))
	var nilIP net.IP
	fmt.Println(nilIP, nilIP == nil, nilIP.To4() == nil, len(nilIP))

	t, err := ip.MarshalText()
	fmt.Println(string(t), err)
	var back net.IP
	err = back.UnmarshalText([]byte("2001:db8::1"))
	fmt.Println(back, err)
	err = back.UnmarshalText([]byte("bad"))
	fmt.Println(back, err)
	p := &back
	fmt.Println(p.String(), (*p).To16())

	ipnet := &net.IPNet{IP: net.IPv4(192, 168, 0, 0), Mask: net.CIDRMask(16, 32)}
	fmt.Println(ipnet, ipnet.Contains(net.ParseIP("192.168.44.1")), ipnet.Contains(net.ParseIP("10.0.0.1")), ipnet.Network())
	ones, bits := ipnet.Mask.Size()
	fmt.Println(ones, bits, ipnet.Mask, net.IPv4Mask(255, 255, 255, 0), net.CIDRMask(64, 128))
	for _, c := range []string{"10.0.0.0/8", "2001:db8::/32", "192.168.1.77/24", "10.0.0.0/33", "x/8", "10.0.0.1"} {
		cip, cnet, err := net.ParseCIDR(c)
		fmt.Println(c, "=>", cip, cnet, err)
		if err == nil {
			fmt.Printf("   %v %s contains=%v\n", *cnet, cnet.IP.Mask(cnet.Mask), cnet.Contains(cip))
		}
	}
	fmt.Println(net.IP{1, 2, 3}, net.IPMask{0xff, 0x00, 0xff, 0}, net.IP(nil).Mask(net.CIDRMask(8, 32)))

	for _, hp := range []string{"localhost:4001", "[::1]:8080", "[fe80::1%eth0]:443", "1.2.3.4", "::1:80", "[::1]", "[::1]x:80"} {
		h, port, err := net.SplitHostPort(hp)
		fmt.Printf("%q %q %v\n", h, port, err)
	}
	fmt.Println(net.JoinHostPort("::1", "80"), net.JoinHostPort("example.com", "443"))

	tcp := &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 4001}
	udp := &net.UDPAddr{IP: net.ParseIP("::1"), Port: 53, Zone: "lo"}
	var addrs []net.Addr
	addrs = append(addrs, tcp, udp, &net.IPAddr{IP: net.IPv4(8, 8, 8, 8)}, &net.UnixAddr{Name: "/tmp/s", Net: "unix"}, ipnet, nil)
	for _, a := range addrs {
		fmt.Println(describe(a))
	}
	fmt.Println(tcp, udp, tcp.Network(), udp.Network(), tcp.AddrPort(), udp.AddrPort())
	var nilTCP *net.TCPAddr
	var na net.Addr = nilTCP
	fmt.Println(na == nil, na.String(), nilTCP.AddrPort().IsValid())
	ap := netip.MustParseAddrPort("[2001:db8::1]:9000")
	fmt.Println(net.TCPAddrFromAddrPort(ap), net.UDPAddrFromAddrPort(ap).Port)
	pr := peer{ID: "Qm", Addr: tcp, IPs: []net.IP{ip, back}}
	fmt.Printf("%v %d\n", pr.IPs, len(pr.IPs))

	mac, err := net.ParseMAC("00:1A:2b:3c:4D:5e")
	fmt.Println(mac, err, len(mac))
	_, err = net.ParseMAC("00:1A:2b")
	fmt.Println(err)
	mac2, _ := net.ParseMAC("0000.5e00.5301")
	fmt.Println(mac2, net.HardwareAddr{1, 2})

	opErr := &net.OpError{Op: "dial", Net: "tcp", Source: tcp, Addr: udp, Err: errors.New("connection refused")}
	fmt.Println(opErr, opErr.Timeout(), opErr.Temporary(), errors.Unwrap(opErr))
	var e error = &net.OpError{Op: "read", Net: "tcp", Addr: tcp, Err: net.ErrClosed}
	fmt.Println(e, errors.Is(e, net.ErrClosed))
	var ne net.Error
	if errors.As(e, &ne) {
		fmt.Println("net.Error", ne.Timeout(), ne.Temporary())
	}
	var ae *net.AddrError
	_, _, err = net.SplitHostPort("nope")
	fmt.Println(errors.As(err, &ae), ae.Err, ae.Addr)
	fmt.Println(&net.ParseError{Type: "IP address", Text: "x"}, net.UnknownNetworkError("foo"), net.InvalidAddrError("bad addr"))
	dnsErr := &net.DNSError{Err: "no such host", Name: "example.invalid", Server: "8.8.8.8:53", IsNotFound: true}
	fmt.Println(dnsErr, dnsErr.Timeout(), dnsErr.Temporary(), dnsErr.IsNotFound)
	fmt.Println(net.ErrClosed, net.ErrWriteToConnected)
	fmt.Println(net.IPv4bcast, net.IPv4zero, net.IPv6loopback, net.IPv6linklocalallnodes, net.IPv4len, net.IPv6len)
}
