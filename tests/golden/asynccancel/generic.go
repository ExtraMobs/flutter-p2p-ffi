package main

import (
	"fmt"
	"sync"
)

// Métodos e campos func() de um tipo genérico não prendem a classe func():
// só o que cita o parâmetro de tipo (`func(T)`) tem formato fixo.
type queue[T any] struct {
	items   []T
	onEmpty func()
}

func (q *queue[T]) push(x T) { q.items = append(q.items, x) }

func (q *queue[T]) drain(each func(T)) {
	for _, x := range q.items {
		each(x)
	}
	q.items = nil
	q.onEmpty()
}

// T = func(): o valor é um T opaco dentro do genérico (como no fx).
func runHook[T any](hook T) {
	switch f := any(hook).(type) {
	case func():
		f()
	}
}

func generics(log chan string) {
	q := &queue[int]{onEmpty: func() { log <- "vazia" }}
	q.push(1)
	q.push(2)
	q.drain(func(x int) { fmt.Println("item", x) })
	runHook(func() { log <- "hook" })
	once := sync.OnceFunc(func() { log <- "uma vez" })
	once()
	once()
}
