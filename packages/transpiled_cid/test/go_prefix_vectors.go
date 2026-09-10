package main

import (
 "encoding/hex"
 "encoding/json"
 "os"
 "strconv"
 cid "github.com/ipfs/go-cid"
)

func main() {
 results := make([][]string, 0)
 for _, input := range os.Args[1:] {
  bytes, err := hex.DecodeString(input)
  if err != nil { panic(err) }
  p, err := cid.PrefixFromBytes(bytes)
  if err != nil { panic(err) }
  results = append(results, []string{
   strconv.FormatUint(p.Version, 10), strconv.FormatUint(p.Codec, 10),
   strconv.FormatUint(p.MhType, 10), strconv.Itoa(p.MhLength),
  })
 }
 if err := json.NewEncoder(os.Stdout).Encode(results); err != nil { panic(err) }
}
