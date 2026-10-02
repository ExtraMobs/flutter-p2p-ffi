package main

import (
	"fmt"

	"g2d.test/asyncinit/conf"
	"g2d.test/asyncinit/plain"
)

var ready = make(chan bool, 1)

func init() {
	ready <- true
	fmt.Println("main.init")
}

func main() {
	fmt.Println(plain.Greeting, conf.Total, conf.Names, <-ready)
}
