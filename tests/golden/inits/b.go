package main

import "fmt"

var fromB = compute("fromB", total+1) // depende de total, de a.go

func init() {
	fmt.Println("init b")
	registry["b"] = 2
}
