// Package registry recebe registros feitos no init de outros pacotes.
package registry

var Names []string

func Register(name string) { Names = append(Names, name) }
