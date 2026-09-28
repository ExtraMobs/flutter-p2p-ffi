// M4b: goroutines, canais e select — sem cor ainda (a cor entra em
// asynccolor/asynccross): tudo aqui roda direto em `main` (ou em goroutines
// `go func(){...}()`, que nunca precisam de `await` no `go` que as inicia),
// então nenhuma chamada a função nomeada precisa ser colorida.
// Determinístico: cada bloco sincroniza para não depender da ordem de
// escalonamento (produtor único, no máximo um case de select pronto por vez).
package main

import "fmt"

func main() {
	// Produtor/consumidor sem buffer: entrega direta, ordem garantida.
	{
		ch := make(chan int)
		done := make(chan bool)
		go func() {
			for i := 0; i < 3; i++ {
				ch <- i
			}
			close(ch)
		}()
		go func() {
			for v := range ch {
				fmt.Println("recv", v)
			}
			close(done)
		}()
		<-done
	}

	// Produtor/consumidor com buffer: envio não bloqueia até o buffer encher.
	{
		ch := make(chan int, 2)
		ch <- 10
		ch <- 20
		fmt.Println("buffered", len(ch), cap(ch))
		a, b := <-ch, <-ch
		fmt.Println(a, b)
	}

	// select com default: nunca bloqueia.
	{
		ch := make(chan int)
		select {
		case v := <-ch:
			fmt.Println("got", v)
		default:
			fmt.Println("no value")
		}
	}

	// select bloqueante: só ch1 recebe valor.
	{
		ch1 := make(chan string)
		ch2 := make(chan string)
		go func() { ch1 <- "one" }()
		select {
		case v := <-ch1:
			fmt.Println("select ch1", v)
		case v := <-ch2:
			fmt.Println("select ch2", v)
		}
	}

	// canal nil em select: nunca fica pronto.
	{
		var nilCh chan int
		ready := make(chan int, 1)
		ready <- 7
		select {
		case v := <-nilCh:
			fmt.Println("unreachable", v)
		case v := <-ready:
			fmt.Println("select ready", v)
		}
	}

	// select com case de envio.
	{
		ch := make(chan int, 1)
		select {
		case ch <- 5:
			fmt.Println("sent")
		default:
			fmt.Println("would block")
		}
		fmt.Println("value", <-ch)
	}

	// select com break: sai só do select (como no switch), não do for
	// externo — a linha depois do select roda normalmente.
	{
		ch := make(chan int, 1)
		ch <- 1
		for i := 0; i < 1; i++ {
			select {
			case v := <-ch:
				fmt.Println("before break", v)
				break
			}
			fmt.Println("depois do select")
		}
	}

	// panic numa goroutine, recuperado por ela mesma (defer+recover normal).
	{
		done := make(chan bool)
		go func() {
			defer func() {
				if r := recover(); r != nil {
					fmt.Println("recovered:", r)
				}
				close(done)
			}()
			panic("boom")
		}()
		<-done
	}

	// comma-ok em canal fechado (drenado e vazio).
	{
		ch := make(chan int, 1)
		ch <- 42
		close(ch)
		v, ok := <-ch
		fmt.Println(v, ok)
		v, ok = <-ch
		fmt.Println(v, ok)
	}

	// `go` com argumentos avaliados na hora (não quando a goroutine roda).
	{
		done := make(chan bool)
		x := 1
		go func(a int) {
			fmt.Println("goroutine viu", a)
			close(done)
		}(x)
		x = 2
		<-done
		fmt.Println("x depois", x)
	}

	fmt.Println("done")
}
