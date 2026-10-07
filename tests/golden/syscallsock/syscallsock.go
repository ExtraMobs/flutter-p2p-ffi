// Funções de socket do shim syscall pela libc (plano D10, etapa E2):
// Socketpair, Read/Write (com EAGAIN no fd não bloqueante), SetsockoptInt,
// GetsockoptInt e Close, com os erros do linux (EBADF, ENOPROTOOPT,
// EAFNOSUPPORT).
//
// No Node não há descritor (F4, syscallsock.node.out): Socketpair, Read,
// Write e Close dão "operation not supported", e as opções, "protocol not
// available".
package main

import (
	"errors"
	"fmt"
	"syscall"
)

func main() {
	fds, err := syscall.Socketpair(syscall.AF_UNIX, syscall.SOCK_STREAM|syscall.SOCK_NONBLOCK|syscall.SOCK_CLOEXEC, 0)
	fmt.Println("socketpair:", fds[0] != fds[1], err)
	a, b := fds[0], fds[1]

	n, err := syscall.Write(a, []byte("ping"))
	fmt.Println("write:", n, err)
	buf := make([]byte, 16)
	n, err = syscall.Read(b, buf)
	fmt.Println("read:", n, string(buf[:max(n, 0)]), err)

	// Nada para ler num fd não bloqueante: EAGAIN (== EWOULDBLOCK).
	n, err = syscall.Read(b, buf)
	fmt.Println("read empty:", n, err, err == syscall.EAGAIN, errors.Is(err, syscall.EWOULDBLOCK))

	// Opções de socket.
	err = syscall.SetsockoptInt(a, syscall.SOL_SOCKET, syscall.SO_KEEPALIVE, 1)
	v, err2 := syscall.GetsockoptInt(a, syscall.SOL_SOCKET, syscall.SO_KEEPALIVE)
	fmt.Println("keepalive:", v, err, err2)
	v, err = syscall.GetsockoptInt(a, syscall.SOL_SOCKET, syscall.SO_TYPE)
	fmt.Println("type:", v, err)
	v, err = syscall.GetsockoptInt(a, syscall.SOL_SOCKET, 9999)
	fmt.Println("unknown option:", v, err, err == syscall.ENOPROTOOPT)
	fmt.Println("unknown set:", syscall.SetsockoptInt(a, syscall.SOL_SOCKET, 9999, 1))

	// Fechar um lado: o outro lê EOF (0, nil).
	fmt.Println("close:", syscall.Close(a))
	n, err = syscall.Read(b, buf)
	fmt.Println("read eof:", n, err)
	fmt.Println("close b:", syscall.Close(b))

	// Descritor inválido e família inexistente.
	n, err = syscall.Write(-1, []byte("x"))
	fmt.Println("write badfd:", n, err, err == syscall.EBADF)
	v, err = syscall.GetsockoptInt(-1, syscall.SOL_SOCKET, syscall.SO_TYPE)
	fmt.Println("badfd:", v, err)
	bad, err := syscall.Socketpair(99, syscall.SOCK_STREAM, 0)
	fmt.Println("bad family:", bad, err)
}
