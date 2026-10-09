// Package main exporta uma API C mínima de um nó IPFS (kubo) para dart:ffi.
// Build: go build -buildmode=c-shared (ver tool/build.dart).
//
// Convenção: toda função devolve NULL em sucesso ou uma mensagem de erro
// alocada em C; strings e buffers devolvidos são liberados com GoFree.
package main

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

import (
	"bytes"
	"context"
	"io"
	"os"
	"sync"
	"unsafe"

	"github.com/ipfs/boxo/path"
	"github.com/ipfs/go-cid"
	cmds "github.com/ipfs/go-ipfs-cmds"
	"github.com/ipfs/kubo/cmd/ipfs/kubo"
	oldcmds "github.com/ipfs/kubo/commands"
	"github.com/ipfs/kubo/core"
	"github.com/ipfs/kubo/core/coreapi"
	iface "github.com/ipfs/kubo/core/coreiface"
	"github.com/ipfs/kubo/plugin/loader"
	"github.com/ipfs/kubo/repo/fsrepo"
)

type node struct {
	n   *core.IpfsNode
	api iface.CoreAPI
}

var (
	mu    sync.Mutex
	nodes = map[int64]*node{}
	next  int64
)

func cerr(err error) *C.char {
	if err == nil {
		return nil
	}
	return C.CString(err.Error())
}

func get(h C.int64_t) *node {
	mu.Lock()
	defer mu.Unlock()
	return nodes[int64(h)]
}

var errHandle = io.ErrClosedPipe // handle inválido ou já parado

// IpfsStart cria um nó em memória (Repo nil: datastore em memória).
// online != 0 liga a rede libp2p.
//
//export IpfsStart
func IpfsStart(online C.int, handle *C.int64_t) *C.char {
	n, err := core.NewNode(context.Background(), &core.BuildCfg{Online: online != 0})
	if err != nil {
		return cerr(err)
	}
	api, err := coreapi.NewCoreAPI(n)
	if err != nil {
		n.Close()
		return cerr(err)
	}
	mu.Lock()
	next++
	nodes[next] = &node{n, api}
	*handle = C.int64_t(next)
	mu.Unlock()
	return nil
}

// IpfsAdd grava um bloco bruto e devolve o CID em *cidOut.
//
//export IpfsAdd
func IpfsAdd(h C.int64_t, data unsafe.Pointer, length C.int, cidOut **C.char) *C.char {
	nd := get(h)
	if nd == nil {
		return cerr(errHandle)
	}
	st, err := nd.api.Block().Put(context.Background(), bytes.NewReader(C.GoBytes(data, length)))
	if err != nil {
		return cerr(err)
	}
	*cidOut = C.CString(st.Path().RootCid().String())
	return nil
}

// IpfsGet lê o bloco de um CID; *dataOut é liberado com GoFree.
//
//export IpfsGet
func IpfsGet(h C.int64_t, cidStr *C.char, dataOut *unsafe.Pointer, lenOut *C.int) *C.char {
	nd := get(h)
	if nd == nil {
		return cerr(errHandle)
	}
	c, err := cid.Decode(C.GoString(cidStr))
	if err != nil {
		return cerr(err)
	}
	r, err := nd.api.Block().Get(context.Background(), path.FromCid(c))
	if err != nil {
		return cerr(err)
	}
	b, err := io.ReadAll(r)
	if err != nil {
		return cerr(err)
	}
	*dataOut = C.CBytes(b)
	*lenOut = C.int(len(b))
	return nil
}

// IpfsStop fecha o nó e invalida o handle.
//
//export IpfsStop
func IpfsStop(h C.int64_t) *C.char {
	mu.Lock()
	nd := nodes[int64(h)]
	delete(nodes, int64(h))
	mu.Unlock()
	if nd == nil {
		return cerr(errHandle)
	}
	return cerr(nd.n.Close())
}

// IpfsRun roda o CLI do kubo como `ipfs <argv...>` (init, daemon, id...) e
// devolve o código de saída. Bloqueia até o comando terminar (o daemon só
// volta depois de `ipfs shutdown` ou SIGINT). O kubo não sobe um segundo
// daemon no mesmo processo (métricas globais do prometheus: panic).
//
// shortcut: os.Args é global; uma chamada por vez enquanto o kubo o lê no início.
//
//export IpfsRun
func IpfsRun(argc C.int, argv **C.char) C.int {
	args := []string{"ipfs"}
	for _, a := range unsafe.Slice(argv, int(argc)) {
		args = append(args, C.GoString(a))
	}
	os.Args = args
	return C.int(kubo.Start(buildEnv))
}

var plugins *loader.PluginLoader // injetados uma vez por processo

// buildEnv é o kubo.BuildDefaultEnv, mas reaproveita os plugins da primeira
// chamada: injetá-los de novo falha ("already have a datastore named ...").
//
// shortcut: a config de plugins do primeiro repo vale para os seguintes;
// separar por repo só se alguém usar repos com plugins diferentes.
func buildEnv(ctx context.Context, req *cmds.Request) (cmds.Environment, error) {
	mu.Lock()
	defer mu.Unlock()
	if plugins == nil {
		env, err := kubo.BuildDefaultEnv(ctx, req)
		if err == nil {
			plugins = env.(*oldcmds.Context).Plugins
		}
		return env, err
	}
	repoPath, _ := req.Options["repo-dir"].(string)
	if repoPath == "" {
		var err error
		if repoPath, err = fsrepo.BestKnownPath(); err != nil {
			return nil, err
		}
	}
	return &oldcmds.Context{
		ConfigRoot: repoPath,
		ReqLog:     &oldcmds.ReqLog{},
		Plugins:    plugins,
		ConstructNode: func() (*core.IpfsNode, error) {
			r, err := fsrepo.Open(repoPath)
			if err != nil {
				return nil, err
			}
			return core.NewNode(ctx, &core.BuildCfg{Repo: r})
		},
	}, nil
}

// GoMalloc existe para o Dart alocar com o mesmo allocator de GoFree
// (no Windows não há DynamicLibrary.process()).
//
//export GoMalloc
func GoMalloc(n C.size_t) unsafe.Pointer { return C.malloc(n) }

//export GoFree
func GoFree(p unsafe.Pointer) { C.free(p) }

func main() {}
