// Package a: tipos com método não exportado promovidos por embedding em
// outro pacote (mixin T$Promote precisa atravessar a fronteira de library:
// TODO/P1-design-promocao-entre-pacotes).
package a

type T struct{ Name string }

func (t T) Hello() string  { return "hi " + t.Name }
func (t T) secret() string { return "a:" + t.Name }

type I interface{ secret() string }

func Reveal(i I) string { return i.secret() }

// T2: promovido por ponteiro embutido (*a.T2), método de valor e de
// ponteiro.
type T2 struct{ N int }

func (t *T2) Bump()     { t.N++ }
func (t T2) Value() int { return t.N }

// T3: promovido em profundidade 2 (a.T3 → b.Mid → c.C).
type T3 struct{ Tag string }

func (t T3) Label() string { return "t3:" + t.Tag }

// Kinded1 (com d.Kinded2): mesmo método exportado, mesma profundidade,
// embutidos juntos em outro pacote → ambíguo, o Go não promove.
type Kinded1 struct{}

func (Kinded1) Kind() string { return "k1" }

// Whisperer1 (com d.Whisperer2): método não exportado de mesmo nome só
// porque os dois pacotes de origem escreveram o mesmo identificador — não é
// ambíguo (identificador não exportado é por pacote), os dois promovem.
type Whisperer1 struct{ W string }

func (w Whisperer1) whisper() string { return "a:" + w.W }

type WhisperI1 interface{ whisper() string }

func Hear1(w WhisperI1) string { return w.whisper() }
