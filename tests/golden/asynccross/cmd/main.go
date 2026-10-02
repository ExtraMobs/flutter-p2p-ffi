package main

import (
	"fmt"

	"g2d.test/asynccross/chanstore"
	"g2d.test/asynccross/store"
)

func main() {
	var s store.Store = chanstore.New(map[string]string{"a": "1", "b": "2"})
	fmt.Println(store.Lookup(s, "a"), store.Lookup(s, "b"))
	fmt.Println(store.Lookup(store.Mem{"c": "3"}, "c"))
}
