// Nomes exportados que só diferem por caixa (`FOO`/`Foo`, `BOOL`/`Bool`):
// no mesmo pacote e usados de outro pacote.
package main

import (
	"fmt"

	"g2d.test/foldnames/attr"
)

const FOO = 1
const Foo = 2

func HTTPServer() string { return "HTTPServer" }
func HttpServer() string { return "HttpServer" }

func main() {
	fmt.Println(FOO, Foo, HTTPServer(), HttpServer())
	for _, kv := range []attr.KeyValue{attr.Bool("b", true), attr.Int64("i", 7), attr.String("s", "x")} {
		fmt.Println(kv.Describe(), kv.Type == attr.BOOL, kv.Type == attr.STRING)
	}
	fmt.Println(attr.INVALID, attr.PDF, attr.Pdf)
	p := &attr.PDF
	*p = "x"
	fmt.Println(attr.PDF)
}
