package main

// Bugs do kubo/boxo que o p2p_ffi corrige por patch no build (tool/build.dart,
// "patches"; README, "Build" › "Upstream patches"). Estes testes rodam contra os
// módulos sem patch (o go.mod) e afirmam o bug como ele é: quando uma versão
// nova o corrigir, o teste falha, e o patch e a nota do README saem.

import (
	"bytes"
	"context"
	"io"
	"os"
	"strings"
	"testing"

	chunker "github.com/ipfs/boxo/chunker"
	mdtest "github.com/ipfs/boxo/ipld/merkledag/test"
	ft "github.com/ipfs/boxo/ipld/unixfs"
	"github.com/ipfs/boxo/ipld/unixfs/importer"
	"github.com/ipfs/boxo/mfs"
	"github.com/ipfs/kubo/config"
	"github.com/ipfs/kubo/core"
	"github.com/ipfs/kubo/core/node/libp2p"
	"github.com/ipfs/kubo/plugin/loader"
	"github.com/ipfs/kubo/repo/fsrepo"
)

// boxo: anexar no fim de um arquivo do MFS cujo nó guarda os dados embutidos
// (o nó folha de um add pequeno, sem links) deixa a leitura só com o trecho
// anexado.
func TestUpstreamMfsAppendInlineData(t *testing.T) {
	ctx := context.Background()
	ds := mdtest.Mock()
	root, err := mfs.NewRoot(ctx, ds, ft.EmptyDirNode(), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	nd, err := importer.BuildDagFromReader(ds, chunker.DefaultSplitter(bytes.NewReader([]byte("abc"))))
	if err != nil {
		t.Fatal(err)
	}
	if err := mfs.PutNode(root, "/a", nd); err != nil {
		t.Fatal(err)
	}
	got := appendAndRead(t, ctx, root, "/a", "def")
	if got == "abcdef" {
		t.Fatal("o boxo corrigiu o append com dados embutidos: tire o patch (tool/build.dart) e a nota do README")
	}
	if got != "def" {
		t.Fatalf("o bug mudou de forma: %q", got)
	}
}

func appendAndRead(t *testing.T, ctx context.Context, root *mfs.Root, p, more string) string {
	t.Helper()
	n, err := mfs.Lookup(root, p)
	if err != nil {
		t.Fatal(err)
	}
	f := n.(*mfs.File)
	fd, err := f.Open(ctx, mfs.Flags{Write: true, Sync: true})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := fd.Seek(0, io.SeekEnd); err != nil {
		t.Fatal(err)
	}
	if _, err := fd.Write([]byte(more)); err != nil {
		t.Fatal(err)
	}
	if err := fd.Close(); err != nil {
		t.Fatal(err)
	}
	fd, err = f.Open(ctx, mfs.Flags{Read: true})
	if err != nil {
		t.Fatal(err)
	}
	defer fd.Close()
	b, err := io.ReadAll(fd)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// kubo: com Routing none (libp2p.NilRouterOption), o SweepingProviderOpt abre o
// keystore do provider no disco (<repo>/provider-keystore, com a trava do
// datastore) e, sem DHT, devolve o NoopProvider sem fechá-lo; os ganchos de
// encerramento pulam o Noop. Reabrir o repo no mesmo processo esbarra na trava.
func TestUpstreamKuboNilRoutingKeystoreLeak(t *testing.T) {
	plugins(t)
	ctx := context.Background()
	// não t.TempDir(): o datastore que vaza segue aberto e, no Windows, a
	// limpeza do TempDir falharia o teste
	dir, err := os.MkdirTemp("", "p2p_ffi_upstream_")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	cfg, err := config.Init(io.Discard, 2048)
	if err != nil {
		t.Fatal(err)
	}
	if err := config.Profiles["test"].Transform(cfg); err != nil {
		t.Fatal(err)
	}
	if err := fsrepo.Init(dir, cfg); err != nil {
		t.Fatal(err)
	}
	start := func() error {
		r, err := fsrepo.Open(dir)
		if err != nil {
			return err
		}
		n, err := core.NewNode(ctx, &core.BuildCfg{Online: true, Repo: r, Routing: libp2p.NilRouterOption})
		if err != nil {
			r.Close()
			return err
		}
		return n.Close()
	}
	if err := start(); err != nil {
		t.Fatal(err)
	}
	err = start()
	if err == nil {
		t.Fatal("o kubo corrigiu o keystore do Routing none: tire o patch (tool/build.dart) e a nota do README")
	}
	if !strings.Contains(err.Error(), "provider-keystore") && !strings.Contains(err.Error(), "lock") &&
		!strings.Contains(err.Error(), "temporarily unavailable") && !strings.Contains(err.Error(), "used by another process") {
		t.Fatalf("o bug mudou de forma: %v", err)
	}
	t.Logf("reabrir: %v", err)
}

// plugins: os do kubo, uma vez por processo (o TestTableRepoFlow pode já ter
// injetado pela tabela).
func plugins(t *testing.T) {
	t.Helper()
	pl, err := loader.NewPluginLoader("")
	if err != nil {
		t.Fatal(err)
	}
	if err := pl.Initialize(); err != nil {
		t.Fatal(err)
	}
	if err := pl.Inject(); err != nil && !strings.Contains(err.Error(), "already") {
		t.Fatal(err)
	}
}
