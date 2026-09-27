// Package d: contrapartida de a.Kinded1/a.Whisperer1 para exercitar
// ambiguidade (Kind, exportado) e a "vantagem" da privacidade por library
// (whisper, não exportado, mesmo nome em pacotes diferentes).
package d

type Kinded2 struct{}

func (Kinded2) Kind() string { return "k2" }

type Whisperer2 struct{ W string }

func (w Whisperer2) whisper() string { return "d:" + w.W }

type WhisperI2 interface{ whisper() string }

func Hear2(w WhisperI2) string { return w.whisper() }
