package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestDartPath(t *testing.T) {
	for pkg, want := range map[string]string{
		"github.com/ipfs/boxo/mfs":                           "go/boxo/mfs.dart",
		"github.com/ipfs/kubo/core/node/libp2p":              "go/kubo/core/node/libp2p.dart",
		"github.com/ipfs/kubo":                               "go/kubo.dart",
		"github.com/ipfs/go-cid":                             "go/cid.dart",
		"github.com/ipfs/go-ipld-format":                     "go/ipld_format.dart",
		"github.com/ipld/go-car/v2":                          "go/car/v2.dart",
		"github.com/ipld/go-car/v2/index":                    "go/car/v2/index.dart",
		"github.com/ipld/go-ipld-prime/linking/cid":          "go/ipld_prime/linking/cid.dart",
		"github.com/ipld/go-ipld-prime/storage/bsadapter":    "go/ipld_prime/storage/bsadapter.dart",
		"github.com/libp2p/go-libp2p/core/peer":              "go/libp2p/core/peer.dart",
		"github.com/libp2p/go-libp2p-kad-dht/provider/stats": "go/libp2p_kad_dht/provider/stats.dart",
		"context":       "go/context.dart",
		"runtime/debug": "go/runtime/debug.dart",
	} {
		if got := dartPath(pkg); got != want {
			t.Errorf("dartPath(%s) = %s, quero %s", pkg, got, want)
		}
	}
}

func TestCheckPublicExports(t *testing.T) {
	dir := t.TempDir()
	write := func(rel, src string) {
		p := filepath.Join(dir, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(src), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("ipfs_ffi.dart", "library;\n\nexport 'src/service.dart' show P2pService;\n")
	write("src/service.dart", "export 'runtime.dart';\n") // privado: pode
	write("go/hand.dart", "library;\n\nint x() => 1;\n")
	if err := checkPublicExports(dir, nil); err != nil {
		t.Fatalf("válido recusado: %v", err)
	}
	write("go/boxo.dart", "library;\n\nexport 'boxo/mfs.dart';\n")
	err := checkPublicExports(dir, nil)
	if err == nil || !strings.Contains(err.Error(), "lib/go/boxo.dart:3 re-exports 'boxo/mfs.dart'") {
		t.Fatalf("reexport aceito: %v", err)
	}
	// e o ipfs_ffi.dart só reexporta o que é de src/
	write("go/boxo.dart", "library;\n")
	write("ipfs_ffi.dart", "library;\n\nexport 'go/boxo/mfs.dart';\n")
	if err := checkPublicExports(dir, nil); err == nil {
		t.Fatal("ipfs_ffi.dart reexportando uma library pública foi aceito")
	}
}

func TestPublicNames(t *testing.T) {
	src := []byte(`library;

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: x.
class File extends GoHandle {
  File.$h(super.$h);
}

final class _Api {
  const _Api._();
}

const tFile = 0;
const api = _Api._();
FsNode lookup(Root r, String path) {
Future<void> mv(
RoutingOption get dhtOption {
Option withMaxLinks(int n) => Option.$(1, (w) => w..i64(n));
Future<$cid.Cid> dagPut(
`)
	want := []string{"File", "tFile", "api", "lookup", "mv", "dhtOption", "withMaxLinks", "dagPut"}
	if got := publicNames(src); !reflect.DeepEqual(got, want) {
		t.Errorf("publicNames = %v, quero %v", got, want)
	}
}
