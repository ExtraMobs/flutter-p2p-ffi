package main
import("encoding/json";"fmt";"math";"os")
func main(){
 rows:=[][]string{}
 for _,v:=range []int64{0,1,-1,16777217,9007199254740993,4611686293305294849,-4611686293305294849,-9223372036854775808,9223372036854775807}{
  rows=append(rows,[]string{fmt.Sprintf("%08x",math.Float32bits(float32(v))),fmt.Sprintf("%016x",math.Float64bits(float64(v)))})
 }
 v:=^uint64(0)
 rows=append(rows,[]string{fmt.Sprintf("%08x",math.Float32bits(float32(v))),fmt.Sprintf("%016x",math.Float64bits(float64(v)))})
 if err:=json.NewEncoder(os.Stdout).Encode(rows);err!=nil{panic(err)}
}
