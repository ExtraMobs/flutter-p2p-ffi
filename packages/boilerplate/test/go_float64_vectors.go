package main
import("encoding/json"; "fmt"; "math"; "os")
func main() {
 values := []float64{0, float64(math.Copysign(0,-1)), 1, -1, 0.1, 9007199254740992,
  math.SmallestNonzeroFloat64, math.MaxFloat64, float64(math.Inf(1))}
 rows := [][]string{}
 for _, x := range values { for _, y := range values {
  row := []string{}
  for _, v := range []float64{float64(x+y),float64(x-y),float64(x*y),float64(x/y)} {
   if math.IsNaN(float64(v)) { row=append(row,"NaN") } else {
    row=append(row,fmt.Sprintf("%016x",math.Float64bits(v)))
   }
  }
  rows=append(rows,row)
 }}
 if err:=json.NewEncoder(os.Stdout).Encode(rows);err!=nil{panic(err)}
}
