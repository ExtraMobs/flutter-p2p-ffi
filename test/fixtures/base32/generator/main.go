package main

import (
 "encoding/hex"
 "encoding/json"
 "os"
 b32 "github.com/multiformats/go-base32"
)

func main() {
 rows := []map[string]any{}
 encodings := []*b32.Encoding{b32.StdEncoding, b32.HexEncoding, b32.RawStdEncoding, b32.RawHexEncoding}
 for mode, enc := range encodings {
  for n := 0; n <= 128; n++ {
   input := make([]byte, n)
   for i := range input { input[i] = byte(i*73 + n*19) }
   encoded := enc.EncodeToString(input)
   rows = append(rows, map[string]any{"mode": mode, "hex": hex.EncodeToString(input), "encoded": encoded})
  }
 }
 invalid := []map[string]any{}
 for mode, enc := range encodings {
  for _, input := range []string{"", "A", "AAA", "AAAAAA", "MY", "MY======", "my======", "MZ======", "MZXW6===", "MZXW6====", "MZXW6===!", "MY=====!", "MY=====", "MY=======", "MY======MY======", "MZXW6YTBMY=====!", "\r\nMY======\r\n", "MY===\n===", "MY\x00=====", "é", "!!!!!!!!", "========"} {
   decoded, err := enc.DecodeString(input)
   msg := ""
   if err != nil { msg = err.Error() }
   invalid = append(invalid, map[string]any{"mode": mode, "input": input, "hex": hex.EncodeToString(decoded), "error": msg})
  }
 }
 if err := json.NewEncoder(os.Stdout).Encode(map[string]any{"roundtrips": rows, "decodes": invalid}); err != nil { panic(err) }
}
