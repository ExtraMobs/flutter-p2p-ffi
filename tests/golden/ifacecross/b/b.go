// Package b declara interfaces que tipos de a (que não importa b) satisfazem.
package b

type Namer interface{ Hello() string }

func Greet(n Namer) string { return n.Hello() }

// Name acha a interface por type assertion e type switch.
func Name(x any) string {
	if n, ok := x.(Namer); ok {
		return "namer " + n.Hello()
	}
	return "?"
}

func Kind(x any) string {
	switch v := x.(type) {
	case interface{ Apply(int) int }:
		return "apply " + string(rune('0'+v.Apply(2)))
	case Namer:
		return "namer"
	}
	return "nada"
}

// Run recebe a interface anônima (a mesma de cmd: um tipo só no Go).
func Run(f interface{ Apply(int) int }, x int) int { return f.Apply(x) }
