// Dialer no shim net (decisão D4, S4/S5): KeepAliveConfig (no Dialer, no
// ListenConfig e em TCPConn.SetKeepAliveConfig) e o dial com vários
// endereços: dialSerial (o primeiro que conecta; falhando todos, o erro do
// primeiro) e o dialParallel da rede "tcp" (a família do primeiro endereço
// na frente, a outra depois de FallbackDelay ou logo que a primeira falha).
// Os nomes vêm de um servidor DNS falso no próprio programa, pelo
// Dialer.Resolver. O sandbox não tem IPv6: o ::1 sempre falha. As portas
// mudam a cada execução e não são impressas.
package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"
)

var zone = map[string][][]byte{
	"serial.test./1":  {{127, 0, 0, 3}, {127, 0, 0, 2}},
	"dual.test./1":    {{127, 0, 0, 1}},
	"dual.test./28":   {{15: 1}},
	"refused.test./1": {{127, 0, 0, 3}, {127, 0, 0, 4}},
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
	ips := zone[fmt.Sprintf("%s./%d", strings.Join(labels, "."), qtype)]
	out := append([]byte{}, q[0], q[1], 0x81, 0x80, 0, 1, 0, byte(len(ips)), 0, 0, 0, 0)
	out = append(out, q[12:end]...)
	for _, ip := range ips {
		out = append(out, 0xc0, 12)
		out = binary.BigEndian.AppendUint16(out, qtype)
		out = append(out, 0, 1, 0, 0, 0, 60, 0, byte(len(ip)))
		out = append(out, ip...)
	}
	return out
}

func serve(pc net.PacketConn) {
	buf := make([]byte, 1500)
	for {
		n, from, err := pc.ReadFrom(buf)
		if err != nil {
			return
		}
		pc.WriteTo(respond(buf[:n]), from)
	}
}

func describe(what string, err error) {
	var op *net.OpError
	if errors.As(err, &op) {
		addr := ""
		if ta, ok := op.Addr.(*net.TCPAddr); ok {
			addr = ta.IP.String()
		}
		fmt.Printf("%s: op=%s net=%s addr=%s err=%v\n", what, op.Op, op.Net, addr, op.Err)
		return
	}
	fmt.Printf("%s: %v\n", what, err)
}

func accept(ln net.Listener, got chan<- string) {
	for {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		got <- c.LocalAddr().(*net.TCPAddr).IP.String()
		c.Close()
	}
}

func main() {
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	go serve(pc)
	r := &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		var d net.Dialer
		return d.DialContext(ctx, "udp", pc.LocalAddr().String())
	}}

	got := make(chan string, 4)
	ln2, err := net.Listen("tcp", "127.0.0.2:0")
	if err != nil {
		panic(err)
	}
	go accept(ln2, got)
	_, port2, _ := net.SplitHostPort(ln2.Addr().String())

	lc := net.ListenConfig{KeepAliveConfig: net.KeepAliveConfig{Enable: true, Idle: 7 * time.Second, Interval: 2 * time.Second, Count: 3}}
	ln1, err := lc.Listen(context.Background(), "tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	go accept(ln1, got)
	_, port1, _ := net.SplitHostPort(ln1.Addr().String())

	// dialSerial: 127.0.0.3 recusa, 127.0.0.2 aceita.
	d := net.Dialer{Resolver: r, KeepAliveConfig: net.KeepAliveConfig{Enable: true, Idle: time.Minute, Count: -1}}
	c, err := d.Dial("tcp4", "serial.test:"+port2)
	fmt.Println("serial:", err, c != nil && c.RemoteAddr().(*net.TCPAddr).IP.String() == "127.0.0.2", <-got)
	if c != nil {
		describe("keepalive config", c.(*net.TCPConn).SetKeepAliveConfig(net.KeepAliveConfig{Enable: true, Idle: 1500 * time.Millisecond, Interval: -1}))
		describe("keepalive off", c.(*net.TCPConn).SetKeepAliveConfig(net.KeepAliveConfig{}))
		c.Close()
		describe("keepalive fechada", c.(*net.TCPConn).SetKeepAliveConfig(net.KeepAliveConfig{Enable: true}))
	}

	// Todos recusam: o erro é o do primeiro endereço.
	_, err = d.Dial("tcp4", "refused.test:"+port2)
	describe("todos recusam", err)

	// dialParallel: 127.0.0.1 (primário) conecta; ::1 nunca é preciso.
	start := time.Now()
	c, err = (&net.Dialer{Resolver: r, FallbackDelay: 5 * time.Second}).Dial("tcp", "dual.test:"+port1)
	fmt.Println("dual:", err, c != nil && c.RemoteAddr().(*net.TCPAddr).IP.String() == "127.0.0.1", <-got,
		time.Since(start) < 4*time.Second)
	if c != nil {
		c.Close()
	}
	// O primário falha: o reserva (::1) sai na hora, sem esperar os 5 s, e
	// falha também; o erro é o do primário.
	start = time.Now()
	_, err = (&net.Dialer{Resolver: r, FallbackDelay: 5 * time.Second}).Dial("tcp", "dual.test:"+port2)
	describe("dual recusado", err)
	fmt.Println("sem esperar o FallbackDelay:", time.Since(start) < 4*time.Second)
	// FallbackDelay negativo: em série, na ordem RFC 6724 (IPv4 antes, sem IPv6).
	_, err = (&net.Dialer{Resolver: r, FallbackDelay: -1}).Dial("tcp", "dual.test:"+port2)
	describe("serial dual", err)
	// tcp6 só tem o ::1.
	_, err = (&net.Dialer{Resolver: r}).Dial("tcp6", "dual.test:"+port2)
	var op *net.OpError
	fmt.Println("tcp6:", errors.As(err, &op) && op.Addr.(*net.TCPAddr).IP.String() == "::1")

	ln1.Close()
	ln2.Close()
	pc.Close()
}
