// Repros de encoding/binary e crypto/subtle no grafo do kubo:
// github.com/pion/dtls/v3/internal/util, github.com/klauspost/compress/internal/le
// (genérico com constraint de união) e github.com/pion/transport/v4/utils/xor.
package main

import (
	"crypto/subtle"
	"encoding/binary"
	"fmt"
)

func BigEndianUint24(raw []byte) uint32 {
	if len(raw) < 3 {
		return 0
	}
	rawCopy := make([]byte, 4)
	copy(rawCopy[1:], raw)
	return binary.BigEndian.Uint32(rawCopy)
}

func PutBigEndianUint48(out []byte, in uint64) {
	tmp := make([]byte, 8)
	binary.BigEndian.PutUint64(tmp, in)
	copy(out, tmp[2:])
}

type Indexer interface {
	int | int8 | int16 | int32 | int64 | uint | uint8 | uint16 | uint32 | uint64
}

func Load32[I Indexer](b []byte, i I) uint32 {
	return binary.LittleEndian.Uint32(b[i:])
}

func Store64[I Indexer](b []byte, i I, v uint64) {
	binary.LittleEndian.PutUint64(b[i:], v)
}

func XorBytes(dst, a, b []byte) int {
	return subtle.XORBytes(dst, a, b)
}

func try(f func()) (msg any) {
	defer func() { msg = recover() }()
	f()
	return
}

func main() {
	b := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
	fmt.Println(BigEndianUint24(b), BigEndianUint24(b[:2]), Load32(b, 3), Load32(b, uint8(7)))
	fmt.Println(binary.LittleEndian.Uint16(b), binary.BigEndian.Uint16(b), binary.LittleEndian.Uint64(b[3:]), binary.BigEndian.Uint64(b))
	out := make([]byte, 6)
	PutBigEndianUint48(out, 0xfedcba9876543210)
	fmt.Println(out)
	Store64(b, int64(2), 0x8877665544332211)
	binary.LittleEndian.PutUint32(b, 0xdeadbeef)
	binary.BigEndian.PutUint16(b[9:], 0xabcd)
	fmt.Println(b)
	fmt.Println(try(func() { binary.BigEndian.Uint32(b[8:]) }))
	fmt.Println(try(func() { binary.LittleEndian.PutUint64(b[4:], 1) }))

	x, y := []byte{0xff, 0x0f, 0xaa, 0x55}, []byte{0x0f, 0xff, 0x55}
	dst := make([]byte, 4)
	fmt.Println(XorBytes(dst, x, y), dst)
	fmt.Println(XorBytes(x, x, y), x) // dst == x: sobreposição exata permitida
	fmt.Println(XorBytes(nil, x, nil))
	fmt.Println(try(func() { XorBytes(dst[:1], x, y) }))
	fmt.Println(try(func() { XorBytes(x[1:], x, y) }))
}
