// Package main exercita conversões string ↔ []byte/[]rune e range sobre
// string, incluindo UTF-8 inválido (U+FFFD com largura 1).
package main

import "fmt"

type Name string

func main() {
	s := "héllo, 世界 🌍"
	b := []byte(s)
	b[0] = 'H'
	fmt.Println(len(b), string(b), s)

	rs := []rune(s)
	rs[1] = 'e'
	fmt.Println(len(rs), string(rs), rs[7])

	for i, r := range s {
		fmt.Print(i, ":", string(r), " ")
	}
	fmt.Println()

	bad := string([]byte{0x61, 0xff, 0xe4, 0xb8, 0x62, 0xed, 0xa0, 0x80, 0xf0, 0x9f, 0x8c})
	for i, r := range bad {
		fmt.Print(i, "=", r, " ")
	}
	fmt.Println(len([]rune(bad)))

	n := 0
	for range "abc" {
		n++
	}
	for i := range "ab" {
		n += i
	}
	fmt.Println(n)

	fmt.Println(string([]rune{72, -1, 0xD800, 0x10FFFF + 1, 0x4E16}))
	name := Name("ñame")
	fmt.Println(len([]rune(name)), string(Name(string([]byte(name)))))
	for _, r := range name {
		if r == 'a' {
			continue
		}
		fmt.Print(string(r))
	}
	fmt.Println()
	fmt.Println(string([]byte(nil)) == "", len([]byte("")))
}
