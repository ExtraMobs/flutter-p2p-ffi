package main

import (
	"errors"
	"fmt"
)

type T struct{ n int }

func (t *T) m(p *int, err error, done chan bool) {
	fmt.Println("m", t.n, p == nil, err == nil)
	if done != nil {
		done <- true
	}
}

func slice(p []byte, done chan bool) { fmt.Println("slice", p == nil, len(p)); done <- true }
func mp(m map[string]int, done chan bool) {
	fmt.Println("map", m == nil, len(m))
	done <- true
}
func ptr(p *T, done chan bool)        { fmt.Println("ptr", p == nil); done <- true }
func iface(e error, done chan bool)   { fmt.Println("iface", e == nil); done <- true }
func anyv(v any, done chan bool)      { fmt.Println("any", v == nil); done <- true }
func fn(f func() int, done chan bool) { fmt.Println("func", f == nil); done <- true }
func vari(done chan bool, xs ...error) {
	fmt.Println("vari", len(xs), xs[0] == nil, xs[1] == nil)
	done <- true
}
func variSlice(done chan bool, xs ...[]int) {
	fmt.Println("variSlice", xs == nil, len(xs))
	done <- true
}

func slicePrint(p []byte) { fmt.Println("defer slice", p == nil) }
func iface2(e error)      { fmt.Println("defer iface", e == nil) }

func deferred() (out string) {
	defer func() {
		if r := recover(); r != nil {
			out = fmt.Sprint("recovered: ", r)
		}
	}()
	defer slicePrint(nil)
	defer fmt.Println("defer println", nil, 1)
	t := &T{n: 7}
	defer t.m(nil, nil, nil)
	defer iface2(nil)
	var m map[string]int
	m["x"] = 1 // panic: assignment to entry in nil map
	return "unreachable"
}

func main() {
	done := make(chan bool)
	go slice(nil, done)
	<-done
	go mp(nil, done)
	<-done
	go ptr(nil, done)
	<-done
	go iface(nil, done)
	<-done
	go anyv(nil, done)
	<-done
	go fn(nil, done)
	<-done
	go vari(done, nil, errors.New("x"))
	<-done
	go variSlice(done, nil...)
	<-done
	go variSlice(done, nil, nil)
	<-done
	t := &T{n: 3}
	go t.m(nil, nil, done)
	<-done
	fmt.Println(deferred())
}
