// Interface anônima de um método testada contra valores das classes dos
// shims (D8): `interface{ Unwrap() error }`, `Timeout() bool`... são as
// interfaces do runtime (`go.Unwrapper`, `go.Timeouter`), que os shims e os
// tipos gerados declaram.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
)

type timeoutErr struct{}

func (timeoutErr) Error() string   { return "t" }
func (timeoutErr) Timeout() bool   { return true }
func (timeoutErr) Temporary() bool { return false }

func main() {
	var err error = context.DeadlineExceeded
	_, ok := err.(interface{ Timeout() bool })
	fmt.Println("assert:", ok)
	if t, ok := err.(interface{ Temporary() bool }); ok {
		fmt.Println("temporary:", t.Temporary())
	}

	w := fmt.Errorf("x: %w", io.EOF)
	u, ok := w.(interface{ Unwrap() error })
	fmt.Println("unwrap:", ok, u.Unwrap() == io.EOF)

	if t, ok := error(timeoutErr{}).(interface{ Timeout() bool }); ok {
		fmt.Println("local:", t.Timeout())
	}
	j := errors.Join(io.EOF, os.ErrClosed)
	_, ok = j.(interface{ Unwrap() []error })
	fmt.Println("join:", ok)
	fmt.Println(os.IsTimeout(timeoutErr{}), os.IsTimeout(io.EOF))
}
