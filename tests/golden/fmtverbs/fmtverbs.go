// fmt.Printf / Sprintf / Errorf: verbos, flags, largura, precisão e os
// erros de formato (%!verbo(...)). Audit do kubo: zap/internal/color
// ("\x1b[%dm%s\x1b[0m"), pion rtcerr ("...: %v"), dig digerror,
// otlptrace ("%s (%d %s rejected)"), go-base36 (%q), pebble (%016X).
package main

import "fmt"

type Color uint8

type Celsius float64

func (c Celsius) String() string { return fmt.Sprintf("%.1f°C", float64(c)) }

type P struct {
	X, Y int
	Name string
}

type myErr struct{ code int }

func (e *myErr) Error() string { return fmt.Sprintf("erro %d", e.code) }

func main() {
	// Inteiros: bases, sinais, largura, precisão, zero, #
	n, neg := 255, -42
	fmt.Printf("[%d] [%5d] [%-5d] [%05d] [%+d] [% d] [%x] [%X] [%o] [%O] [%b]\n", n, n, n, n, n, n, n, n, n, n, n)
	fmt.Printf("[%d] [%5d] [%05d] [%x] [%+d] [%.4d] [%8.4d] [%.0d] [%5.0d]\n", neg, neg, neg, neg, neg, n, n, 0, 0)
	fmt.Printf("[%#x] [%#X] [%#o] [%#b] [%#08x] [%08x] [%-8x|]\n", n, n, n, n, n, n, n)
	var u64 uint64 = 1<<64 - 1
	var i8 int8 = -128
	fmt.Printf("%d %x %d %x %016X\n", u64, u64, i8, i8, uint64(0xBEEF))
	fmt.Printf("%c %c %q %q %U %#U %c\n", 'A', 0x1F600, 'x', '\n', 0x1F600, 'é', -1)
	c := Color(31)
	fmt.Printf("\x1b[%dm%s\x1b[0m|%v|%T\n", c, "red", c, c)

	// Floats
	f := 3.14159265
	fmt.Printf("[%v] [%f] [%.2f] [%8.3f] [%-8.2f|] [%08.2f] [%+.1f] [% .1f]\n", f, f, f, f, f, f, f, f)
	fmt.Printf("[%e] [%E] [%.3e] [%g] [%G] [%.3g] [%.10g] [%g]\n", f, f, f, f, 1e21, f, f, 1e-7)
	fmt.Printf("[%.0f] [%.0f] [%.0f] [%.1f] [%.2f] [%f]\n", 0.5, 1.5, 2.5, 0.25, 1.005, 1e20)
	var f32 float32 = 0.1
	fmt.Printf("%v %f %.10f %g %e\n", f32, f32, f32, float64(f32), f32)
	var zero float64
	fmt.Printf("[%f] [%5.1f] [%+f] [%v] [%08.3f] [%-8f|]\n", 1/zero, -1/zero, zero/zero, zero/zero, -1/zero, zero/zero)
	fmt.Printf("%v %.2f %s\n", Celsius(21.456), Celsius(21.456), Celsius(-3))

	// Strings e bytes
	s := "olá, mundo"
	fmt.Printf("[%s] [%12s] [%-12s|] [%.3s] [%8.3s] [%q] [%x] [% x] [%#x] [%X]\n", s, s, s, s, s, s, "hi", "hi", "hi", "hi")
	fmt.Printf("[%q] [%+q] [%#q] [%#q] [%q]\n", "tab\there\"", "é\u00a0x", "raw", "has`tick", "\xff\x00")
	b := []byte("go!")
	fmt.Printf("[%s] [%q] [%x] [%v] [%d] [%5s]\n", b, b, b, b, b, b)
	fmt.Printf("[%05s] [%-05d|] [%t] [%v] [%5t]\n", "ab", 7, true, false, true)

	// Compostos: o verbo vale para cada elemento
	xs := []int{1, 22, 333}
	m := map[string]int{"b": 2, "a": 1}
	p := P{1, 2, "pt"}
	fmt.Printf("%v %d %3d %x %v %d %v %v\n", xs, xs, xs, xs, m, m, p, &p)
	fmt.Printf("%s %q %v %x\n", []string{"a", "b"}, []string{"a", "b"}, [2]bool{true, false}, []uint16{255, 4096})

	// nil, interfaces, erros e Stringers
	var e error
	var ip *int
	var ps *P
	fmt.Printf("%v %d %s %v %v\n", nil, nil, e, ip == nil, ps)
	var err error = &myErr{7}
	fmt.Printf("%v|%s|%q|%x|%d|%T\n", err, err, err, err, err.(*myErr).code, err)

	// %T
	fmt.Printf("%T %T %T %T %T %T %T\n", 1, "s", 2.5, true, c, uint8(1), float32(1))

	// Erros de formato
	fmt.Printf("%z %d %s\n", 1, "x", 2)
	fmt.Printf("%d %d\n", 1)
	fmt.Printf("%d\n", 1, "extra", nil, 3.5)
	fmt.Printf("%!|%-|%\n")
	fmt.Println()
	fmt.Printf("%*d|%-*d|%.*f|%*d\n", 5, 42, 4, 7, 2, 3.14159, "x", 1)
	fmt.Printf("100%% %5%|%w\n", err)

	// Sprintf e Errorf
	msg := fmt.Sprintf("OTLP partial success: %s (%d %s rejected)", "cheio", 3, "spans")
	fmt.Println(msg, len(msg))
	fmt.Println(fmt.Sprintf("invalid base36 character (%q)", 'z'))
	fmt.Println(fmt.Sprintf("UnknownError: %v", err))
	e1 := fmt.Errorf("falhou: %d", 5)
	e2 := fmt.Errorf("envolto: %w", err)
	e3 := fmt.Errorf("nil: %w", nil)
	e4 := fmt.Errorf("dois: %w e %w", e1, e2)
	e5 := fmt.Errorf("não-erro: %w", 42)
	fmt.Println(e1, "|", e2, "|", e3, "|", e4, "|", e5)
	fmt.Printf("%T %T %T %T\n", e1, e2, e3, e4)
	fmt.Println(e1 == e1, e1 != fmt.Errorf("falhou: %d", 5))

	written, _ := fmt.Printf("%s\n", "conta")
	fmt.Println(written)
}
