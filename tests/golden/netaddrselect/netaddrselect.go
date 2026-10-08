// Ordem RFC 6724 (addrselect.go) dos endereços que o cliente DNS do Go
// devolve: a origem de cada destino é a do kernel, achada por um DialUDP
// (connect) para a porta 9. Um servidor DNS falso (UDP em 127.0.0.1) responde
// A/AAAA por uma tabela; o Resolver.Dial disca nele. 0.0.0.0 tem origem
// 127.0.0.1 (escopo diferente do destino: perde para um destino global), e
// destino sem rota (IPv6 sem pilha IPv6) vai para o fim.
package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"net"
	"strings"
)

var zone = map[string][][]byte{
	"zero.test./1":  {{0, 0, 0, 0}, {8, 8, 8, 8}},
	"loop.test./1":  {{8, 8, 8, 8}, {127, 0, 0, 1}},
	"lo2.test./1":   {{8, 8, 4, 4}, {127, 0, 0, 2}, {0, 0, 0, 0}},
	"v6.test./28":   {{0x20, 0x01, 0x0d, 0xb8, 15: 1}},
	"v6.test./1":    {{8, 8, 8, 8}},
	"local.test./1": {{8, 8, 8, 8}, {169, 254, 1, 1}},
	"lo6.test./28":  {{15: 1}},
	"lo6.test./1":   {{8, 8, 8, 8}},
	"bcast.test./1": {{8, 8, 8, 8}, {255, 255, 255, 255}},
	"mcast.test./1": {{224, 0, 0, 1}, {8, 8, 8, 8}},
}

func respond(q []byte) []byte {
	off := 12
	var labels []string
	for q[off] != 0 {
		n := int(q[off])
		labels = append(labels, strings.ToLower(string(q[off+1:off+1+n])))
		off += 1 + n
	}
	off++
	qtype := binary.BigEndian.Uint16(q[off:])
	end := off + 4
	rrs := zone[fmt.Sprintf("%s./%d", strings.Join(labels, "."), qtype)]
	out := append([]byte{}, q[:2]...)
	out = append(out, 0x81, 0x80, 0, 1)
	out = binary.BigEndian.AppendUint16(out, uint16(len(rrs)))
	out = append(out, 0, 0, 0, 0)
	out = append(out, q[12:end]...)
	for _, d := range rrs {
		out = append(out, 0xc0, 12)
		out = binary.BigEndian.AppendUint16(out, qtype)
		out = append(out, 0, 1, 0, 0, 0, 60)
		out = binary.BigEndian.AppendUint16(out, uint16(len(d)))
		out = append(out, d...)
	}
	return out
}

func main() {
	pc, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		fmt.Println(err)
		return
	}
	go func() {
		buf := make([]byte, 512)
		for {
			n, from, err := pc.ReadFrom(buf)
			if err != nil {
				return
			}
			pc.WriteTo(respond(buf[:n]), from)
		}
	}()
	srv := pc.LocalAddr().String()
	r := &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		return net.Dial("udp", srv)
	}}
	for _, h := range []string{"zero.test", "loop.test", "lo2.test", "v6.test", "local.test", "lo6.test", "bcast.test", "mcast.test"} {
		addrs, err := r.LookupIPAddr(context.Background(), h)
		fmt.Println(h, addrs, err)
	}
	pc.Close()
}
