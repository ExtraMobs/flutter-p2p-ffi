package main

import (
	"go/types"
	"testing"
)

// A handle type that a command emits (dagcmd.DagStatSummary, with an
// unexported field) keeps its class for the command's DTO: its methods are
// left out.
func TestLeaveCmdOutputs(t *testing.T) {
	const line = cmdsPkg + "/dag.DagStatSummary.String"
	pkgs, err := loadPaths([]string{cmdsPkg + "/dag"})
	if err != nil {
		t.Fatal(err)
	}
	m := newModel()
	m.load = func(path string) *types.Package { return pkgs[path] }
	fs, err := m.resolve(pkgs, line)
	if err != nil {
		t.Fatal(err)
	}
	if fs[0].recv.k != kHandle || fs[0].why != "" {
		t.Fatalf("%s: a handle method before the filter, got kind %d, why %q", line, fs[0].recv.k, fs[0].why)
	}
	m.leaveCmdOutputs(fs, manualNames())
	if fs[0].why == "" {
		t.Fatalf("%s: still generated", line)
	}
}
