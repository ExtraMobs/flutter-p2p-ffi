// Oráculo dos shims net (endereços, sem rede) e net/netip: cada entrada
// passa por ParseIP/ParseCIDR/SplitHostPort/ParseMAC e por
// ParseAddr/ParsePrefix/ParseAddrPort, e cada resultado vira uma linha de
// texto. Saída: JSON {"inputs":[...],"res":[["k linha"...]...],"masks":[...]};
// o Dart recalcula as mesmas linhas (`net_test.dart`).
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strings"
)

var inputs = []string{
	"", "0.0.0.0", "127.0.0.1", "10.1.2.3", "172.16.5.4", "172.32.0.1", "192.168.0.1", "169.254.1.1", "224.0.0.1", "224.1.0.1",
	"239.255.255.250", "255.255.255.255", "8.8.8.8", "1.2.3", "1.2.3.4.5", "01.2.3.4", "1.2.3.256", "1..2.3", ".1.2.3", "1.2.3.",
	"1.2.3.4x", "::", "::1", "::2", "fe80::1", "fe80::1%eth0", "fe80::%", "ff01::1", "ff02::1", "ff02::2", "ff05::1", "fc00::1",
	"fd12:3456::1", "2001:db8::68", "2001:db8:0:0:1:0:0:1", "2001:0db8:0000:0000:0000:ff00:0042:8329", "1:2:3:4:5:6:7:8",
	"1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7", "::ffff:1.2.3.4", "::ffff:10.0.0.1", "::ffff:192.168.1.1%x", "::1.2.3.4",
	"1:2:3:4:5:6:1.2.3.4", "1:2:3:4:5:6:7:1.2.3.4", "1::1.2.3.4", "::1::2", "12345::", "1:2:3:4:5:6:7::", "::1:2:3:4:5:6:7",
	"1::2:3:4:5:6:7", "abcd:EF01::1", "g::1", ":1", "1:", "1::%25", "%eth0", "abc", "ffff::ffff:ffff:ffff:ffff:ffff:ffff",
	"10.0.0.0/8", "10.1.2.3/8", "192.168.1.77/24", "0.0.0.0/0", "1.2.3.4/32", "1.2.3.4/33", "1.2.3.4/-1", "1.2.3.4/08",
	"1.2.3.4/", "2001:db8::/32", "2001:db8::1/128", "::/0", "::ffff:10.0.0.0/104", "fe80::1%eth0/64", "x/8", "1.2.3.4/a",
	"1.2.3.4:80", "[::1]:443", "[fe80::1%eth0]:22", "[1.2.3.4]:80", "::1:80", "1.2.3.4:99999", "1.2.3.4:", ":80",
	"[::1]", "[::1]x:80", "[::1", "localhost:4001", "a:b:c", "[a]:b]", "x[y:80", "1.2.3.4:0", "[::ffff:1.2.3.4]:65535",
	"00:1A:2b:3c:4D:5e", "00-1a-2b-3c-4d-5e", "001a.2b3c.4d5e", "001a2b3c4d5e", "00:1a:2b:3c:4d:5e:6f:70", "00:1a:2b",
	"00:1a:2b:3c:4d:5g", "00:1a:2b:3c:4d-5e", "0000.5e00.5301", "02:00:5e:10:00:00:00:01:00:00:00:00:00:00:00:00:00:00:00:01",
}

func hx(b []byte) string {
	if b == nil {
		return "nil"
	}
	return hex.EncodeToString(b)
}

func es(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func bit(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

func ipFlags(ip net.IP) string {
	return bit(ip.IsUnspecified()) + bit(ip.IsLoopback()) + bit(ip.IsPrivate()) + bit(ip.IsMulticast()) +
		bit(ip.IsInterfaceLocalMulticast()) + bit(ip.IsLinkLocalMulticast()) + bit(ip.IsLinkLocalUnicast()) + bit(ip.IsGlobalUnicast())
}

func addrFlags(a netip.Addr) string {
	return bit(a.IsValid()) + bit(a.Is4()) + bit(a.Is6()) + bit(a.Is4In6()) + bit(a.IsUnspecified()) + bit(a.IsLoopback()) +
		bit(a.IsPrivate()) + bit(a.IsMulticast()) + bit(a.IsInterfaceLocalMulticast()) + bit(a.IsLinkLocalMulticast()) +
		bit(a.IsLinkLocalUnicast()) + bit(a.IsGlobalUnicast())
}

func run(s string, prev netip.Addr) []string {
	var out []string
	add := func(k string, parts ...string) { out = append(out, k+" "+strings.Join(parts, "|")) }

	ip := net.ParseIP(s)
	mt, merr := ip.MarshalText()
	add("ip", hx(ip), ip.String(), hx(ip.To4()), hx(ip.To16()), ipFlags(ip), ip.DefaultMask().String(), string(mt), es(merr))
	if ip != nil {
		add("ipmask", ip.Mask(net.CIDRMask(12, 32)).String(), ip.Mask(net.CIDRMask(70, 128)).String(),
			ip.Mask(net.CIDRMask(108, 128)).String(), bit(ip.Equal(ip.To4())), bit(ip.Equal(net.ParseIP("10.1.2.3"))))
	}
	cip, cnet, err := net.ParseCIDR(s)
	cs := "nil"
	if cnet != nil {
		cs = cnet.String() + " " + cnet.Network() + " " + bit(cnet.Contains(cip)) + " " + bit(cnet.Contains(net.ParseIP("10.200.0.1")))
	}
	add("cidr", hx(cip), cs, es(err))
	h, p, err := net.SplitHostPort(s)
	add("hostport", h, p, es(err), net.JoinHostPort(h, p))
	hw, err := net.ParseMAC(s)
	add("mac", hw.String(), hx(hw), es(err))

	a, err := netip.ParseAddr(s)
	bin, _ := a.MarshalBinary()
	txt, _ := a.MarshalText()
	add("addr", a.String(), es(err), a.StringExpanded(), addrFlags(a), fmt.Sprint(a.BitLen()), a.Zone(),
		a.Next().String(), a.Prev().String(), a.Unmap().String(), hx(a.AsSlice()), hx(bin), string(txt),
		fmt.Sprint(a.Compare(prev)), bit(a.Less(prev)), bit(a == prev))
	for _, n := range []int{0, 1, 17, 31, 32, 64, 120, 128, 129, -1} {
		pf, err := a.Prefix(n)
		add("addrprefix", pf.String(), es(err))
	}
	var u netip.Addr
	err = u.UnmarshalBinary(bin)
	add("addrunbin", u.String(), es(err), bit(u == a))

	pf, err := netip.ParsePrefix(s)
	pbin, _ := pf.MarshalBinary()
	ptxt, _ := pf.MarshalText()
	add("prefix", pf.String(), es(err), pf.Masked().String(), fmt.Sprint(pf.Bits()), bit(pf.IsValid()), bit(pf.IsSingleIP()),
		pf.Addr().String(), hx(pbin), string(ptxt), bit(pf.Contains(prev)), bit(pf.Contains(pf.Addr().Next())),
		bit(pf.Overlaps(netip.MustParsePrefix("10.0.0.0/16"))), bit(pf.Overlaps(netip.MustParsePrefix("2001:db8::/48"))),
		fmt.Sprint(pf.Compare(netip.MustParsePrefix("10.1.0.0/16"))))

	ap, err := netip.ParseAddrPort(s)
	abin, _ := ap.MarshalBinary()
	atxt, _ := ap.MarshalText()
	add("addrport", ap.String(), es(err), fmt.Sprint(ap.Port()), ap.Addr().String(), hx(abin), string(atxt), bit(ap.IsValid()),
		net.TCPAddrFromAddrPort(ap).String(), net.UDPAddrFromAddrPort(ap).String())
	return out
}

func main() {
	var res [][]string
	prev := netip.MustParseAddr("10.1.2.3")
	for _, s := range inputs {
		res = append(res, run(s, prev))
		if a, err := netip.ParseAddr(s); err == nil {
			prev = a
		}
	}
	var masks []string
	for _, bits := range []int{0, 32, 64, 128} {
		for _, ones := range []int{-1, 0, 1, 7, 8, 9, 24, 31, 32, 33, 64, 127, 128, 129} {
			m := net.CIDRMask(ones, bits)
			o, b := m.Size()
			masks = append(masks, fmt.Sprintf("%d/%d %s %d %d", ones, bits, m.String(), o, b))
		}
	}
	for _, m := range []net.IPMask{{0xff, 0, 0xff, 0}, {0xff, 0xf0, 0, 0}, {}, {0xff}, {0x80, 0, 0, 1}} {
		o, b := m.Size()
		n := &net.IPNet{IP: net.IPv4(10, 1, 2, 3), Mask: m}
		masks = append(masks, fmt.Sprintf("%s %d %d %s", m.String(), o, b, n.String()))
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"inputs": inputs, "res": res, "masks": masks})
}
