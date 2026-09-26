// Repros de strconv (inteiros) no grafo do kubo: github.com/multiformats/go-multicodec
// (ParseUint base 0, FormatInt), go-multiaddr/x/meg e hanwen/go-fuse/v2/internal (Itoa).
package main

import (
	"fmt"
	"strconv"
)

type Code uint64

func (c *Code) Set(text string) error {
	if n, err := strconv.ParseUint(text, 0, 64); err == nil {
		code := Code(n)
		if code >= 0x300000 && code <= 0x3FFFFF {
			*c = code
			return nil
		}
		return fmt.Errorf("unknown multicodec code: %s", text)
	} else {
		return err
	}
}

func (i Code) String() string {
	if i == 0x55 {
		return "raw"
	}
	return "Code(" + strconv.FormatInt(int64(i), 10) + ")"
}

func main() {
	for _, s := range []string{"0x300001", "0o14000001", "3145729", "0x55", "0x3_00_002", "0x_300001", "x", "", "99999999999999999999"} {
		var c Code
		err := c.Set(s)
		fmt.Println(s, c, err)
	}
	fmt.Println(Code(0x55), Code(7), strconv.Itoa(-12), strconv.Itoa(0), strconv.FormatUint(1<<63, 16), strconv.FormatInt(-255, 2))
	for _, s := range []string{"12", "-9223372036854775808", "9223372036854775808", "+7", "1e3"} {
		n, err := strconv.Atoi(s)
		i, err2 := strconv.ParseInt(s, 10, 8)
		fmt.Println(n, err, i, err2)
	}
}
