package main

import (
	"go/constant"
	"go/types"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestDartPath(t *testing.T) {
	for pkg, want := range map[string]string{
		"github.com/ipfs/boxo/mfs":                           "go/ipfs/boxo/mfs.dart",
		"github.com/ipfs/kubo/core/node/libp2p":              "go/ipfs/kubo/core/node/libp2p.dart",
		"github.com/ipfs/kubo":                               "go/ipfs/kubo.dart",
		"github.com/ipfs/go-cid":                             "go/ipfs/cid.dart",
		"github.com/ipfs/go-ipld-format":                     "go/ipfs/ipld_format.dart",
		"github.com/ipld/go-car/v2":                          "go/ipld/car/v2.dart",
		"github.com/ipld/go-car/v2/index":                    "go/ipld/car/v2/index.dart",
		"github.com/ipld/go-ipld-prime/linking/cid":          "go/ipld/ipld_prime/linking/cid.dart",
		"github.com/ipld/go-ipld-prime/storage/bsadapter":    "go/ipld/ipld_prime/storage/bsadapter.dart",
		"github.com/libp2p/go-libp2p/core/peer":              "go/libp2p/libp2p/core/peer.dart",
		"github.com/libp2p/go-libp2p-kad-dht/provider/stats": "go/libp2p/libp2p_kad_dht/provider/stats.dart",
		"context":       "go/context.dart",
		"runtime/debug": "go/runtime/debug.dart",
	} {
		if got := dartPath(pkg); got != want {
			t.Errorf("dartPath(%s) = %s, quero %s", pkg, got, want)
		}
	}
}

// The namespace keeps the author; the class names do not.
func TestNamespaceAndClass(t *testing.T) {
	for _, c := range []struct{ pkg, goName, ns, class string }{
		{"github.com/ipfs/boxo/mfs", "Root", "go.ipfs.boxo.mfs", "BoxoMfsRoot"},
		{"github.com/ipfs/go-cid", "Cid", "go.ipfs.cid", "Cid"},
		{"github.com/libp2p/go-libp2p/core/peer", "ID", "go.libp2p.libp2p.core.peer", "Libp2pCorePeerId"},
		{"github.com/ipld/go-ipld-prime/storage/bsadapter", "Adapter", "go.ipld.ipldPrime.storage.bsadapter", "IpldPrimeStorageBsadapterAdapter"},
		{"context", "Context", "go.context", "Context"},
	} {
		path := dartPath(c.pkg)
		if got := nsPath(path); got != c.ns {
			t.Errorf("nsPath(%s) = %s, quero %s", path, got, c.ns)
		}
		if got := qualType(path, c.goName); got != c.class {
			t.Errorf("qualType(%s, %s) = %s, quero %s", path, c.goName, got, c.class)
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
	write("p2p_ffi.dart", "library;\n\nexport 'src/service.dart' show P2pService;\n")
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
	// e o p2p_ffi.dart só reexporta o que é de src/
	write("go/boxo.dart", "library;\n")
	write("p2p_ffi.dart", "library;\n\nexport 'go/boxo/mfs.dart';\n")
	if err := checkPublicExports(dir, nil); err == nil {
		t.Fatal("p2p_ffi.dart reexportando uma library pública foi aceito")
	}
}

func TestPublicNames(t *testing.T) {
	src := []byte(`library;

import 'package:p2p_ffi/src/runtime.dart';

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

// A constant of a named type is an enum; the others, untyped or of a basic
// type, are consts; a variable is neither.
func TestConstLayer(t *testing.T) {
	pkg := types.NewPackage("crypto", "crypto")
	hash := types.NewNamed(types.NewTypeName(0, pkg, "Hash", nil), types.Typ[types.Uint], nil)
	one := constant.MakeInt64(1)
	for _, c := range []struct {
		o    types.Object
		want string
	}{
		{types.NewConst(0, pkg, "MD5", hash, one), "enums"},
		{types.NewConst(0, pkg, "Raw", types.Typ[types.UntypedInt], one), "consts"},
		{types.NewConst(0, pkg, "Size", types.Typ[types.Int], one), "consts"},
		{types.NewVar(0, pkg, "X", hash), ""},
	} {
		if got := constLayer(c.o); got != c.want {
			t.Errorf("constLayer(%s) = %q, quero %q", c.o.Name(), got, c.want)
		}
	}
	if got := nsPath(layerPath("go/crypto.dart", "enums")); got != "go.crypto.enums" {
		t.Errorf("nsPath = %s", got)
	}
}

func TestMarkClasses(t *testing.T) {
	defer clear(classMarks)
	markClasses([][2]string{
		{"go/grpc.dart", "BackoffConfig"}, {"go/grpc/backoff.dart", "Config"},
		{"go/pebble/v2.dart", "WALCreateInfo"}, {"go/pebble/v2/wal.dart", "CreateInfo"},
		{"go/encoding/gob.dart", "Decoder"}, {"go/encoding/gob.dart", "GobDecoder"},
		{"go/errors/errorspb.dart", "EncodedErrorLeaf"}, {"go/errors/errorspb.dart", "EncodedError_Leaf"},
		{"go/encoding/gob.dart", "Encoder"},
	})
	for _, c := range [][3]string{
		{"go/grpc/backoff.dart", "Config", "GrpcBackoffConfig"},
		{"go/grpc.dart", "BackoffConfig", "Grpc_BackoffConfig"},
		{"go/pebble/v2/wal.dart", "CreateInfo", "PebbleV2WalCreateInfo"},
		{"go/pebble/v2.dart", "WALCreateInfo", "PebbleV2_WalCreateInfo"},
		{"go/encoding/gob.dart", "Decoder", "EncodingGobDecoder"},
		{"go/encoding/gob.dart", "GobDecoder", "EncodingGob_GobDecoder"},
		{"go/errors/errorspb.dart", "EncodedErrorLeaf", "ErrorsErrorspbEncodedErrorLeaf"},
		{"go/errors/errorspb.dart", "EncodedError_Leaf", "ErrorsErrorspbEncodedError_Leaf"},
		{"go/encoding/gob.dart", "Encoder", "EncodingGobEncoder"},
	} {
		if got := qualType(c[0], c[1]); got != c[2] {
			t.Errorf("qualType(%s, %s) = %s, quero %s", c[0], c[1], got, c[2])
		}
	}
	src := "/// Go: `grpc.BackoffConfig` (handle).\nclass Grpc_BackoffConfig extends GoHandle {\n}\n\nmixin Grpc_BackoffConfig$ on GoHandle {\n}\n"
	if got := ignoreMarked(src); strings.Count(got, "// ignore: camel_case_types\n") != 2 || !strings.Contains(got, "(handle).\n// ignore: camel_case_types\nclass ") {
		t.Errorf("ignoreMarked:\n%s", got)
	}
}

func TestSplitRoot(t *testing.T) {
	for _, c := range [][4]string{
		{"github.com/ipfs/kubo/core.IpfsNode.Close", "github.com/ipfs/kubo/core", "IpfsNode", "Close"},
		{"go.opentelemetry.io/otel/semconv/v1.26.0.ServiceName", "go.opentelemetry.io/otel/semconv/v1.26.0", "ServiceName", ""},
		{"go.opentelemetry.io/otel/semconv/v1.26.0", "go.opentelemetry.io/otel/semconv/v1.26.0", "", ""},
		{"gopkg.in/yaml.v3.Node.Decode", "gopkg.in/yaml.v3", "Node", "Decode"},
		{"context", "context", "", ""},
	} {
		if p, n, m := splitRoot(c[0]); p != c[1] || n != c[2] || m != c[3] {
			t.Errorf("splitRoot(%s) = %s %s %s", c[0], p, n, m)
		}
	}
}
