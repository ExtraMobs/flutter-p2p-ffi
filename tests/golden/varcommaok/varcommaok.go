// Comma-ok (map e type assertion) em var de pacote e var local.
package main

import "fmt"

var m = map[string]int{"a": 1}
var v, ok = m["a"]
var w, ok2 = m["zz"]

var anyv any = "s"
var str, isStr = anyv.(string)
var num, isNum = anyv.(int)

func main() {
	var lv, lok = m["a"]
	var ls, lis = anyv.(string)
	fmt.Println(v, ok, w, ok2, str, isStr, num, isNum, lv, lok, ls, lis)
}
