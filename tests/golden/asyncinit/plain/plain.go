// Package plain não suspende: o $goInit dele continua síncrono, mesmo
// importado por quem é async.
package plain

import "fmt"

var Greeting = "olá"

func init() { fmt.Println("plain.init") }
