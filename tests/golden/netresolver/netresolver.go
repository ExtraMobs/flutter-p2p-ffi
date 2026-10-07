// Resolver com Dial próprio no shim net (decisão D4, S1/S2): todo lookup do
// Resolver passa pelo cliente DNS do Go (A/AAAA, /etc/hosts, search, ndots,
// SRV/MX/NS/TXT/PTR, CNAME pela consulta A/AAAA, TCP quando a resposta UDP
// vem truncada), e o Dial é chamado com o servidor do /etc/resolv.conf. Um
// servidor DNS falso (UDP e TCP em 127.0.0.1, porta efêmera) responde por
// uma tabela; o Dial ignora o endereço e disca nele. O que depende da máquina
// (o servidor do resolv.conf, o conteúdo do /etc/hosts) só aparece como
// booleano.
package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"sort"
	"strings"
	"sync"
)

type rr struct {
	typ  uint16
	name string // dono (vazio: o nome da pergunta, por ponteiro)
	data []byte
}

const (
	tA     = 1
	tNS    = 2
	tCNAME = 5
	tPTR   = 12
	tMX    = 15
	tTXT   = 16
	tAAAA  = 28
	tSRV   = 33
)

// encName escreve o nome em labels, sem compressão.
func encName(n string) []byte {
	var out []byte
	for _, l := range strings.Split(strings.TrimSuffix(n, "."), ".") {
		if l == "" {
			continue
		}
		out = append(out, byte(len(l)))
		out = append(out, l...)
	}
	return append(out, 0)
}

func u16(v uint16) []byte { return binary.BigEndian.AppendUint16(nil, v) }

func srv(prio, weight, port uint16, target string) []byte {
	b := append(u16(prio), u16(weight)...)
	b = append(b, u16(port)...)
	return append(b, encName(target)...)
}

func mx(pref uint16, host string) []byte { return append(u16(pref), encName(host)...) }

func txt(parts ...string) []byte {
	var b []byte
	for _, p := range parts {
		b = append(b, byte(len(p)))
		b = append(b, p...)
	}
	return b
}

type answer struct {
	rcode     int
	truncated bool // só por UDP
	rrs       []rr
}

var zone = map[string]answer{
	"a.test./1":      {rrs: []rr{{typ: tA, data: []byte{10, 0, 0, 1}}}},
	"multi.test./1":  {rrs: []rr{{typ: tA, data: []byte{10, 0, 0, 2}}, {typ: tA, data: []byte{10, 0, 0, 3}}}},
	"v6.test./28":    {rrs: []rr{{typ: tAAAA, data: []byte{0x20, 0x01, 0x0d, 0xb8, 15: 1}}}},
	"alias.test./1":  {rrs: []rr{{typ: tCNAME, data: encName("real.test.")}, {typ: tA, name: "real.test.", data: []byte{10, 0, 0, 9}}}},
	"alias.test./28": {rrs: []rr{{typ: tCNAME, data: encName("real.test.")}}},
	"_http._tcp.srv.test./33": {rrs: []rr{
		{typ: tSRV, data: srv(20, 5, 8080, "c.test.")},
		{typ: tSRV, data: srv(10, 0, 80, "b.test.")},
	}},
	"mx.test./15":               {rrs: []rr{{typ: tMX, data: mx(20, "mx2.test.")}, {typ: tMX, data: mx(10, "mx1.test.")}}},
	"ns.test./2":                {rrs: []rr{{typ: tNS, data: encName("ns1.test.")}, {typ: tNS, data: encName("ns2.test.")}}},
	"txt.test./16":              {rrs: []rr{{typ: tTXT, data: txt("v=spf1", " -all")}, {typ: tTXT, data: txt("hello")}}},
	"big.test./16":              {truncated: true, rrs: []rr{{typ: tTXT, data: txt(strings.Repeat("x", 200), strings.Repeat("y", 200))}}},
	"bad.test./15":              {rrs: []rr{{typ: tMX, data: mx(1, "ok.test.")}, {typ: tMX, data: mx(2, "bad_-.test.")}}},
	"1.0.0.10.in-addr.arpa./12": {rrs: []rr{{typ: tPTR, data: encName("a.test.")}}},
	"fail.test./1":              {rcode: 2},
	"fail.test./28":             {rcode: 2},
}

// parseQuestion lê o id, o nome (minúsculo, com ponto) e o tipo da pergunta.
func parseQuestion(q []byte) (uint16, string, uint16, int) {
	id := binary.BigEndian.Uint16(q)
	off := 12
	var labels []string
	for q[off] != 0 {
		n := int(q[off])
		labels = append(labels, strings.ToLower(string(q[off+1:off+1+n])))
		off += 1 + n
	}
	off++
	return id, strings.Join(labels, ".") + ".", binary.BigEndian.Uint16(q[off:]), off + 4
}

var (
	mu      sync.Mutex
	queries []string
)

func respond(q []byte, udp bool) []byte {
	id, name, qtype, end := parseQuestion(q)
	mu.Lock()
	queries = append(queries, fmt.Sprintf("%s/%d", name, qtype))
	mu.Unlock()
	a, ok := zone[fmt.Sprintf("%s%d", name+"/", qtype)]
	rcode := a.rcode
	if !ok && !strings.HasSuffix(name, ".test.") && !strings.HasSuffix(name, ".arpa.") {
		rcode = 3
	}
	if name == "nx.test." {
		rcode = 3
	}
	flags := uint16(0x8180) | uint16(rcode)
	rrs := a.rrs
	if udp && a.truncated {
		flags |= 0x0200
		rrs = nil
	}
	out := append(u16(id), u16(flags)...)
	out = append(out, u16(1)...)
	out = append(out, u16(uint16(len(rrs)))...)
	out = append(out, 0, 0, 0, 0)
	out = append(out, q[12:end]...)
	for _, r := range rrs {
		if r.name == "" {
			out = append(out, 0xc0, 12)
		} else {
			out = append(out, encName(r.name)...)
		}
		out = append(out, u16(r.typ)...)
		out = append(out, 0, 1, 0, 0, 0, 60)
		out = append(out, u16(uint16(len(r.data)))...)
		out = append(out, r.data...)
	}
	return out
}

func serveUDP(pc net.PacketConn) {
	buf := make([]byte, 1500)
	for {
		n, from, err := pc.ReadFrom(buf)
		if err != nil {
			return
		}
		pc.WriteTo(respond(buf[:n], true), from)
	}
}

func serveTCP(ln net.Listener) {
	for {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		hdr := make([]byte, 2)
		if _, err := c.Read(hdr); err != nil {
			c.Close()
			continue
		}
		q := make([]byte, binary.BigEndian.Uint16(hdr))
		got := 0
		for got < len(q) {
			n, err := c.Read(q[got:])
			if err != nil {
				break
			}
			got += n
		}
		resp := respond(q, false)
		c.Write(append(u16(uint16(len(resp))), resp...))
		c.Close()
	}
}

func show(what string, err error) {
	var de *net.DNSError
	if errors.As(err, &de) {
		fmt.Printf("%s: DNSError err=%q name=%q notfound=%v temporary=%v timeout=%v server=%v\n",
			what, de.Err, de.Name, de.IsNotFound, de.IsTemporary, de.IsTimeout, de.Server != "")
		return
	}
	fmt.Printf("%s: %v\n", what, err)
}

func main() {
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	go serveUDP(pc)
	go serveTCP(ln)

	dials := map[string]int{}
	port53 := true
	r := &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			dials[network]++
			_, port, _ := net.SplitHostPort(address)
			port53 = port53 && port == "53"
			var d net.Dialer
			if network == "tcp" {
				return d.DialContext(ctx, network, ln.Addr().String())
			}
			return d.DialContext(ctx, network, pc.LocalAddr().String())
		},
	}
	ctx := context.Background()

	hosts, err := r.LookupHost(ctx, "a.test")
	fmt.Println("host a.test:", hosts, err)
	hosts, err = r.LookupHost(ctx, "multi.test.")
	fmt.Println("host multi.test.:", hosts, err)
	hosts, err = r.LookupHost(ctx, "10.1.2.3")
	fmt.Println("literal:", hosts, err)
	ips, err := r.LookupIP(ctx, "ip6", "v6.test")
	fmt.Println("ip6 v6.test:", ips, err)
	ips, err = r.LookupIP(ctx, "ip4", "v6.test")
	show("ip4 v6.test", err)
	addrs, err := r.LookupIPAddr(ctx, "alias.test")
	fmt.Println("ipaddr alias.test:", addrs, err)
	nips, err := r.LookupNetIP(ctx, "ip", "a.test")
	fmt.Println("netip a.test:", nips, err)

	cname, err := r.LookupCNAME(ctx, "alias.test")
	fmt.Println("cname alias.test:", cname, err)
	cname, err = r.LookupCNAME(ctx, "a.test")
	fmt.Println("cname a.test:", cname, err)

	target, srvs, err := r.LookupSRV(ctx, "http", "tcp", "srv.test")
	fmt.Println("srv:", target, err)
	for _, s := range srvs {
		fmt.Println("  ", s.Target, s.Port, s.Priority, s.Weight)
	}
	mxs, err := r.LookupMX(ctx, "mx.test")
	fmt.Println("mx:", err)
	for _, m := range mxs {
		fmt.Println("  ", m.Host, m.Pref)
	}
	mxs, err = r.LookupMX(ctx, "bad.test")
	fmt.Println("mx bad:", len(mxs), mxs[0].Host)
	show("mx bad", err)
	nss, err := r.LookupNS(ctx, "ns.test")
	fmt.Println("ns:", err)
	for _, n := range nss {
		fmt.Println("  ", n.Host)
	}
	txts, err := r.LookupTXT(ctx, "txt.test")
	fmt.Printf("txt: %q %v\n", txts, err)
	txts, err = r.LookupTXT(ctx, "big.test")
	fmt.Println("txt big:", len(txts), len(txts[0]), err)
	names, err := r.LookupAddr(ctx, "10.0.0.1")
	fmt.Println("ptr 10.0.0.1:", names, err)

	_, err = r.LookupHost(ctx, "nx.test")
	show("nx", err)
	_, err = r.LookupTXT(ctx, "nx.test")
	show("nx txt", err)
	_, err = r.LookupHost(ctx, "fail.test")
	show("fail", err)
	_, err = r.LookupHost(ctx, "bad..name")
	show("bad..name", err)
	_, err = r.LookupHost(ctx, "")
	show("vazio", err)
	_, err = r.LookupAddr(ctx, "not-an-ip")
	show("ptr inválido", err)
	_, err = r.LookupIP(ctx, "tcp", "a.test")
	show("rede", err)

	// Dial síncrono (o g2d o embrulha na forma que suspende): o erro dele
	// vira o Err do DNSError, depois de todas as tentativas.
	refused := 0
	off := &net.Resolver{Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		refused++
		return nil, errors.New("sem rede")
	}}
	_, err = off.LookupTXT(ctx, "a.test")
	show("dial falha", err)
	fmt.Println("tentativas > 1:", refused > 1)
	_, err = off.LookupHost(ctx, "localhost")
	fmt.Println("localhost sem DNS:", err)

	// /etc/hosts vem antes do DNS (nsswitch "files dns").
	hosts, err = r.LookupHost(ctx, "localhost")
	fmt.Println("localhost:", len(hosts) > 0, err)
	names, err = r.LookupAddr(ctx, "127.0.0.1")
	has := false
	for _, n := range names {
		has = has || n == "localhost"
	}
	fmt.Println("ptr 127.0.0.1:", has, err)

	mu.Lock()
	sort.Strings(queries)
	seen := map[string]bool{}
	for _, q := range queries {
		seen[q] = true
	}
	mu.Unlock()
	fmt.Println("consultas a.test A:", seen["a.test./1"], "AAAA:", seen["a.test./28"], "localhost:", seen["localhost./1"])
	fmt.Println("dials udp>0:", dials["udp"] > 0, "tcp:", dials["tcp"], "porta 53:", port53)
	pc.Close()
	ln.Close()
}
