package main
import("encoding/json";"fmt";"math";"os")
func main(){
 values:=[]float64{0,math.Copysign(0,-1),1+math.Ldexp(1,-24),1+3*math.Ldexp(1,-24),math.Ldexp(1,-150),3*math.Ldexp(1,-150),1e300,0.1}
 rows:=[][]string{}
 for _,x:=range values{ y:=float32(x);rows=append(rows,[]string{fmt.Sprintf("%08x",math.Float32bits(y)),fmt.Sprintf("%016x",math.Float64bits(float64(y)))}) }
 if err:=json.NewEncoder(os.Stdout).Encode(rows);err!=nil{panic(err)}
}
