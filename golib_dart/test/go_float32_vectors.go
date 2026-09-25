package main
import("encoding/json"; "fmt"; "math"; "os")
func main() {
 values := []float32{0, float32(math.Copysign(0,-1)), 1, -1, 0.1, 16777216,
  math.SmallestNonzeroFloat32, math.MaxFloat32, float32(math.Inf(1))}
 rows := [][]string{}
 for _, x := range values { for _, y := range values {
  row := []string{}
  for _, v := range []float32{float32(x+y),float32(x-y),float32(x*y),float32(x/y)} {
   if math.IsNaN(float64(v)) { row=append(row,"NaN") } else {
    row=append(row,fmt.Sprintf("%08x",math.Float32bits(v)))
   }
  }
  rows=append(rows,row)
 }}
 if err:=json.NewEncoder(os.Stdout).Encode(rows);err!=nil{panic(err)}
}
