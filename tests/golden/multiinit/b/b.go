// Package b conta a ordem de inicialização do programa inteiro.
package b

import "fmt"

var Order []string

func Next(who string) int {
	Order = append(Order, who)
	return len(Order)
}

var First = Next("b.First")

func init() { fmt.Println("init b", First) }
