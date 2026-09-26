// Receptor ponteiro reatribuído no corpo (`if s == nil { s = &T{} }`, de
// github.com/klauspost/compress/fse): a local do receptor não é final.
package main

import "fmt"

type Scratch struct{ n int }

// Receptor ponteiro reatribuído no corpo (klauspost/compress/fse).
func (s *Scratch) prepare(n int) *Scratch {
	if s == nil {
		s = &Scratch{}
	}
	s.n += n
	return s
}

func main() {
	var p *Scratch
	q := p.prepare(2)
	fmt.Println(p == nil, q.n)
	r := q.prepare(3)
	fmt.Println(r == q, r.n)
}
