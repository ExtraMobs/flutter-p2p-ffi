// Tipos nomeados sobre inteiros sem sinal (antes: base `UInt32Base`
// inexistente, Dart inválido; audit do kubo: go-fuse ioctl, dtls, zap...).
package main

import "fmt"

type Command uint32

func (c Command) Next() Command { return c + 1 }

type Color uint8

func (c Color) Invert() Color { return ^c }

type Port uint16

type Seq uint64

func (s *Seq) Inc() { *s++ }

type Size uint

type Addr uintptr

func main() {
	top := Command(0xFFFFFFFF)
	fmt.Println(Command(7).Next(), top.Next())
	c := Color(200)
	fmt.Println(Color(0x0F).Invert(), c+100)
	var p Port = 65535
	p++
	fmt.Println(p, Port(1)<<15)
	var s Seq = 1<<64 - 1
	s.Inc()
	fmt.Println(s)
	fmt.Println(Size(3)*Size(4), Addr(0x1000)+8)
	fmt.Println(uint32(Command(5)) + 1, Command(9) > Command(3))
}
