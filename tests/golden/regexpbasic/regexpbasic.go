// regexp (shim): MustCompile/Compile, casamentos, índices em bytes (UTF-8),
// grupos nomeados, expansão $1/${name}, Replace*, Split, QuoteMeta e erros
// de sintaxe com a mensagem do Go.
package main

import (
	"fmt"
	"regexp"
)

var kv = regexp.MustCompile(`^(\w+)\s*=\s*(.*)$`)

var date = regexp.MustCompile(`(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})`)

func try(expr string) {
	defer func() { fmt.Println("recover:", recover()) }()
	regexp.MustCompile(expr)
}

func main() {
	fmt.Println(kv.MatchString("name = value"), kv.MatchString("=x"))
	fmt.Printf("%q\n", kv.FindStringSubmatch("name = value"))
	fmt.Println(kv.FindStringSubmatchIndex("name = value"), kv.NumSubexp())
	fmt.Println(kv, kv.String())

	fmt.Printf("%q\n", date.SubexpNames())
	fmt.Println(date.SubexpIndex("month"), date.SubexpIndex("nope"))
	fmt.Println(date.ReplaceAllString("on 2024-05-17 and 1999-12-31", "${day}/${month}/$year"))
	fmt.Println(date.ReplaceAllString("2024-05-17", "$1x|$$|${1}x|$9|$"))
	fmt.Println(date.ReplaceAllLiteralString("2024-05-17", "$1"))
	fmt.Println(date.ReplaceAllStringFunc("a 2024-05-17 b", func(m string) string { return "<" + m + ">" }))

	// Índices em bytes, não em runas.
	u := regexp.MustCompile(`日+|é`)
	s := "aé日日b日"
	fmt.Println(u.FindStringIndex(s), u.FindAllStringIndex(s, -1))
	fmt.Printf("%q\n", u.FindAllString(s, 2))

	// Casamentos vazios.
	e := regexp.MustCompile(`a*`)
	fmt.Printf("%q\n", e.FindAllString("baaab", -1))
	fmt.Println(e.FindAllStringIndex("baaab", -1))
	fmt.Println(e.ReplaceAllString("baaab", "-"))
	fmt.Printf("%q\n", regexp.MustCompile(`,\s*`).Split("a, b,c,   d", -1))
	fmt.Printf("%q\n", regexp.MustCompile(`x*`).Split("axbxxc", -1))
	fmt.Printf("%q\n", regexp.MustCompile(`,`).Split("a,b,c", 2))

	// Leftmost-first e preguiçoso.
	fmt.Println(regexp.MustCompile(`a|ab`).FindString("ab"))
	fmt.Println(regexp.MustCompile(`a+?`).FindString("aaa"), regexp.MustCompile(`(?U)a+`).FindString("aaa"))
	fmt.Printf("%q\n", regexp.MustCompile(`(a+)(b+)?`).FindStringSubmatch("aac"))
	fmt.Println(regexp.MustCompile(`(?i)straSSe`).MatchString("STRAsse"))
	fmt.Println(regexp.MustCompile(`[[:alpha:]]+|\pN+|\p{Greek}+`).FindAllString("abc 123 αβγ", -1))
	fmt.Println(regexp.MustCompile(`(?m)^\w+$`).FindAllString("one\ntwo three\nfour", -1))

	// Bytes.
	b := []byte("foo=1, bar=22")
	pair := regexp.MustCompile(`(\w+)=(\d+)`)
	fmt.Printf("%s\n", pair.Find(b))
	fmt.Printf("%q\n", pair.FindSubmatch(b))
	fmt.Printf("%s\n", pair.ReplaceAll(b, []byte("$2:$1")))
	fmt.Printf("%s\n", pair.ReplaceAllLiteral(b, []byte("$1")))
	fmt.Println(pair.Match(b), pair.Match([]byte("none")))
	fmt.Printf("%s\n", pair.ExpandString([]byte(">"), "$1<-$2", "foo=1", pair.FindStringSubmatchIndex("foo=1")))
	fmt.Printf("%q\n", pair.FindAllStringSubmatch("a=1 b=2 c=3", -1))
	fmt.Println(pair.FindAllStringSubmatchIndex("a=1 b=2 c=3", 2))

	fmt.Println(regexp.QuoteMeta(`a.b*c[d]`))
	m, err := regexp.MatchString(`^\d+$`, "12345")
	fmt.Println(m, err)

	// Erros.
	_, err = regexp.Compile(`a(b`)
	fmt.Println(err)
	_, err = regexp.Compile(`a**`)
	fmt.Println(err)
	_, err = regexp.Compile(`(?<=x)y`)
	fmt.Println(err)
	_, err = regexp.Compile(`\1`)
	fmt.Println(err)
	try(`[z-a]`)
	try(`x{1001}`)
}
