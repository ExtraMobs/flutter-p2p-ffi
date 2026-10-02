//go:build ignore

// Oráculo de `timer_forgotten.dart`: um timer de canal esquecido (ninguém
// espera em `t.C`) não impede o deadlock no Go ≥ 1.23; um `Sleep`, sim.
package main

import (
	"fmt"
	"time"
)

func main() {
	t := time.NewTimer(time.Hour)
	tk := time.NewTicker(time.Hour)
	_, _ = t, tk
	go func() {
		time.Sleep(20 * time.Millisecond)
		fmt.Println("acordou")
	}()
	fmt.Println("bloqueia")
	<-make(chan int)
}
