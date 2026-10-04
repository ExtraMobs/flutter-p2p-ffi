// Package main chama por reflexão funções e métodos que suspendem (cor
// `async`, D2): num contexto async o g2d usa `call$async`.
package main

import (
	"fmt"
	"reflect"
	"time"
)

type Svc struct{ n int }

func (s *Svc) Slow(d int) int {
	time.Sleep(time.Millisecond)
	s.n += d
	return s.n
}

func slow(x int) (int, error) {
	time.Sleep(time.Millisecond)
	return x * 2, nil
}

func fast(x int) int { return x + 1 }

func main() {
	time.Sleep(time.Millisecond)
	r := reflect.ValueOf(slow).Call([]reflect.Value{reflect.ValueOf(21)})
	fmt.Println(r[0], r[1].IsNil())
	fmt.Println(reflect.ValueOf(fast).Call([]reflect.Value{reflect.ValueOf(1)})[0])
	s := &Svc{}
	m := reflect.ValueOf(s).MethodByName("Slow")
	fmt.Println(m.Call([]reflect.Value{reflect.ValueOf(5)})[0], m.Type())
	ch := make(chan int)
	go func() {
		out := reflect.ValueOf(slow).Call([]reflect.Value{reflect.ValueOf(4)})
		ch <- int(out[0].Int())
	}()
	fmt.Println(<-ch)
}
