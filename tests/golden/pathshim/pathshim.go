// Shim de path: Join variádico (com e sem `...`), Split (dois retornos),
// Match com ErrBadPattern (errors.Is), valor de função `path.Base`.
package main

import (
	"errors"
	"fmt"
	"path"
)

func main() {
	fmt.Println(path.Join("a", "../b", "c"), path.Join(), path.Join([]string{"/x", "", "y/"}...))
	dir, file := path.Split("static/myfile.css")
	fmt.Printf("%q %q\n", dir, file)
	fmt.Println(path.Clean("/../a//b/./c/.."), path.Ext("/a/b.tar.gz"), path.Dir("/a/b/"), path.IsAbs("/x"))
	base := path.Base
	fmt.Println(base("/a/b/"), base(""))
	ok, err := path.Match("*.go", "main.go")
	fmt.Println(ok, err)
	_, err = path.Match("[", "a")
	fmt.Println(err, errors.Is(err, path.ErrBadPattern))
}
