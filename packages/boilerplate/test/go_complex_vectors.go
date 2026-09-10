package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
)

type Result struct {
	Add string `json:"add"`
	Sub string `json:"sub"`
	Mul string `json:"mul"`
	Div string `json:"div"`
}

func fmtComplex(c complex128) string {
	r := real(c)
	i := imag(c)
	rStr := fmt.Sprintf("%016x", math.Float64bits(r))
	if math.IsNaN(r) {
		rStr = "NaN"
	}
	iStr := fmt.Sprintf("%016x", math.Float64bits(i))
	if math.IsNaN(i) {
		iStr = "NaN"
	}
	return rStr + "," + iStr
}

func main() {
	values := []complex128{
		complex(0, 0),
		complex(1, 0),
		complex(0, 1),
		complex(1, 1),
		complex(-2, 3),
		complex(3, -4),
		complex(0.5, -1.5),
	}

	results := []Result{}
	for _, a := range values {
		for _, b := range values {
			res := Result{
				Add: fmtComplex(a + b),
				Sub: fmtComplex(a - b),
				Mul: fmtComplex(a * b),
			}
			if b != 0 {
				res.Div = fmtComplex(a / b)
			} else {
				res.Div = "zero"
			}
			results = append(results, res)
		}
	}

	if err := json.NewEncoder(os.Stdout).Encode(results); err != nil {
		panic(err)
	}
}
