// reflect.Select e as operações de canal do reflect.Value (Send, Recv,
// TrySend, TryRecv, Close), ChanOf e MakeChan, com os panics do Go.
package main

import (
	"fmt"
	"reflect"
)

func try(name string, f func()) {
	defer func() { fmt.Println(name+":", recover()) }()
	f()
}

func main() {
	ch := make(chan int, 1)
	cases := []reflect.SelectCase{
		{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(ch)},
		{Dir: reflect.SelectDefault},
	}
	chosen, recv, ok := reflect.Select(cases)
	fmt.Println("default:", chosen, recv.IsValid(), ok)
	ch <- 7
	chosen, recv, ok = reflect.Select(cases)
	fmt.Println("recv:", chosen, recv, ok, recv.Type(), recv.CanSet())

	// Envio pronto (buffer livre) e canal nil (nunca pronto).
	var nilch chan int
	chosen, recv, ok = reflect.Select([]reflect.SelectCase{
		{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(nilch)},
		{Dir: reflect.SelectSend, Chan: reflect.ValueOf(ch), Send: reflect.ValueOf(9)},
		{Dir: reflect.SelectRecv},
	})
	fmt.Println("send:", chosen, recv.IsValid(), ok, <-ch)

	// Bloqueia até outra goroutine enviar (canal sem buffer).
	sch := make(chan string)
	done := make(chan bool)
	go func() {
		sch <- "hello"
		done <- true
	}()
	chosen, recv, ok = reflect.Select([]reflect.SelectCase{
		{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(nilch)},
		{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(sch)},
	})
	fmt.Println("blocked:", chosen, recv, ok)
	<-done

	// Bloqueia num envio até outra goroutine receber.
	go func() {
		fmt.Println("got:", <-sch)
		done <- true
	}()
	chosen, _, _ = reflect.Select([]reflect.SelectCase{
		{Dir: reflect.SelectSend, Chan: reflect.ValueOf(sch), Send: reflect.ValueOf("world")},
	})
	<-done
	fmt.Println("sent:", chosen)

	// Canal fechado: recv pronto com o zero value e ok=false.
	cl := make(chan *int)
	close(cl)
	chosen, recv, ok = reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(cl)}})
	fmt.Println("closed:", chosen, recv.IsValid(), recv.IsNil(), ok)

	// ChanOf e MakeChan.
	ct := reflect.ChanOf(reflect.BothDir, reflect.TypeOf(0))
	fmt.Println("chanof:", ct, ct == reflect.TypeOf(ch), ct.ChanDir(), ct.Elem())
	ro := reflect.ChanOf(reflect.RecvDir, reflect.TypeOf(0))
	fmt.Println(ro, reflect.ChanOf(reflect.SendDir, ro), reflect.ChanOf(reflect.BothDir, ro), reflect.ChanOf(reflect.RecvDir, ro))
	var roch <-chan int = ch
	fmt.Println("ro:", ro == reflect.TypeOf(roch))

	mc := reflect.MakeChan(ct, 2)
	mc.Send(reflect.ValueOf(1))
	fmt.Println("trysend:", mc.TrySend(reflect.ValueOf(2)), mc.TrySend(reflect.ValueOf(3)), mc.Len(), mc.Cap())
	x, xok := mc.Recv()
	fmt.Println("recv:", x, xok)
	x, xok = mc.TryRecv()
	fmt.Println("tryrecv:", x, xok)
	x, xok = mc.TryRecv()
	fmt.Println("empty:", x.IsValid(), xok)
	native := mc.Interface().(chan int)
	native <- 5
	x, xok = mc.Recv()
	fmt.Println("native:", x, xok)
	mc.Close()
	x, xok = mc.Recv()
	fmt.Println("after close:", x, xok)
	x, xok = mc.TryRecv()
	fmt.Println("tryrecv closed:", x, xok)
	x, xok = reflect.ValueOf(nilch).TryRecv()
	fmt.Println("nil tryrecv:", x.IsValid(), xok, reflect.ValueOf(nilch).TrySend(reflect.ValueOf(1)))

	// Recv bloqueante sobre canal sem buffer.
	uc := reflect.MakeChan(reflect.TypeOf(sch), 0)
	go func() {
		uc.Send(reflect.ValueOf("ping"))
		done <- true
	}()
	x, xok = uc.Recv()
	<-done
	fmt.Println("unbuffered:", x, xok)

	// Panics.
	try("dir", func() { reflect.Select([]reflect.SelectCase{{Dir: 0}}) })
	try("multidefault", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectDefault}, {Dir: reflect.SelectDefault}})
	})
	try("defaultchan", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectDefault, Chan: reflect.ValueOf(ch)}})
	})
	try("defaultsend", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectDefault, Send: reflect.ValueOf(1)}})
	})
	try("nosend", func() { reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectSend, Chan: reflect.ValueOf(ch)}}) })
	try("recvsend", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(ch), Send: reflect.ValueOf(1)}})
	})
	try("sendro", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectSend, Chan: reflect.ValueOf(roch), Send: reflect.ValueOf(1)}})
	})
	var soch chan<- int = ch
	try("recvso", func() { reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectRecv, Chan: reflect.ValueOf(soch)}}) })
	try("sendtype", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectSend, Chan: reflect.ValueOf(ch), Send: reflect.ValueOf("x")}})
	})
	try("sendclosed", func() {
		reflect.Select([]reflect.SelectCase{{Dir: reflect.SelectSend, Chan: reflect.ValueOf(cl), Send: reflect.ValueOf((*int)(nil))}})
	})
	try("valsendro", func() { reflect.ValueOf(roch).Send(reflect.ValueOf(1)) })
	try("valrecvso", func() { reflect.ValueOf(soch).Recv() })
	try("valclosero", func() { reflect.ValueOf(roch).Close() })
	try("valclose2", func() { mc.Close() })
	try("valsendtype", func() { reflect.ValueOf(ch).TrySend(reflect.ValueOf(1.5)) })
	try("valkind", func() { reflect.ValueOf(1).Recv() })
	try("makechan", func() { reflect.MakeChan(reflect.TypeOf(0), 1) })
	try("makechanneg", func() { reflect.MakeChan(ct, -1) })
	try("makechanro", func() { reflect.MakeChan(ro, 1) })
	try("chanofdir", func() { reflect.ChanOf(0, reflect.TypeOf(0)) })
}
