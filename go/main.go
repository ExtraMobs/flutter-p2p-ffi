// Package main é o p2p_host: o kubo num processo só dele, que o app (Dart)
// lança e com quem fala por memória compartilhada (host.go, WIRE.md). A API
// exposta é gerada por gen/ a partir de gen/roots.txt (zz_generated.go); as
// funções escritas à mão estão em manual_*.go. Compila sem cgo
// (CGO_ENABLED=0; ver tool/build.dart).
package main

func main() { runHost() }
