// Oráculo do shim net/textproto: canonicalHeaderKeyTests (header_test.go),
// alguns commonHeader de reader.go e, para cada byte c, as chaves "xc-y" e
// "c-Y" passam por CanonicalMIMEHeaderKey e TrimString/TrimBytes. Strings
// viram listas de bytes (podem não ser UTF-8). Saída: JSON
// {"in":[...],"canon":[...],"trim":[...]}; o Dart recalcula
// (`textproto_test.dart`).
package main

import (
	"encoding/json"
	"net/textproto"
	"os"
)

var inputs = []string{
	"a-b-c", "a-1-c", "User-Agent", "uSER-aGENT", "user-agent", "USER-AGENT",
	"foo-bar_baz", "foo-bar$baz", "foo-bar~baz", "foo-bar*baz", "üser-agenT", "a B",
	"C Ontent-Transfer-Encoding", "foo bar", "", " ", "-", "--a--", "x--Y", "WWW-Authenticate",
	"Accept-Charset", "content-md5", "x-forwarded-for", "Mime-version", "dkim-signature",
	" \t a b \r\n", "\r\n", "\x0b x \x0c", "\n\t \r", "abc", "  abc", "abc  ",
}

func bs(s string) []int {
	out := []int{}
	for i := 0; i < len(s); i++ {
		out = append(out, int(s[i]))
	}
	return out
}

func main() {
	for c := 0; c < 256; c++ {
		inputs = append(inputs, "x"+string([]byte{byte(c)})+"-y", string([]byte{byte(c)})+"-Y")
	}
	var in, canon, trim [][]int
	for _, s := range inputs {
		in = append(in, bs(s))
		canon = append(canon, bs(textproto.CanonicalMIMEHeaderKey(s)))
		t := textproto.TrimString(s)
		if string(textproto.TrimBytes([]byte(s))) != t {
			panic("TrimBytes != TrimString")
		}
		trim = append(trim, bs(t))
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"in": in, "canon": canon, "trim": trim})
}
