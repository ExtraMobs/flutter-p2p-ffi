// Shim net/netip: Addr, AddrPort e Prefix por valor (==, chave de map,
// campo de struct), parse com os erros do Go, Prefix.Contains/Overlaps/
// Masked, Next/Prev, Compare, Marshal/Unmarshal de texto e binário e a
// ponte com net.IP.
package main

import (
	"fmt"
	"net"
	"net/netip"
	"sort"
)

type route struct {
	Dst  netip.Prefix
	Via  netip.Addr
	Port uint16
}

func main() {
	for _, s := range []string{"1.2.3.4", "::1", "fe80::1%eth0", "::ffff:1.2.3.4", "2001:db8:0:0:1:0:0:1", "1.2.3", "01.2.3.4", "1.2.3.256", "::1::2", "fe80::%", "%eth0", "abc", "", "1:2:3:4:5:6:7:8:9", "::1.2.3.4", "12345::"} {
		a, err := netip.ParseAddr(s)
		fmt.Println(s, "=>", a, err, a.IsValid(), a.Is4(), a.Is6(), a.Is4In6(), a.BitLen(), a.Zone())
	}
	a := netip.MustParseAddr("192.168.1.1")
	b := netip.AddrFrom4([4]byte{192, 168, 1, 1})
	c := netip.MustParseAddr("::ffff:192.168.1.1")
	fmt.Println(a == b, a == c, a == c.Unmap(), a.Compare(c), c.Compare(a), a.Less(c))
	fmt.Println(a.Next(), a.Prev(), netip.MustParseAddr("255.255.255.255").Next().IsValid(), netip.IPv6Unspecified().Prev().IsValid())
	fmt.Println(netip.MustParseAddr("2001:db8::ffff").Next(), netip.MustParseAddr("2001:db8::1:0").Prev())
	fmt.Println(a.IsPrivate(), a.IsGlobalUnicast(), a.IsLoopback(), netip.IPv6Loopback().IsLoopback(), netip.IPv4Unspecified().IsUnspecified(), netip.IPv6LinkLocalAllNodes().IsLinkLocalMulticast())
	fmt.Println(netip.MustParseAddr("2001:db8::1").StringExpanded(), a.StringExpanded(), a.As4(), a.As16(), a.AsSlice(), netip.Addr{}.AsSlice() == nil)
	fmt.Println(netip.Addr{}, netip.Addr{}.IsValid(), netip.Addr{} == netip.Addr{}, netip.IPv6LinkLocalAllRouters())

	seen := map[netip.Addr]int{}
	for _, s := range []string{"10.0.0.1", "10.0.0.2", "10.0.0.1", "::1", "::1", "::1%lo"} {
		seen[netip.MustParseAddr(s)]++
	}
	fmt.Println(len(seen), seen[netip.MustParseAddr("10.0.0.1")], seen[netip.MustParseAddr("::1")], seen[netip.MustParseAddr("::1%lo")])

	for _, s := range []string{"10.0.0.0/8", "10.1.2.3/8", "2001:db8::/32", "::ffff:10.0.0.0/104", "1.2.3.4/33", "1.2.3.4/-1", "1.2.3.4", "fe80::1%eth0/64", "1.2.3.4/08", "::/0"} {
		p, err := netip.ParsePrefix(s)
		fmt.Println(s, "=>", p, err, p.IsValid(), p.Bits(), p.Addr(), p.Masked(), p.IsSingleIP())
	}
	p := netip.MustParsePrefix("10.0.0.0/8")
	fmt.Println(p.Contains(netip.MustParseAddr("10.255.0.1")), p.Contains(netip.MustParseAddr("11.0.0.1")), p.Contains(netip.MustParseAddr("::ffff:10.0.0.1")))
	q := netip.MustParsePrefix("10.1.0.0/16")
	fmt.Println(p.Overlaps(q), q.Overlaps(netip.MustParsePrefix("10.2.0.0/16")), p.Compare(q), q.Compare(p))
	v6, _ := netip.MustParseAddr("2001:db8::1234").Prefix(48)
	fmt.Println(v6, v6.Contains(netip.MustParseAddr("2001:db8:0:ffff::1")))
	_, err := a.Prefix(40)
	fmt.Println(err, netip.PrefixFrom(a, 24), netip.PrefixFrom(a, 99).IsValid())

	ap := netip.AddrPortFrom(a, 4001)
	fmt.Println(ap, ap.Addr(), ap.Port(), ap.IsValid(), netip.AddrPort{})
	for _, s := range []string{"1.2.3.4:80", "[::1]:443", "[fe80::1%eth0]:22", "1.2.3.4", "[1.2.3.4]:80", "::1:80", "1.2.3.4:99999", ":80"} {
		x, err := netip.ParseAddrPort(s)
		fmt.Println(s, "=>", x, err)
	}

	routes := map[netip.Prefix]route{}
	routes[p] = route{Dst: p, Via: a, Port: 1}
	routes[q] = route{Dst: q, Via: c, Port: 2}
	fmt.Println(len(routes), routes[netip.MustParsePrefix("10.0.0.0/8")].Via, routes[q].Port)
	r := routes[q]
	fmt.Printf("%v %+v\n", r, r)
	pfxs := []netip.Prefix{q, p, netip.MustParsePrefix("::/0")}
	sort.Slice(pfxs, func(i, j int) bool { return pfxs[i].Compare(pfxs[j]) < 0 })
	fmt.Println(pfxs)

	txt, err := a.MarshalText()
	fmt.Println(string(txt), err)
	var u netip.Addr
	fmt.Println(u.UnmarshalText([]byte("2001:db8::2")), u)
	fmt.Println(u.UnmarshalText([]byte("nope")), u.IsValid())
	bin, _ := netip.MustParseAddr("fe80::1%eth0").MarshalBinary()
	fmt.Println(bin)
	var u2 netip.Addr
	fmt.Println(u2.UnmarshalBinary(bin), u2)
	pb, _ := p.MarshalBinary()
	var p2 netip.Prefix
	fmt.Println(pb, p2.UnmarshalBinary(pb), p2, p2 == p)
	apt, _ := ap.MarshalText()
	var ap2 netip.AddrPort
	fmt.Println(string(apt), ap2.UnmarshalText(apt), ap2 == ap)
	fmt.Println(string(a.AppendTo([]byte("ip="))), string(p.AppendTo(nil)), string(ap.AppendTo([]byte("<"))))

	ip := net.ParseIP("10.9.8.7")
	na, ok := netip.AddrFromSlice(ip)
	fmt.Println(na, ok, na.Unmap(), na.Unmap().Is4())
	na4, ok := netip.AddrFromSlice(ip.To4())
	fmt.Println(na4, ok, net.IP(na4.AsSlice()), p.Contains(na4))
	_, ok = netip.AddrFromSlice([]byte{1, 2, 3})
	fmt.Println(ok)

	defer func() { fmt.Println("recover:", recover()) }()
	netip.MustParseAddr("not an ip")
}
