// bytes.Buffer (porta do Go 1.26: Cap/Available iguais), io.EOF, io.Reader e
// io.Writer do usuário (interfaces de shim), fmt.Fprint.
package main

import (
	"bytes"
	"fmt"
	"io"
	"strings"
)

// chunks é um io.Reader do usuário que entrega de 3 em 3 bytes.
type chunks struct{ data []byte }

func (c *chunks) Read(p []byte) (int, error) {
	if len(c.data) == 0 {
		return 0, io.EOF
	}
	n := copy(p, c.data[:min(3, len(c.data))])
	c.data = c.data[n:]
	return n, nil
}

type sink struct{ got []string }

func (s *sink) Write(p []byte) (int, error) {
	s.got = append(s.got, string(p))
	return len(p), nil
}

func main() {
	var b bytes.Buffer
	fmt.Println(b.Len(), b.Cap(), b.String() == "")
	b.WriteString("hello")
	b.WriteByte(' ')
	b.WriteRune('→')
	b.Write([]byte("world\nline2\n"))
	fmt.Println(b.Len(), b.Cap(), b.Available())
	line, err := b.ReadString('\n')
	fmt.Printf("%q %v\n", line, err)
	c, _ := b.ReadByte()
	fmt.Println(string(c), b.UnreadByte(), b.UnreadByte() != nil)
	r, size, _ := b.ReadRune()
	fmt.Println(string(r), size, b.UnreadRune())
	rest, err := b.ReadBytes('!')
	fmt.Printf("%q %v %v\n", rest, err, err == io.EOF)
	_, err = b.ReadByte()
	fmt.Println(err == io.EOF, b.Len())

	b.Grow(200)
	fmt.Println(b.Cap())
	n, err := b.ReadFrom(&chunks{[]byte("abcdefgh")})
	fmt.Println(n, err, b.String(), b.Cap())
	s := &sink{}
	m, err := b.WriteTo(s)
	fmt.Println(m, err, s.got, b.Len())

	nb := bytes.NewBufferString("xyz")
	fmt.Println(nb, nb.Next(2), nb.String())
	nb.Truncate(0)
	fmt.Println(nb.Len(), bytes.NewBuffer([]byte("ab")).String())
	var w io.Writer = &b
	fmt.Fprint(w, "")
	var sb strings.Builder
	var sw io.StringWriter = &sb
	sw.WriteString("via interface")
	fmt.Println(sb.String())
	big := bytes.NewBuffer(make([]byte, 0, 10))
	for i := 0; i < 5; i++ {
		big.WriteString("0123456789")
		fmt.Print(big.Cap(), " ")
	}
	fmt.Println()
}
