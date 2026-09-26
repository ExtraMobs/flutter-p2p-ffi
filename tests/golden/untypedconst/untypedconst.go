// Constante de pacote sem tipo usada em contexto tipado (audit do kubo:
// pion/interceptor/internal/sequencenumber, zeebo/blake3/internal/consts).
package main

import "fmt"

const (
	IV0 = 0x6A09E667
	IV1 = 0xBB67AE85
)

// Como o blake3: array de uint32 com constantes sem tipo.
var IV = [...]uint32{IV0, IV1}

const (
	maxSequenceNumberPlusOne = 65536
	breakpoint               = 32768 // metade do máximo de uint16
)

// Como o sequencenumber do pion.
func isNewer(value, previous uint16) bool {
	if value-previous == breakpoint {
		return value > previous
	}
	return value != previous && (value-previous) < breakpoint
}

type Unwrapper struct {
	init    bool
	lastRaw uint16
	lastExt int64
}

func (u *Unwrapper) Unwrap(i uint16) int64 {
	if !u.init {
		u.init = true
		u.lastRaw = i
		u.lastExt = int64(i)
		return u.lastExt
	}
	diff := int64(i) - int64(u.lastRaw)
	if isNewer(i, u.lastRaw) {
		if diff < 0 {
			diff += maxSequenceNumberPlusOne
		}
	} else if diff > 0 {
		diff -= maxSequenceNumberPlusOne
	}
	u.lastExt += diff
	u.lastRaw = i
	return u.lastExt
}

const ratio = 1.5

type Celsius float32

func main() {
	fmt.Println(IV[0], IV[1], IV0+1)
	fmt.Println(isNewer(40000, 1), isNewer(1, 65535), isNewer(5, 5))
	var u Unwrapper
	for _, s := range []uint16{65534, 65535, 0, 1, 65530} {
		fmt.Print(u.Unwrap(s), " ")
	}
	fmt.Println()
	var c Celsius = 20
	var f32 float32 = ratio
	fmt.Println(c*ratio, f32, ratio*2)
}
