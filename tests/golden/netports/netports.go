// Portas por nome no shim net (decisão D4, S3): a tabela embutida do Go
// completada pelo /etc/services (o arquivo vence; aliases contam), a rede
// "ip" (tcp e depois udp), o parsePort do Go (sinal, estouro) e os erros.
// O /etc/services é o da máquina: o oráculo e o Dart leem o mesmo.
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
)

func show(what string, port int, err error) {
	var de *net.DNSError
	var ae *net.AddrError
	switch {
	case errors.As(err, &de):
		fmt.Printf("%s: %d DNSError %q %q notfound=%v\n", what, port, de.Err, de.Name, de.IsNotFound)
	case errors.As(err, &ae):
		fmt.Printf("%s: %d AddrError %q %q\n", what, port, ae.Err, ae.Addr)
	default:
		fmt.Printf("%s: %d %v\n", what, port, err)
	}
}

func main() {
	cases := [][2]string{
		{"tcp", "http"}, {"tcp", "HTTP"}, {"tcp", "www"}, {"tcp4", "ssh"}, {"udp", "domain"},
		{"tcp", "domain"}, {"udp6", "ntp"}, {"tcp", "ntp"}, {"ip", "ntp"}, {"ip", "http"},
		{"", "https"}, {"udp", "http"}, {"tcp", "kerberos5"}, {"sctp", "http"},
		{"tcp", "nao-existe"}, {"tcp", "um-nome-de-servico-longo-demais-para-o-buffer"},
		{"tcp", "8080"}, {"tcp", "+80"}, {"tcp", "-1"}, {"tcp", "65536"}, {"tcp", "99999999999"},
		{"tcp", ""}, {"tcp", "+"}, {"tcp", "1x"},
	}
	for _, c := range cases {
		p, err := net.LookupPort(c[0], c[1])
		show(c[0]+"/"+c[1], p, err)
	}
	var r net.Resolver
	p, err := r.LookupPort(context.Background(), "tcp", "imaps")
	show("resolver imaps", p, err)

	a, err := net.ResolveTCPAddr("tcp", "127.0.0.1:www")
	fmt.Println(a, err)
	u, err := net.ResolveUDPAddr("udp", "127.0.0.1:ntp")
	fmt.Println(u, err)
	_, err = net.ResolveTCPAddr("tcp", "127.0.0.1:nao-existe")
	fmt.Println(err)
}
