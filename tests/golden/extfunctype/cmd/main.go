// Tipos func nomeados de outro pacote (github.com/ipfs/go-ipfs-cmds): campo
// Function, EncoderMap (map de func nomeado: descritor com zero não nulo).
package main

import (
	"errors"
	"fmt"

	"g2d.test/extfunctype/cmds"
)

var updateCmd = &cmds.Command{
	Helptext: "update",
	Run: func(req *cmds.Request, out []string) error {
		out[0] = "ran " + req.Path
		if req.Path == "bad" {
			return errors.New("bad path")
		}
		return nil
	},
}

var encoders = cmds.EncoderMap{
	"text": cmds.MakeTypedEncoder("tx"),
	"json": func(r *cmds.Request) func([]string) int { return func(w []string) int { return -1 } },
}

func main() {
	fmt.Println(updateCmd.Call("/x"))
	fmt.Println(updateCmd.Call("bad"))
	var f cmds.Function = func(r *cmds.Request, o []string) error { return nil }
	fmt.Println(f(&cmds.Request{}, nil), f != nil)
	var e cmds.EncoderFunc = cmds.MakeTypedEncoder("a")
	fmt.Println(encoders["text"](&cmds.Request{Path: "p"})([]string{"x"}), encoders["json"](nil)(nil), e(&cmds.Request{})(nil))
}
