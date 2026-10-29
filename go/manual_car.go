// `ipfs dag export` e `ipfs dag import` (arquivos CAR). No kubo isso é o
// corpo dos comandos (core/commands/dag/export.go e import.go), não função
// de biblioteca, por isso o porte é à mão; o Dart está em
// lib/go/ipfs/kubo/core/commands/dag.dart. Diferenças do CLI: sem barra de progresso
// e sem o fast-provide do DAG inteiro; a raiz é anunciada pelo Provide da
// CoreAPI (o mesmo enfileiramento).
package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/ipfs/boxo/blockstore"
	"github.com/ipfs/boxo/dag/walker"
	"github.com/ipfs/boxo/path"
	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	format "github.com/ipfs/go-ipld-format"
	ipldlegacy "github.com/ipfs/go-ipld-legacy"
	"github.com/ipfs/kubo/config"
	"github.com/ipfs/kubo/core"
	"github.com/ipfs/kubo/core/coreapi"
	iface "github.com/ipfs/kubo/core/coreiface"
	"github.com/ipfs/kubo/core/coreiface/options"
	gocar "github.com/ipld/go-car/v2"
	carstorage "github.com/ipld/go-car/v2/storage"
	cidlink "github.com/ipld/go-ipld-prime/linking/cid"
	selectorparse "github.com/ipld/go-ipld-prime/traversal/selector/parse"
)

// dagExport é o dagExport do kubo: escreve em [w] o DAG de [p] como CARv1.
// [localOnly] (--local-only) só lê o blockstore e pula o que faltar (CAR
// parcial); senão busca pela Dag da CoreAPI (rede, se o nó estiver online).
func dagExport(ctx context.Context, node *core.IpfsNode, p path.Path, w io.Writer, localOnly bool) error {
	api, err := coreapi.NewCoreAPI(node)
	if err != nil {
		return err
	}
	if localOnly {
		if api, err = api.WithOptions(options.Api.Offline(true)); err != nil {
			return err
		}
	}
	b, err := api.Block().Stat(ctx, p)
	if err != nil {
		return err
	}
	c := b.Path().RootCid()

	if localOnly {
		err = exportPartialCAR(ctx, node.Blockstore, c, w)
	} else {
		lsys := cidlink.DefaultLinkSystem()
		lsys.SetReadStorage(&dagStore{dag: api.Dag(), ctx: ctx})
		_, err = gocar.TraverseV1(ctx, &lsys, c, selectorparse.CommonSelector_ExploreAllRecursively, w, gocar.AllowDuplicatePuts(false))
	}
	if errors.Is(err, format.ErrNotFound{}) && !node.IsOnline {
		err = fmt.Errorf("%s (currently offline, perhaps retry after attaching to the network)", err)
	}
	return err
}

// exportPartialCAR: o motor do `dag export --local-only` (kubo): anda pelo DAG
// só no blockstore e pula o que não está local.
func exportPartialCAR(ctx context.Context, bs blockstore.Blockstore, root cid.Cid, w io.Writer) error {
	writable, err := carstorage.NewWritable(w, []cid.Cid{root}, gocar.WriteAsCarV1(true))
	if err != nil {
		return err
	}
	var emitErr error
	emit := func(k cid.Cid) bool {
		blk, err := bs.Get(ctx, k)
		if err != nil {
			return true // não está local: pula
		}
		if err := writable.Put(ctx, k.KeyString(), blk.RawData()); err != nil {
			emitErr = err
			return false
		}
		return true
	}
	if err := walker.WalkDAG(ctx, root,
		walker.LinksFetcherFromBlockstore(bs),
		emit,
		walker.WithLocality(func(ctx context.Context, k cid.Cid) (bool, error) { return bs.Has(ctx, k) }),
	); err != nil {
		return err
	}
	return emitErr
}

// dagStore: o dagStore do kubo (export.go): a leitura da travessia do go-car
// pela Dag da CoreAPI.
type dagStore struct {
	dag iface.APIDagService
	ctx context.Context
}

func (ds *dagStore) Get(ctx context.Context, key string) ([]byte, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	c, err := cidFromBinString(key)
	if err != nil {
		return nil, err
	}
	block, err := ds.dag.Get(ds.ctx, c)
	if err != nil {
		return nil, err
	}
	return block.RawData(), nil
}

func (ds *dagStore) Has(ctx context.Context, key string) (bool, error) {
	_, err := ds.Get(ctx, key)
	if err != nil {
		if errors.Is(err, format.ErrNotFound{}) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func cidFromBinString(key string) (cid.Cid, error) {
	l, k, err := cid.CidFromBytes([]byte(key))
	if err != nil {
		return cid.Undef, fmt.Errorf("dagStore: key was not a cid: %w", err)
	}
	if l != len(key) {
		return cid.Undef, fmt.Errorf("dagStore: key was not a cid: had %d bytes leftover", len(key)-l)
	}
	return k, nil
}

// rootMeta e carImportStats: os tipos de saída do `dag import` (kubo dag.go).
type rootMeta struct {
	Cid         cid.Cid
	PinErrorMsg string
}

type carImportStats struct {
	BlockCount      uint64
	BlockBytesCount uint64
}

// dagImport é o dagImport do kubo: grava os blocos dos CARs em [cars] e pina
// as raízes ([pinRoots], --pin-roots). Sem rede: só o que está nos CARs e no
// blockstore.
func dagImport(ctx context.Context, node *core.IpfsNode, cars []io.Reader, pinRoots, allowBigBlock bool) ([]rootMeta, carImportStats, error) {
	var stats carImportStats
	cfg, err := node.Repo.Config()
	if err != nil {
		return nil, stats, err
	}
	api, err := coreapi.NewCoreAPI(node)
	if err != nil {
		return nil, stats, err
	}
	blockDecoder := ipldlegacy.NewDecoder()
	if api, err = api.WithOptions(options.Api.Offline(true)); err != nil {
		return nil, stats, err
	}
	// pin lock (também trava o GC) até as raízes, que podem vir no fim
	if pinRoots {
		unlocker := node.Blockstore.PinLock(ctx)
		defer unlocker.Unlock(ctx)
	}
	batch := format.NewBatch(ctx, api.Dag(),
		format.MaxNodesBatchOption(int(cfg.Import.BatchMaxNodes.WithDefault(config.DefaultBatchMaxNodes))),
		format.MaxSizeBatchOption(int(cfg.Import.BatchMaxSize.WithDefault(config.DefaultBatchMaxSize))),
	)
	roots := cid.NewSet()
	importError := func(previous, current blocks.Block, err error) error {
		if current != nil {
			return fmt.Errorf("import failed at block %q: %w", current.Cid(), err)
		}
		if previous != nil {
			return fmt.Errorf("import failed after block %q: %w", previous.Cid(), err)
		}
		return fmt.Errorf("import failed: %w", err)
	}

	for _, r := range cars {
		car, err := gocar.NewBlockReader(struct{ io.Reader }{r}) // leitura sequencial (kubo#9361)
		if err != nil {
			return nil, stats, err
		}
		for _, c := range car.Roots {
			roots.Add(c)
		}
		var previous blocks.Block
		for {
			block, err := car.Next()
			if err != nil && err != io.EOF {
				return nil, stats, importError(previous, block, err)
			} else if block == nil {
				break
			}
			if !allowBigBlock && len(block.RawData()) > softBlockLimit {
				return nil, stats, importError(previous, block, fmt.Errorf("produced block is over 2MiB: big blocks can't be exchanged with other peers. consider using UnixFS for automatic chunking of bigger files, or pass --allow-big-block to override"))
			}
			nd, err := blockDecoder.DecodeNode(ctx, block)
			if err != nil {
				return nil, stats, importError(previous, block, err)
			}
			if err := batch.Add(ctx, nd); err != nil {
				return nil, stats, importError(previous, block, err)
			}
			stats.BlockCount++
			stats.BlockBytesCount += uint64(len(block.RawData()))
			previous = block
		}
	}
	if err := batch.Commit(); err != nil {
		return nil, stats, err
	}

	var out []rootMeta
	if pinRoots { // pin oportunista: o que der certo
		_ = roots.ForEach(func(c cid.Cid) error {
			ret := rootMeta{Cid: c}
			if block, err := node.Blockstore.Get(ctx, c); err != nil {
				ret.PinErrorMsg = err.Error()
			} else if nd, err := blockDecoder.DecodeNode(ctx, block); err != nil {
				ret.PinErrorMsg = err.Error()
			} else if err := node.Pinning.Pin(ctx, nd, true, ""); err != nil {
				ret.PinErrorMsg = err.Error()
			} else if err := node.Pinning.Flush(ctx); err != nil {
				ret.PinErrorMsg = err.Error()
			}
			out = append(out, ret)
			return nil
		})
	}
	// Import.FastProvideRoot (padrão true): anuncia as raízes, se online
	if node.IsOnline && cfg.Import.FastProvideRoot.WithDefault(config.DefaultFastProvideRoot) {
		_ = roots.ForEach(func(c cid.Cid) error {
			_ = api.Routing().Provide(ctx, path.FromCid(c))
			return nil
		})
	}
	return out, stats, nil
}

// WIRE.md, ids 34 e 35.
func init() {
	// IpfsNode, ctx, path, local-only, arquivo ("" = devolve os bytes) → bytes
	table[34] = entry{key: "kubo/core/commands/dag.export", fn: func(_ *req, r *reader, w *writer) error {
		node, err := decH[*core.IpfsNode](r)
		if err != nil {
			return err
		}
		ctx, err := decH[context.Context](r)
		if err != nil {
			return err
		}
		p, err := path.NewPath(r.str())
		if err != nil {
			return err
		}
		localOnly, file := r.bool(), r.str()
		if err := r.done(); err != nil {
			return err
		}
		if file == "" {
			var buf bytes.Buffer
			if err := dagExport(ctx, node, p, &buf, localOnly); err != nil {
				return err
			}
			w.bytes(buf.Bytes())
			return nil
		}
		f, err := os.Create(file)
		if err != nil {
			return err
		}
		if err := dagExport(ctx, node, p, f, localOnly); err != nil {
			f.Close()
			return err
		}
		w.bytes([]byte{}) // gravou no arquivo: bytes vazios
		return f.Close()
	}}
	// IpfsNode, ctx, arquivos, CAR (nil = só os arquivos), pin-roots,
	// allow-big-block → raízes (CID, erro do pin), blocos, bytes
	table[35] = entry{key: "kubo/core/commands/dag.import", fn: func(_ *req, r *reader, w *writer) error {
		node, err := decH[*core.IpfsNode](r)
		if err != nil {
			return err
		}
		ctx, err := decH[context.Context](r)
		if err != nil {
			return err
		}
		paths := make([]string, max(r.count(), 0))
		for i := range paths {
			paths[i] = r.str()
		}
		data := r.bytes()
		pinRoots, allowBigBlock := r.bool(), r.bool()
		if err := r.done(); err != nil {
			return err
		}
		var cars []io.Reader
		if data != nil {
			cars = append(cars, bytes.NewReader(data))
		}
		for _, p := range paths {
			f, err := os.Open(p)
			if err != nil {
				return err
			}
			defer f.Close()
			cars = append(cars, f)
		}
		roots, stats, err := dagImport(ctx, node, cars, pinRoots, allowBigBlock)
		if err != nil {
			return err
		}
		w.i32(int32(len(roots)))
		for _, rt := range roots {
			w.str(rt.Cid.String())
			w.str(rt.PinErrorMsg)
		}
		w.i64(int64(stats.BlockCount))
		w.i64(int64(stats.BlockBytesCount))
		return nil
	}}
}
