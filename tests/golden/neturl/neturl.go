// Shim de net/url: Parse/String, campos de *URL, Userinfo, Query e Values
// (nomeado de shim sobre map: literal, make, conversão, range, len, índice,
// métodos, *Values), Encode, ResolveReference, erros (*url.Error com
// errors.As, net.Error, EscapeError), Hostname/Port, %v de *URL e de URL.
package main

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"sort"
)

type params = url.Values

func addAll(v *url.Values, kv ...string) {
	for i := 0; i+1 < len(kv); i += 2 {
		v.Add(kv[i], kv[i+1])
	}
}

func main() {
	u, err := url.Parse("https://user:pa%20ss@example.com:8443/a%2Fb/c d?q=1&q=2&x=y+z#frag%21")
	if err != nil {
		panic(err)
	}
	fmt.Println(u)
	fmt.Printf("%v|%s|%q\n", u, u, u.String())
	fmt.Println(u.Scheme, u.Host, u.Path, u.RawPath, u.RawQuery, u.Fragment, u.RawFragment, u.ForceQuery, u.OmitHost)
	fmt.Println(u.Hostname(), u.Port(), u.EscapedPath(), u.RequestURI(), u.Redacted(), u.IsAbs())
	pw, ok := u.User.Password()
	fmt.Println(u.User.Username(), pw, ok, u.User)

	q := u.Query()
	fmt.Println(len(q), q["q"], q.Get("x"), q.Get("nada"), q.Has("q"), q.Has("nada"))
	q.Set("z", "último & mais")
	q.Add("q", "3")
	q.Del("x")
	fmt.Println(q.Encode())
	u.RawQuery = q.Encode()
	fmt.Println(u.String())

	v := url.Values{"b": {"2", "1"}, "a": nil}
	v.Add("a", "x y")
	addAll(&v, "c", "/?", "c", "%")
	keys := make([]string, 0, len(v))
	for k := range v {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Println(keys, v.Encode())
	m := map[string][]string(v)
	p := params(m)
	fmt.Println(len(m), p.Get("b"))
	var empty url.Values
	fmt.Println(empty.Get("a"), empty.Encode() == "", empty == nil)
	made := make(url.Values)
	made["k"] = append(made["k"], "v")
	fmt.Println(made.Encode())

	pq, err := url.ParseQuery("a=1&b=%zz&c=3&d;e")
	fmt.Println(pq.Encode(), err)

	base, _ := url.Parse("http://a/b/c/d;p?q")
	for _, ref := range []string{"g", "./g/", "../..", "../../../g", "?y", "#s", "//g", "/./g", "g?y#s"} {
		r, err := url.Parse(ref)
		if err != nil {
			panic(err)
		}
		fmt.Print(base.ResolveReference(r), " ")
	}
	fmt.Println()
	rel, err := base.Parse("../x?k=v")
	fmt.Println(rel, err)
	fmt.Println(u.JoinPath("x", "../y/"))
	fmt.Println(url.JoinPath("http://h/a", "b", "c/"))

	for _, s := range []string{"http://[::1]:namedport", "%zz", "http://h/%", "1http://x", ":foo", "http://x\x01"} {
		_, err := url.Parse(s)
		var ue *url.Error
		if errors.As(err, &ue) {
			var ne net.Error
			fmt.Printf("%q | %s | %s | %v | %v %v\n", err, ue.Op, ue.URL, ue.Err, errors.As(err, &ne), ue.Timeout())
		}
	}
	_, err = url.QueryUnescape("a%2")
	var ee url.EscapeError
	fmt.Println(err, errors.As(err, &ee), string(ee))
	_, err = url.ParseRequestURI("rel/path")
	fmt.Println(err)

	for _, h := range []string{"example.com:80", "[::1]:443", "[fe80::1%25en0]", "host", "a:b"} {
		x := &url.URL{Host: h}
		fmt.Printf("%s=%s,%s ", h, x.Hostname(), x.Port())
	}
	fmt.Println()

	lit := url.URL{Scheme: "mailto", Opaque: "a@b.c"}
	fmt.Println(lit.String(), &lit)
	fmt.Println(url.QueryEscape("a b/c?d"), url.PathEscape("a b/c?d"), url.UserPassword("u", "p:@").String())
	var nilURL *url.URL
	fmt.Println(nilURL.Redacted() == "", url.User("só").String())
}
