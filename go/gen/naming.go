package main

import (
	"strings"
	"unicode"
)

// Nomes Go → Dart pelas regras de "Preservação da API" (branch archive):
// tipos UpperCamelCase e membros lowerCamelCase, siglas como palavras
// (CoreAPI → CoreApi, PeerID → peerId, HTTPServer → httpServer).

// words quebra um identificador Go em palavras: "CoreAPI" → [Core API],
// "HTTPServer" → [HTTP Server], "MD5Sum" → [MD5 Sum], "cidV1" → [cid V1].
func words(name string) []string {
	r := []rune(name)
	var out []string
	start := 0
	for i := 1; i < len(r); i++ {
		prev, cur := r[i-1], r[i]
		next := rune(0)
		if i+1 < len(r) {
			next = r[i+1]
		}
		boundary := (unicode.IsLower(prev) && unicode.IsUpper(cur)) ||
			(unicode.IsDigit(prev) && unicode.IsUpper(cur) && unicode.IsLower(next)) ||
			(unicode.IsUpper(prev) && unicode.IsUpper(cur) && unicode.IsLower(next)) ||
			cur == '_'
		if boundary {
			if s := strings.Trim(string(r[start:i]), "_"); s != "" {
				out = append(out, s)
			}
			start = i
		}
	}
	if s := strings.Trim(string(r[start:]), "_"); s != "" {
		out = append(out, s)
	}
	return out
}

func capitalize(w string) string {
	w = strings.ToLower(w)
	return strings.ToUpper(w[:1]) + w[1:]
}

// typeName: nome de classe Dart.
func typeName(goName string) string {
	var b strings.Builder
	for _, w := range words(goName) {
		b.WriteString(capitalize(w))
	}
	return escapeType(b.String())
}

// memberName: função, método, campo ou parâmetro Dart.
func memberName(goName string) string {
	ws := words(goName)
	if len(ws) == 0 {
		return goName
	}
	var b strings.Builder
	b.WriteString(strings.ToLower(ws[0]))
	for _, w := range ws[1:] {
		b.WriteString(capitalize(w))
	}
	return escapeMember(b.String())
}

var dartReserved = setOf(`assert break case catch class const continue default do else enum extends
false final finally for if in is new null rethrow return super switch this throw true try var void
while with`)

// Nomes do dart:core que uma classe gerada sombrearia.
var dartCoreTypes = setOf(`Object String List Map Set BigInt Function Null Never Iterable Uint8List
Future Stream Type Error Exception Duration DateTime Uri Symbol Record Enum Pattern RegExp Sink
Comparable Iterator Invocation Expando`)

// Membros que toda classe gerada já tem (Object, GoHandle, GoValue).
var dartBaseMembers = setOf(`hashCode runtimeType toString noSuchMethod value`)

// dartParamName: parâmetro Dart. Só as palavras reservadas escapam: o receptor é
// sempre um handle, sem os membros de GoValue (value) que um parâmetro
// esconderia.
func dartParamName(goName string) string {
	n := strings.TrimSuffix(memberName(goName), "$")
	if dartReserved[n] {
		return n + "$"
	}
	return n
}

func escapeMember(s string) string {
	if dartReserved[s] || dartBaseMembers[s] {
		return s + "$"
	}
	return s
}

func escapeType(s string) string {
	if dartCoreTypes[s] {
		return s + "$"
	}
	return s
}

func setOf(s string) map[string]bool {
	m := map[string]bool{}
	for _, w := range strings.Fields(s) {
		m[w] = true
	}
	return m
}
