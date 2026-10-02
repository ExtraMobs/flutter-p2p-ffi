// Shim os (recorte portável): Stdout/Stderr como *File, Getenv, erros
// sentinela, PathError, FileMode e Exit.
package main

import (
	"errors"
	"fmt"
	"io"
	"os"
)

func main() {
	os.Stdout.WriteString("via WriteString\n")
	os.Stdout.Write([]byte("via Write\n"))
	fmt.Fprintln(os.Stdout, "via Fprintln", 42)
	fmt.Fprintln(os.Stderr, "isto vai para stderr")
	os.Stderr.WriteString("stderr WriteString\n")
	var w io.Writer = os.Stdout
	io.WriteString(w, "via io.Writer\n")

	fmt.Printf("%q\n", os.Getenv("G2D_VARIAVEL_QUE_NAO_EXISTE"))
	v, ok := os.LookupEnv("G2D_VARIAVEL_QUE_NAO_EXISTE")
	fmt.Printf("%q %v\n", v, ok)
	fmt.Println(os.Getpid() > 0, len(os.Args))

	fmt.Println(os.ErrNotExist, "|", os.ErrExist, "|", os.ErrPermission, "|", os.ErrClosed, "|", os.ErrInvalid, "|", os.ErrDeadlineExceeded)
	fmt.Println(os.IsNotExist(os.ErrNotExist), os.IsExist(os.ErrNotExist), os.IsPermission(os.ErrPermission))
	fmt.Println(os.IsNotExist(nil), os.IsNotExist(errors.New("x")))

	pe := &os.PathError{Op: "open", Path: "/x/y", Err: os.ErrNotExist}
	fmt.Println(pe)
	fmt.Println(os.IsNotExist(pe), errors.Is(pe, os.ErrNotExist), errors.Is(pe, os.ErrExist))
	var target *os.PathError
	fmt.Println(errors.As(fmt.Errorf("wrap: %w", pe), &target), target.Path)
	fmt.Println(os.IsTimeout(os.ErrDeadlineExceeded), os.IsTimeout(pe))

	var m os.FileMode = 0o644
	fmt.Println(m, m.IsRegular(), m.IsDir(), m.Perm(), os.ModePerm)
	d := os.ModeDir | 0o755
	fmt.Println(d, d.IsDir(), d.IsRegular(), d.Type() == os.ModeDir, d.Perm())

	fmt.Println(os.Stdout.Name(), os.Stderr.Name(), os.Stdin.Fd(), os.Stdout.Fd())

	os.Stdout.WriteString("fim\n")
	os.Exit(0)
	fmt.Println("nunca")
}
