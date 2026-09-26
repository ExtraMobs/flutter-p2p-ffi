// encoding/binary completo para o grafo: varints (snappy, protobuf), ByteOrder
// (Append*, String, NativeEndian, o tipo não exportado de `var NBO =
// binary.BigEndian` do go-msgio), Read/Write sem reflexão (go-msgio,
// klauspost/compress/zstd) e io.ReadFull/ReadAtLeast/ReadAll/WriteString.
package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
)

var NBO = binary.BigEndian

type decSymbol uint64

type rec struct {
	A uint16
	B int32
	_ uint8
	C float64
	D [2]int8
}

func ff(n int) []byte {
	b := make([]byte, n)
	for i := range b {
		b[i] = 0xff
	}
	return b
}

func main() {
	// Varints (snappy, protobuf).
	buf := make([]byte, binary.MaxVarintLen64)
	for _, x := range []uint64{0, 1, 127, 128, 300, 1 << 35, 1<<64 - 1} {
		n := binary.PutUvarint(buf, x)
		v, m := binary.Uvarint(buf[:n])
		fmt.Println(x, buf[:n], v, m)
	}
	for _, x := range []int64{0, -1, 1, -64, 63, -1 << 63, 1<<63 - 1} {
		b := binary.AppendVarint(nil, x)
		v, m := binary.Varint(b)
		fmt.Println(x, b, v, m, binary.PutVarint(buf, x))
	}
	fmt.Println(binary.Uvarint([]byte{0x80, 0x80}))
	fmt.Println(binary.Uvarint(ff(11)))
	v, err := binary.ReadUvarint(bytes.NewBuffer([]byte{0xac, 0x02}))
	fmt.Println(v, err)
	_, err = binary.ReadUvarint(bytes.NewBuffer([]byte{0xac}))
	fmt.Println(err)
	_, err = binary.ReadUvarint(bytes.NewBuffer(nil))
	fmt.Println(err)

	// ByteOrder.
	fmt.Println(NBO, binary.LittleEndian, binary.NativeEndian)
	fmt.Println(NBO.AppendUint32([]byte{9}, 0x01020304), binary.LittleEndian.AppendUint16(nil, 0xabcd),
		binary.BigEndian.AppendUint64(nil, 1<<63|5))

	// Write/Read (go-msgio, klauspost/compress/zstd).
	var w bytes.Buffer
	ul := uint32(0xdeadbeef)
	fmt.Println(binary.Write(&w, NBO, &ul), w.Bytes())
	fmt.Println(binary.Write(&w, binary.LittleEndian, []int16{-2, 3}), w.Bytes())
	fmt.Println(binary.Write(&w, binary.LittleEndian, rec{A: 1, B: -2, C: 1.5, D: [2]int8{-1, 2}}), w.Len())
	fmt.Println(binary.Write(&w, binary.LittleEndian, 5))
	r := bytes.NewBuffer(append([]byte(nil), w.Bytes()...))
	var got uint32
	var pair [2]int16
	fmt.Println(binary.Read(r, NBO, &got), got == ul)
	fmt.Println(binary.Read(r, binary.LittleEndian, pair[:]), pair)
	var dt [3]decSymbol
	var sl uint16
	var tl uint8
	r2 := bytes.NewBuffer([]byte{1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 128, 3, 0, 0, 0, 0, 0, 0, 0, 7, 1, 9})
	fmt.Println(binary.Read(r2, binary.LittleEndian, &dt), dt)
	fmt.Println(binary.Read(r2, binary.LittleEndian, &sl), sl)
	fmt.Println(binary.Read(r2, binary.LittleEndian, &tl), tl)
	fmt.Println(binary.Read(r2, binary.LittleEndian, &tl), tl)
	var f32 float32
	fmt.Println(binary.Read(bytes.NewBuffer([]byte{0, 0, 0xc0, 0x3f}), binary.LittleEndian, &f32), f32)
	var n int
	fmt.Println(binary.Read(bytes.NewBuffer([]byte{1}), binary.LittleEndian, &n))

	// io.
	b4 := make([]byte, 4)
	k, err := io.ReadFull(bytes.NewBuffer([]byte{1, 2}), b4)
	fmt.Println(k, err, b4)
	k, err = io.ReadAtLeast(bytes.NewBuffer([]byte{1, 2, 3}), b4, 2)
	fmt.Println(k, err)
	_, err = io.ReadAtLeast(bytes.NewBuffer(nil), b4, 5)
	fmt.Println(err)
	all, err := io.ReadAll(bytes.NewBuffer(ff(1000)))
	fmt.Println(len(all), cap(all), err)
	k, err = io.WriteString(&w, "xyz")
	fmt.Println(k, err, w.Len())
	k, err = io.WriteString(io.Discard, "abc")
	fmt.Println(k, err)
}
