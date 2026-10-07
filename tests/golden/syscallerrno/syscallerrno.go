// Shim syscall: Errno numérico com a numeração do linux, a cadeia real de
// erro da rede (*net.OpError → *os.SyscallError → syscall.Errno), Error/
// Timeout/Temporary/Is, igualdade com constante dentro de interface,
// conversões, errors.As e type switch.
package main

import (
	"errors"
	"fmt"
	"io/fs"
	"net"
	"os"
	"strings"
	"syscall"
)

// wrapped embrulha um erro (tipo gerado na cadeia do errors.Is).
type wrapped struct{ err error }

func (w *wrapped) Error() string { return "wrapped: " + w.err.Error() }
func (w *wrapped) Unwrap() error { return w.err }

func kind(err error) string {
	switch e := err.(type) {
	case nil:
		return "nil"
	case syscall.Errno:
		return fmt.Sprintf("Errno(%d)", int(e))
	case *os.SyscallError:
		return "SyscallError(" + e.Syscall + ")"
	case *net.OpError:
		return "OpError(" + e.Op + ")"
	default:
		return fmt.Sprintf("outro %T", e)
	}
}

func chain(err error) {
	for err != nil {
		fmt.Printf("  %T: %s\n", err, kind(err))
		err = errors.Unwrap(err)
	}
}

func props(e syscall.Errno) {
	fmt.Printf("%d %q timeout=%v temporary=%v\n", uintptr(e), e.Error(), e.Timeout(), e.Temporary())
}

func main() {
	// Conexão recusada numa porta que acabou de fechar.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	addr := ln.Addr().String()
	ln.Close()
	_, err = net.Dial("tcp", addr)
	fmt.Println("refused:", errors.Is(err, syscall.ECONNREFUSED), errors.Is(err, syscall.ECONNRESET))
	fmt.Println("sufixo:", strings.HasSuffix(err.Error(), "connect: connection refused"))
	chain(err)
	var errno syscall.Errno
	if errors.As(err, &errno) {
		fmt.Println("As:", errno == syscall.ECONNREFUSED, int(errno), errno)
	}
	var se *os.SyscallError
	if errors.As(err, &se) {
		fmt.Printf("SyscallError: %s %v %T\n", se.Syscall, se.Err, se.Err)
		fmt.Println("  == const:", se.Err == syscall.ECONNREFUSED, se.Err == error(syscall.Errno(111)))
	}
	var ne net.Error
	fmt.Println("net.Error:", errors.As(err, &ne), ne.Timeout())

	// Errno solto: Error/Timeout/Temporary.
	props(syscall.Errno(11))
	props(syscall.EAGAIN)
	props(syscall.EWOULDBLOCK)
	props(syscall.ETIMEDOUT)
	props(syscall.EINTR)
	props(syscall.ENOENT)
	props(syscall.Errno(0))
	props(syscall.Errno(200))
	props(syscall.ENOTSUP)
	fmt.Println(syscall.EAGAIN == syscall.EWOULDBLOCK, syscall.ENOTSUP == syscall.EOPNOTSUPP)

	// Is: os erros portáveis.
	var target error = syscall.ENOENT
	fmt.Println("Is:", errors.Is(target, fs.ErrNotExist), errors.Is(target, os.ErrNotExist),
		errors.Is(syscall.EEXIST, fs.ErrExist), errors.Is(syscall.ENOTEMPTY, os.ErrExist),
		errors.Is(syscall.EACCES, fs.ErrPermission), errors.Is(syscall.EPERM, os.ErrPermission),
		errors.Is(syscall.ENOSYS, errors.ErrUnsupported), errors.Is(syscall.EOPNOTSUPP, errors.ErrUnsupported),
		errors.Is(syscall.EINVAL, fs.ErrNotExist))
	pe := &os.SyscallError{Syscall: "open", Err: syscall.ENOENT}
	fmt.Println("os.Is*:", os.IsNotExist(pe), os.IsExist(pe), os.IsNotExist(syscall.ENOENT),
		os.IsPermission(&os.SyscallError{Syscall: "x", Err: syscall.EACCES}))
	w := &wrapped{err: os.NewSyscallError("read", syscall.ECONNRESET)}
	fmt.Println(w, errors.Is(w, syscall.ECONNRESET), errors.Is(w, syscall.ECONNABORTED))
	chain(w)

	// Igualdade dentro de interface, map com Errno e conversões.
	var a, b error = syscall.Errno(111), syscall.ECONNREFUSED
	fmt.Println("iface ==:", a == b, a == syscall.ECONNRESET, a != nil)
	seen := map[error]int{syscall.EAGAIN: 1}
	seen[syscall.Errno(11)]++
	fmt.Println("map:", len(seen), seen[syscall.EWOULDBLOCK])
	n := int(syscall.EADDRINUSE)
	e := syscall.Errno(n + 1)
	fmt.Println("conv:", n, e, e == syscall.EADDRNOTAVAIL, uint64(e)*2)
	fmt.Printf("%v|%d|%s|%x|%T\n", syscall.EPIPE, syscall.EPIPE, syscall.EPIPE, uintptr(syscall.EPIPE), syscall.EPIPE)
	if ne, ok := error(syscall.ETIMEDOUT).(net.Error); ok {
		fmt.Println("net.Error assert:", ne.Timeout(), ne.Temporary())
	}
	if t, ok := error(syscall.EMFILE).(interface{ Temporary() bool }); ok {
		fmt.Println("Temporary assert:", t.Temporary())
	}
	fmt.Println(kind(syscall.EBADF), kind(nil), kind(errors.New("x")))
	fmt.Println(syscall.AF_INET, syscall.AF_INET6, syscall.SOCK_STREAM|syscall.SOCK_NONBLOCK|syscall.SOCK_CLOEXEC,
		syscall.SOL_SOCKET, syscall.SO_REUSEADDR, syscall.IPPROTO_UDP, syscall.IP_MTU_DISCOVER,
		syscall.IPV6_V6ONLY, syscall.SOMAXCONN)
}
