// Run with go run test/go_integer_vectors.go. Runtime variables avoid constant overflow.
package main

import (
 "encoding/json"
 "encoding/hex"
 "fmt"
)

func main() {
 u := ^uint64(0)
 min := int64(-9223372036854775808)
 max := int64(9223372036854775807)
 neg := int64(-5)
 divisor := int64(-1)
 s := string([]byte{255, 0, 195, 169})
 values := []string{
  fmt.Sprint(u), fmt.Sprint(u+1), fmt.Sprint(u*2), fmt.Sprint(u>>63),
  fmt.Sprint(u<<64), fmt.Sprint(u &^ 15),
  fmt.Sprint(max+1), fmt.Sprint(min-1), fmt.Sprint(min/divisor),
  fmt.Sprint(min%divisor), fmt.Sprint(neg/2), fmt.Sprint(neg%2),
  fmt.Sprint(neg>>64), fmt.Sprint(uint64(divisor)),
  fmt.Sprint(len(s)), fmt.Sprint(s[0]), hex.EncodeToString([]byte(s[2:3])),
  hex.EncodeToString([]byte(s + "a")), fmt.Sprint("\ue000" < "\U00010000"),
 }
 for _, code := range []int64{-1, 0, 127, 128, 0xd7ff, 0xd800, 0xdfff, 0xe000, 0x1f30d, 0x10ffff, 0x110000} {
  values = append(values, hex.EncodeToString([]byte(string(code))))
 }
 values = append(values, hex.EncodeToString([]byte(string(u))))
 wideRune := int64(4294967361)
 values = append(values, hex.EncodeToString([]byte(string(rune(wideRune)))),
  hex.EncodeToString([]byte(string(wideRune))))
 for _, a := range []bool{false,true} {
  for _, b := range []bool{false,true} {
   calls := 0
   rhs := func() bool { calls++; return b }
   result := a && rhs()
   values = append(values,fmt.Sprint(result),fmt.Sprint(calls))
   calls = 0
   result = a || rhs()
   values = append(values,fmt.Sprint(result),fmt.Sprint(calls),fmt.Sprint(!a))
  }
 }
 // Go specification example: sign extension precedes truncation.
 conversion := uint16(0x10f0)
 values = append(values,fmt.Sprint(uint32(int8(conversion))))
 for _,v:=range []int16{-32768,-129,-128,-1,0,127,128,255,32767}{
  values=append(values,fmt.Sprint(int8(v)),fmt.Sprint(uint8(v)),fmt.Sprint(uint64(v)))
 }
 data, err := json.Marshal(values)
 if err != nil { panic(err) }
 fmt.Println(string(data))
}
