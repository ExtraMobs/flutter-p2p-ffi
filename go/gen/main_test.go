package main

import (
	"slices"
	"strings"
	"testing"
)

// The universe is the host's build on every target: fuse (linux's alone),
// internal and vendored packages and the host itself stay out.
func TestUniverse(t *testing.T) {
	t.Chdir("..")
	all, err := universe()
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range []string{"github.com/ipfs/boxo/mfs.*", "github.com/ipfs/go-cid.*", "os.*"} {
		if !slices.Contains(all, p) {
			t.Errorf("%s: missing", p)
		}
	}
	for _, p := range all {
		switch {
		case p == "github.com/ipfs/kubo/fuse/node.*", p == "golang.org/x/sys/windows.*",
			p == "github.com/ExtraMobs/transpiled_ipfs/go.*", p == "internal/poll.*",
			p == "vendor/golang.org/x/net/dns/dnsmessage.*":
			t.Errorf("%s: should be out", p)
		}
	}
}

// A declaration some target lacks or declares otherwise stays out
// (syscall.SysProcAttr has other fields on Windows); a common one does not.
func TestPlatformDecls(t *testing.T) {
	_, _, decls, err := platformConsts([]string{"syscall", "os"})
	if err != nil {
		t.Fatal(err)
	}
	for k, want := range map[string]bool{"syscall.DLLError": true, "syscall.SysProcAttr": true, "os.File": false, "os.File.Close": false, "os.Open": false} {
		if decls[k] != want {
			t.Errorf("%s: %v, want %v", k, decls[k], want)
		}
	}
}

// A struct holding a lock (go vet's copylocks) is never copied: a lock itself,
// one embedded, one in a field; a plain struct is not one.
func TestHasLock(t *testing.T) {
	pkgs, err := loadPaths([]string{"crypto/tls", "net", "sync"})
	if err != nil {
		t.Fatal(err)
	}
	for name, want := range map[string]bool{"sync.Mutex": true, "sync.Pool": true, "crypto/tls.Config": true, "crypto/tls.Certificate": false, "net.IPNet": false} {
		i := strings.LastIndex(name, ".")
		pkg := pkgs[name[:i]]
		if got := hasLock(pkg.Scope().Lookup(name[i+1:]).Type()); got != want {
			t.Errorf("%s: %v, want %v", name, got, want)
		}
	}
}
