// String() de receptor ponteiro não vale para o valor (method set do Go).
package main

import "fmt"

type T struct{ n int }

func (t *T) String() string { return "T!" }

func main() {
	t := T{1}
	fmt.Println(t, &t)
	fmt.Printf("%v %v\n", t, &t)
}
