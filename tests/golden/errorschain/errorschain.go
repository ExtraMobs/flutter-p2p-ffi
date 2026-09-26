// errors.Is/As/Unwrap/Join/AsType: cadeia por Unwrap() error e []error, Is/As
// próprios, alvo ponteiro/interface/struct por valor, alvo não comparável e
// os pânicos do Go.
package main

import (
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("not found")

type PathError struct {
	Op, Path string
	Err      error
}

func (e *PathError) Error() string { return e.Op + " " + e.Path + ": " + e.Err.Error() }
func (e *PathError) Unwrap() error { return e.Err }

// Código de erro por valor, com Is próprio (casa por categoria).
type Code int

func (c Code) Error() string        { return fmt.Sprintf("code %d", int(c)) }
func (c Code) Is(target error) bool { t, ok := target.(Code); return ok && t/100 == c/100 }

type temporary interface{ Temporary() bool }

type tempErr interface {
	error
	Temporary() bool
}

type netErr struct{ msg string }

func (e netErr) Error() string   { return e.msg }
func (e netErr) Temporary() bool { return true }

// As próprio: preenche um netErr.
type named struct{ name string }

func (n *named) Error() string { return "named " + n.name }
func (n *named) As(target any) bool {
	if p, ok := target.(*netErr); ok {
		*p = netErr{"via As " + n.name}
		return true
	}
	return false
}

type multi struct{ errs []error }

func (m multi) Error() string   { return "multi" }
func (m multi) Unwrap() []error { return m.errs }

func try(f func()) (r any) {
	defer func() { r = recover() }()
	f()
	return
}

func main() {
	pe := &PathError{"open", "/x", ErrNotFound}
	wrapped := fmt.Errorf("load: %w", pe)
	fmt.Println(errors.Is(wrapped, ErrNotFound), errors.Is(wrapped, errors.New("not found")), errors.Unwrap(wrapped) == pe)
	var target *PathError
	fmt.Println(errors.As(wrapped, &target), target == pe, target.Path)

	fmt.Println(errors.Is(Code(404), Code(400)), errors.Is(Code(404), Code(500)), errors.Is(fmt.Errorf("x: %w", Code(403)), Code(401)))
	var c Code
	fmt.Println(errors.As(fmt.Errorf("w: %w", Code(502)), &c), c)

	var tmp temporary
	fmt.Println(errors.As(fmt.Errorf("n: %w", netErr{"timeout"}), &tmp), tmp.Temporary(), tmp)
	var ne netErr
	fmt.Println(errors.As(netErr{"v"}, &ne), ne.msg)
	var pne *netErr
	fmt.Println(errors.As(netErr{"v"}, &pne), pne == nil)

	var viaAs netErr
	fmt.Println(errors.As(fmt.Errorf("a: %w", &named{"zed"}), &viaAs), viaAs.msg)
	var s string
	fmt.Println(try(func() { errors.As(pe, &s) }))

	j := errors.Join(ErrNotFound, nil, Code(301))
	fmt.Printf("%q %v %v %v\n", j.Error(), errors.Is(j, ErrNotFound), errors.Is(j, Code(302)), errors.Unwrap(j) == nil)
	fmt.Println(errors.Join(nil, nil) == nil)
	two := fmt.Errorf("%w + %w", ErrNotFound, pe)
	var t2 *PathError
	fmt.Println(errors.Is(two, ErrNotFound), errors.As(two, &t2), t2.Op, errors.Unwrap(two) == nil)
	m := multi{[]error{Code(200), pe}}
	fmt.Println(errors.Is(m, ErrNotFound), errors.Is(m, Code(250)), errors.Is(m, multi{}))

	p1, ok1 := errors.AsType[*PathError](wrapped)
	c2, ok2 := errors.AsType[Code](wrapped)
	t3, ok3 := errors.AsType[tempErr](fmt.Errorf("q: %w", netErr{"slow"}))
	fmt.Println(p1 == pe, ok1, c2, ok2, t3, ok3)

	fmt.Println(try(func() { errors.As(pe, nil) }))
	fmt.Println(try(func() { var p *PathError; errors.As(pe, p) }))
	fmt.Println(errors.As(nil, &target), errors.Is(nil, nil), errors.Is(nil, ErrNotFound), errors.ErrUnsupported)
}
