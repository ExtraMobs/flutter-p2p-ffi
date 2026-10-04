// Package main: switch com fallthrough e default em que todo case termina
// é terminal no Go (sem return depois); o Dart precisa ver o fim.
package main

import "fmt"

func kind(x int) (string, error) {
	switch x {
	case 0:
		return "zero", nil
	case 1:
		fallthrough
	default:
		return "outro", fmt.Errorf("x=%d", x)
	}
}

func main() {
	for _, x := range []int{0, 1, 2} {
		fmt.Println(kind(x))
	}
}
