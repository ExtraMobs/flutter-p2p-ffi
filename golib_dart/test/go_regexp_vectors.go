// Oráculo do shim regexp: padrões (válidos e inválidos) × entradas (inclusive
// UTF-8 inválido). Saída: JSON {"pats":[hex...],"inputs":[hex...],"res":[...],
// "pkg":[...]}; o Dart recalcula cada linha com o mesmo formato
// (`regexp_test.dart`).
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var pats = []string{
	``, `a`, `abc`, `a*`, `a+`, `a?`, `a*?`, `a+?`, `a??`, `a{2}`, `a{2,}`, `a{2,3}`, `a{2,3}?`, `a{0}`, `a{,2}`, `a{`, `x{1001}`,
	`(a)(b)?`, `(a|b)*`, `(a*)*`, `(a*)+`, `(a|ab)(c|bcd)(d*)`, `a|ab`, `ab|a`, `(?:a|ab)(?:c|bcd)`, `(|a)+`, `(a|)+`,
	`^abc$`, `^`, `$`, `(?m)^b$`, `(?m)^`, `(?m)$`, `\Aabc\z`, `\bfoo\b`, `\Bo\B`, `\b`, `\B`, `(?s).`, `.`, `(?s)a.b`, `a.b`,
	`[abc]`, `[^abc]`, `[a-c]+`, `[^a-c]+`, `[]a]`, `[^]a]`, `[a-]`, `[-a]`, `[a\-c]`, `[\d\s]+`, `[\D]+`, `\d+`, `\D+`, `\s+`, `\S+`, `\w+`, `\W+`,
	`[[:alpha:]]+`, `[[:^alpha:]]+`, `[[:digit:][:space:]]+`, `[[:upper:]]`, `[[:word:]]+`, `[[:xdigit:]]+`, `[[:punct:]]`, `[[:foo:]]`, `[[:alpha:]`,
	`(?i)abc`, `(?i)k`, `(?i)s`, `(?i)[a-c]+`, `(?i)[^a-c]+`, `(?i:a)b`, `(?-i)a`, `(?i)(?-i)a`, `(?i)(?-i:a)A`, `(?s:.)`, `(?U)a+`, `(?U)a+?`, `(?Ui)A*`, `(?i-s)a`, `(?:)`, `(?i)`, `(?-)`, `(?i-)`, `(?--i)`, `(?z)`,
	`(?P<first>a)(?P<second>b)?`, `(?<x>a)(?<y>b)`, `(?P<n>a)(?P<n>b)`, `(?P<n`, `(?P<>a)`, `(?P<a-b>x)`, `(?P=n)`, `(?P>n)`, `(?<=a)b`, `(?=a)`, `(?!a)`, `(?`, `(?P`, `(?P<`,
	`\x41`, `\x{263a}`, `\x{110000}`, `\x{}`, `\x4`, `\xZZ`, `\101`, `\0`, `\08`, `\1`, `\8`, `\a\f\t\n\r\v`, `\.`, `\Q.*\E+`, `\Qab`, `\Q\E`, `\Z`, `\z`, `\y`, `\`, `\C`,
	`\pL+`, `\p{Greek}+`, `\p{Lu}`, `\PL+`, `\P{Lu}+`, `\p{^Lu}`, `\p{^Greek}`, `[\pL\d]+`, `[^\pL]+`, `\pZ`, `\p{Foo}`, `\pX`, `\p{L`, `\p`, `\p{Han}`, `\p{Any}`, `[\p{Greek}x]`,
	`(`, `)`, `a)`, `(a`, `((a)`, `a(b`, `*`, `+a`, `?`, `a|*`, `(*)`, `(?:*)`, `a**`, `a*+`, `a+*`, `a*??`, `a{2}{3}`, `a{2}*`, `(a{2}){3}`, `^*`, `$*`, `\b*`, `(?i)*`, `a(?i)*`,
	`[`, `[a`, `[a-`, `[z-a]`, `[a-\d]`, `[\d-z]`, `[a-a]`, `[\n]`, `[^\n]`, `[\]]`, `[\\]`, `[[]`, `[a[:digit:]]`,
	`(a{1000}){1000}`, `(a{10}){100}`, `((a{10}){10}){10}`, `a{1000}`,
	`日本語`, `[日本]+`, `.+`, `(?s).+`, `a.c`, `[^a]`, `é`, `(?i)é`, `(?i)Σ`, `(?i)ǅ`,
	`(\w+)@(\w+)\.com`, `(\d+)-(\d+)`, `(?P<year>\d{4})-(?P<month>\d{2})`, `^(\w+)\s*=\s*(.*)$`, `(?m)^(\w+):\s*(.*)$`, `a(b(c)?)*d`, `(a+)(b+)?(c+)?`, `x*`, `(x*)`, `\w*`, `(\w)*`,
	"a\xffb", "[\xff]", "(?i)\xff",
	`(?i)k+`, `(?i)s+`, `(?i)[k]+`, `(?i)[^k]+`, `(?i)σ+`, `(?i)Σ+`, `(?i)ς+`, `(?i)[σ]+`, `(?i)\W+`, `(?i)\w+`, `(?i)\D+`, `(?i)[[:upper:]]+`, `(?i)[^[:lower:]]+`,
	`(?i)\p{Lu}+`, `(?i)\p{Ll}+`, `(?i)\P{Lu}+`, `(?i)\p{Greek}+`, `(?i)[\p{Lu}]+`, `(?i)ǆ+`, `(?i)ß`, `(?i)ẞ`, `(?i)Å+`, `(?i)µ+`, `(?i)ᲀ+`,
	`\p{Lu}+`, `\p{Ll}+`, `\pN+`, `\p{Nd}+`, `\p{Han}+`, `\p{Latin}+`, `\p{Cyrillic}+`, `\p{Greek}`, `\p{Common}+`, `\p{Zs}`, `\p{Sc}`, `\p{Cn}`, `\p{LC}`, `\p{Letter}`, `\pC`, `\p{Arabic}+`, `\p{Hiragana}+`, `[^\p{Greek}]+`, `[\P{L}]+`, `\p{han}`,
}

var inputs = []string{
	``, `a`, `b`, `abc`, `aaa`, `aaaa`, `abcd`, `ab`, `abab`, "a\nb\nc", "abc\n", "\nabc", `foo bar foobar`, `foo`,
	`xyz 123 abc-9`, `a.b a-b`, `hello_world 42`, `日本語text`, `éÉσΣςǆǅǄ`, `αβγ abc ΑΒΓ`,
	"kKK sSſ", `me@example.com, you@test.com`, `2024-05 and 1999-12`, "key: value\nother: thing\n", "x = 1\ny=2",
	`aab`, `abbcc`, `ac`, `baaab`, "a\xffb", "\xff\xfe", "ab\xe6\x97", `{[()]}\.+*?|^$`, `1234567890`,
}

func hx(s string) string { return hex.EncodeToString([]byte(s)) }

func hxs(a []string) string {
	if a == nil {
		return "nil"
	}
	var p []string
	for _, s := range a {
		p = append(p, hx(s))
	}
	return "[" + strings.Join(p, ",") + "]"
}

func hxss(a [][]string) string {
	if a == nil {
		return "nil"
	}
	var p []string
	for _, s := range a {
		p = append(p, hxs(s))
	}
	return "[" + strings.Join(p, ",") + "]"
}

func ints(a []int) string {
	if a == nil {
		return "nil"
	}
	return fmt.Sprint(a)
}

func intss(a [][]int) string {
	if a == nil {
		return "nil"
	}
	return fmt.Sprint(a)
}

func hxb(b []byte) string {
	if b == nil {
		return "nil"
	}
	return hx(string(b))
}

func hxbs(bs [][]byte) string {
	if bs == nil {
		return "nil"
	}
	var p []string
	for _, b := range bs {
		p = append(p, hxb(b))
	}
	return "[" + strings.Join(p, ",") + "]"
}

func run(pat, in string) []string {
	re, err := regexp.Compile(pat)
	if err != nil {
		var msg string
		func() {
			defer func() { msg = fmt.Sprint(recover()) }()
			regexp.MustCompile(pat)
		}()
		return []string{"ERR " + hx(err.Error()) + " | " + hx(msg)}
	}
	b := []byte(in)
	tpl := "<$0|${1}|$x|$$|$1x|${first}|$>"
	return []string{
		fmt.Sprintf("ns=%d names=%s str=%s", re.NumSubexp(), hxs(re.SubexpNames()), hx(re.String())),
		fmt.Sprint(re.MatchString(in), re.Match(b)),
		ints(re.FindStringIndex(in)) + " " + ints(re.FindIndex(b)),
		ints(re.FindStringSubmatchIndex(in)) + " " + ints(re.FindSubmatchIndex(b)),
		intss(re.FindAllStringSubmatchIndex(in, -1)),
		intss(re.FindAllStringIndex(in, 3)) + " " + intss(re.FindAllIndex(b, -1)),
		hx(re.FindString(in)) + " " + hxb(re.Find(b)),
		hxs(re.FindStringSubmatch(in)) + " " + hxbs(re.FindSubmatch(b)),
		hxs(re.FindAllString(in, -1)) + " " + hxss(re.FindAllStringSubmatch(in, 2)),
		hx(re.ReplaceAllString(in, tpl)) + " " + hx(string(re.ReplaceAll(b, []byte(tpl)))),
		hx(re.ReplaceAllLiteralString(in, "$1")) + " " + hx(string(re.ReplaceAllLiteral(b, []byte("$1")))),
		hx(re.ReplaceAllStringFunc(in, func(m string) string { return "[" + m + "]" })),
		hxs(re.Split(in, -1)) + " " + hxs(re.Split(in, 2)) + " " + hxs(re.Split(in, 0)),
		hx(string(re.ExpandString([]byte("pre:"), tpl, in, re.FindStringSubmatchIndex(in)))),
		fmt.Sprint(re.SubexpIndex("first"), re.SubexpIndex("x"), re.SubexpIndex("")),
	}
}

func main() {
	var res []string
	for pi, p := range pats {
		for ii, in := range inputs {
			if _, err := regexp.Compile(p); err != nil && ii > 0 {
				continue
			}
			for k, line := range run(p, in) {
				res = append(res, fmt.Sprintf("%d/%d/%d %s", pi, ii, k, line))
			}
		}
	}
	var hp, hi []string
	for _, p := range pats {
		hp = append(hp, hx(p))
	}
	for _, s := range inputs {
		hi = append(hi, hx(s))
	}
	var pkg []string
	for _, s := range []string{"", "a.b", `\.+*?()|[]{}^$`, "日本", "a\xffb", "-_ a"} {
		pkg = append(pkg, hx(regexp.QuoteMeta(s)))
	}
	ok, err := regexp.MatchString(`^a+b$`, "aaab")
	pkg = append(pkg, fmt.Sprint(ok, err))
	ok, err = regexp.Match(`(`, []byte("x"))
	pkg = append(pkg, fmt.Sprintf("%v %s", ok, hx(err.Error())))
	json.NewEncoder(os.Stdout).Encode(map[string]any{"pats": hp, "inputs": hi, "res": res, "pkg": pkg})
}
