package main

import (
 "encoding/json"
 "os"
)

// All operands are runtime values. JSON numbers are deliberately decimal strings.
func main() {
 rows := []any{}
 signed := []int8{-128, -127, -65, -5, -1, 0, 1, 2, 65, 127}
 unsigned := []uint8{0, 1, 2, 65, 127, 128, 255}
 for _, x := range signed {
  for _, y := range signed {
   row := []any{x+y,x-y,x*y,x&y,x|y,x^y,x&^y,x==y,x<y,x<=y,x>y,x>=y}
   if y != 0 { row = append(row,x/y,x%y) }
   rows = append(rows, row)
  }
  for _, shift := range []uint{0,1,31,32,63,64,65,1000000} {
   rows = append(rows, []any{x<<shift,x>>shift})
  }
 }
 for _, x := range unsigned {
  for _, y := range unsigned {
   row := []any{x+y,x-y,x*y,x&y,x|y,x^y,x&^y,x==y,x<y,x<=y,x>y,x>=y}
   if y != 0 { row = append(row,x/y,x%y) }
   rows = append(rows,row)
  }
  for _, shift := range []uint{0,1,31,32,63,64,65,1000000} {
   rows = append(rows, []any{x<<shift,x>>shift})
  }
 }
 // Marshal each scalar as text to avoid Dart JSON numeric precision loss.
 result := [][]string{}
 for _, raw := range rows {
  row := []string{}
  for _, value := range raw.([]any) {
   b, err := json.Marshal(value)
   if err != nil { panic(err) }
   row = append(row,string(b))
  }
  result = append(result,row)
 }
 if err := json.NewEncoder(os.Stdout).Encode(result); err != nil { panic(err) }
}
