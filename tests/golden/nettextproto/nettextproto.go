// Package main exercita o shim parcial de net/textproto: MIMEHeader (Add,
// Set, Get, Values, Del) com chaves não canônicas, CanonicalMIMEHeaderKey,
// TrimString/TrimBytes, ProtocolError e Error.
package main

import (
	"errors"
	"fmt"
	"net/textproto"
	"sort"
	"strings"
)

func dump(h textproto.MIMEHeader) {
	keys := make([]string, 0, len(h))
	for k := range h {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Printf("%s: %q\n", k, h[k])
	}
}

func main() {
	for _, k := range []string{"a-b-c", "a-1-c", "User-Agent", "uSER-aGENT", "user-agent", "USER-AGENT",
		"foo-bar_baz", "foo bar", "foo-bar ", "Content-Type", "", "üser-agent", "WWW-Authenticate",
		"a b", "C Ontent-Transfer-Encoding", "content-length", "x-my-header", "-x", "x--y"} {
		fmt.Printf("%q -> %q\n", k, textproto.CanonicalMIMEHeaderKey(k))
	}

	h := textproto.MIMEHeader{}
	h.Add("content-type", "text/plain")
	h.Add("CONTENT-TYPE", "charset=utf-8")
	h.Set("x-request-id", "42")
	h.Add("accept", "  */*  ")
	h["raw key"] = []string{"kept"}
	fmt.Println(h.Get("Content-Type"), h.Get("missing") == "", len(h.Values("content-type")))
	fmt.Printf("%q %q\n", h.Values("Accept"), h.Values("nope"))
	fmt.Println(textproto.TrimString(h.Get("accept")))
	dump(h)
	h.Del("X-Request-Id")
	h.Set("content-type", "application/json")
	dump(h)

	var nilh textproto.MIMEHeader
	fmt.Println(nilh.Get("a") == "", nilh.Values("a") == nil, len(nilh))

	line := "  Host:   example.com \r\n"
	i := strings.Index(line, ":")
	key := textproto.CanonicalMIMEHeaderKey(textproto.TrimString(line[:i]))
	val := textproto.TrimString(line[i+1:])
	fmt.Printf("%q=%q\n", key, val)
	fmt.Printf("%q %q\n", textproto.TrimString("\t \r\n"), string(textproto.TrimBytes([]byte("\n x y \t"))))

	var err error = textproto.ProtocolError("bad line")
	fmt.Println(err)
	err = &textproto.Error{Code: 5, Msg: "nope \"x\""}
	fmt.Println(err)
	var te *textproto.Error
	fmt.Println(errors.As(err, &te), te.Code, te.Msg)
}
