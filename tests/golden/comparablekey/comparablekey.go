// Interface com comparable embutido e métodos como constraint
// (github.com/cockroachdb/pebble/v2/internal/genericcache: type Key interface{ comparable; ... }).
package main

import "fmt"

type Key interface {
	comparable
	Shard(n int) int
}

type id int

func (i id) Shard(n int) int { return int(i) % n }

type Cache[K Key, V any] struct{ m map[K]V }

func (c *Cache[K, V]) Put(k K, v V) int {
	if c.m == nil {
		c.m = map[K]V{}
	}
	c.m[k] = v
	return k.Shard(4)
}

func main() {
	var c Cache[id, string]
	fmt.Println(c.Put(7, "x"), c.Put(9, "y"), len(c.m), c.m[7])
}
