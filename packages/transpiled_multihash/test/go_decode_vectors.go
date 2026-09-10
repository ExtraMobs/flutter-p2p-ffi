package main

import (
 "encoding/hex"
 "encoding/json"
 "os"
 "strconv"
 mh "github.com/multiformats/go-multihash"
)

func main() {
 results := make([][]string, 0)
 for _, input := range os.Args[1:] {
  b, err := hex.DecodeString(input)
  if err != nil { panic(err) }
  decoded, err := mh.Decode(b)
  if err != nil {
   results = append(results, []string{"error", err.Error()})
  } else {
   results = append(results, []string{"ok", strconv.FormatUint(decoded.Code, 10), decoded.Name, hex.EncodeToString(decoded.Digest)})
  }
 }
 if err := json.NewEncoder(os.Stdout).Encode(results); err != nil { panic(err) }
}
