// append([]byte, string...) e copy([]byte, string) (golang.org/x/net/dns/dnsmessage),
// com string nomeada, UTF-8 inválido e slice nomeado.
package main

import "fmt"

type Name string

type Buf []byte

func main() {
	b := []byte("ab")
	b = append(b, "cd"...)
	s := "ção"
	b = append(b, s...)
	var n Name = "!\xff"
	b = append(b, n...)
	fmt.Println(string(b), len(b))

	dst := make([]byte, 3)
	k := copy(dst, "xyz!")
	fmt.Println(k, string(dst))
	fmt.Println(copy(dst[1:], s), dst)
	var bb Buf
	bb = append(bb, "hi"...)
	fmt.Println(bb, copy(bb, n), bb, append([]byte(nil), ""...) == nil)
}
