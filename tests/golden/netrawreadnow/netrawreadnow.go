// syscall.Read no fd do SyscallConn de uma conexão TCP lê o que já está no
// kernel, mesmo antes de o programa ter dado a vez ao poller: o dado chega
// por loopback durante o Write do par, e uma espera ocupada (sem ceder) segura
// o laço de eventos. Na VM a conexão é do dart:io e o fd é virtual: o
// syscall.Read tenta o RawSocket.read sem esperar o evento de leitura.
//
// No Node (F4/F5, netrawreadnow.node.out) não há descritor: syscall.Read e o
// RawConn.Read dão "operation not supported".
package main

import (
	"fmt"
	"net"
	"syscall"
	"time"
)

func busy() {
	for t := time.Now(); time.Since(t) < 30*time.Millisecond; {
	}
}

func main() {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	acc := make(chan net.Conn)
	go func() {
		c, _ := ln.Accept()
		acc <- c
	}()
	conn, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		panic(err)
	}
	srv := <-acc
	raw, err := conn.(*net.TCPConn).SyscallConn()
	fmt.Println("syscallconn:", err)

	buf := make([]byte, 16)
	var n int
	var rerr error
	str := func() string {
		if n <= 0 {
			return ""
		}
		return string(buf[:n])
	}

	srv.Write([]byte("hello"))
	busy()
	cerr := raw.Control(func(fd uintptr) { n, rerr = syscall.Read(int(fd), buf) })
	fmt.Printf("control: %d %q %v %v\n", n, str(), rerr, cerr)

	srv.Write([]byte("world"))
	busy()
	err = raw.Read(func(fd uintptr) bool {
		n, rerr = syscall.Read(int(fd), buf)
		return true
	})
	fmt.Printf("one-shot: %d %q %v %v\n", n, str(), rerr, err != nil)

	// Sem dado: EAGAIN.
	cerr = raw.Control(func(fd uintptr) { n, rerr = syscall.Read(int(fd), buf) })
	fmt.Printf("vazio: %d %v %v\n", n, rerr, cerr)

	// Parte pelo syscall.Read, o resto pelo Read normal.
	srv.Write([]byte("abcdefghij"))
	busy()
	cerr = raw.Control(func(fd uintptr) { n, rerr = syscall.Read(int(fd), buf[:4]) })
	fmt.Printf("parcial: %d %q %v %v", n, str(), rerr, cerr)
	n, err = conn.Read(buf)
	fmt.Printf(" / resto: %d %q %v\n", n, str(), err)

	srv.Close()
	conn.Close()
	ln.Close()
}
