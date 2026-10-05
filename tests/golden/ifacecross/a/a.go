// Package a não importa b, sort nem nenhum pacote que declare as interfaces
// que os tipos dele satisfazem: o Go as satisfaz estruturalmente.
package a

type T struct{ Name string }

func (t T) Hello() string { return "hi " + t.Name }

// P só satisfaz b.Namer como *P (receptor ponteiro).
type P struct{ n int }

func (p *P) Hello() string { p.n++; return "p" + string(rune('0'+p.n)) }

func NewP() *P { return &P{} }

// U só vira `any` (nunca b.Namer direto): b o encontra por type assertion.
type U struct{}

func (U) Hello() string { return "u" }

// Ints satisfaz sort.Interface sem importar sort.
type Ints []int

func (s Ints) Len() int           { return len(s) }
func (s Ints) Less(i, j int) bool { return s[i] < s[j] }
func (s Ints) Swap(i, j int)      { s[i], s[j] = s[j], s[i] }

// Op satisfaz a interface anônima `interface{ Apply(int) int }` de b.
type Op int

func (o Op) Apply(x int) int { return x * int(o) }

// Src satisfaz io.Reader sem importar io (interface dual do D2).
type Src struct {
	s string
	i int
}

type doneErr struct{}

func (doneErr) Error() string { return "fim" }

func NewSrc(s string) *Src { return &Src{s: s} }

func (r *Src) Read(p []byte) (int, error) {
	if r.i >= len(r.s) {
		return 0, doneErr{}
	}
	n := copy(p, r.s[r.i:])
	r.i += n
	return n, nil
}
