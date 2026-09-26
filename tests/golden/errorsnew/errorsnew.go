// Repro de github.com/pion/rtp/codecs/vp9 e pion/turn/v4/internal/ipnet:
// erros sentinela com errors.New, comparados por identidade.
package main

import (
	"errors"
	"fmt"
)

var (
	errShortPacket = errors.New("packet is not large enough")
	errTooMany     = errors.New("too many spatial layers")
)

type Header struct{ NS uint8 }

func (h *Header) Unmarshal(buf []byte) (int, error) {
	if len(buf) < 1 {
		return 0, errShortPacket
	}
	h.NS = buf[0] >> 5
	if h.NS > 4 {
		return 1, errTooMany
	}
	return 1, nil
}

func main() {
	var h Header
	for _, buf := range [][]byte{nil, {0xff}, {0x40}} {
		n, err := h.Unmarshal(buf)
		fmt.Println(n, err, err == errShortPacket, err == errTooMany, err == nil, h.NS)
	}
	a, b := errors.New("x"), errors.New("x")
	fmt.Println(a == b, a == a, a.Error() == b.Error())
	w := fmt.Errorf("unmarshal: %w", errShortPacket)
	fmt.Printf("%v|%s|%q\n", w, errTooMany, errTooMany)
}
