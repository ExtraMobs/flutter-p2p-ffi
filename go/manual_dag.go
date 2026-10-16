// `ipfs dag put` e `ipfs dag get` (DAG-CBOR/JSON e os outros codecs do
// go-ipld-prime). No kubo isso é o corpo dos comandos (core/commands/dag/
// put.go e get.go), não função de biblioteca, por isso o porte é à mão; o
// Dart está em lib/kubo/core/commands/dag.dart.
package main

import (
	"bytes"
	"context"
	"fmt"

	"github.com/ipfs/boxo/path"
	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	format "github.com/ipfs/go-ipld-format"
	ipldlegacy "github.com/ipfs/go-ipld-legacy"
	iface "github.com/ipfs/kubo/core/coreiface"
	"github.com/ipld/go-ipld-prime"
	"github.com/ipld/go-ipld-prime/multicodec"
	basicnode "github.com/ipld/go-ipld-prime/node/basic"
	"github.com/ipld/go-ipld-prime/traversal"
	mc "github.com/multiformats/go-multicodec"

	// os codecs que o `ipfs dag` registra (core/commands/dag/put.go)
	_ "github.com/ipld/go-codec-dagpb"
	_ "github.com/ipld/go-ipld-prime/codec/cbor"
	_ "github.com/ipld/go-ipld-prime/codec/dagcbor"
	_ "github.com/ipld/go-ipld-prime/codec/dagjson"
	_ "github.com/ipld/go-ipld-prime/codec/json"
	_ "github.com/ipld/go-ipld-prime/codec/raw"
)

// softBlockLimit: cmdutils.SoftBlockLimit do kubo (2 MiB, spec do bitswap).
const softBlockLimit = 2 * 1024 * 1024

// dagPut é o dagPut do kubo para um objeto: decodifica [data] com o codec de
// entrada, grava com o de armazenamento e devolve o CID (CIDv1).
func dagPut(ctx context.Context, api iface.CoreAPI, data []byte, inputCodec, storeCodec, hash string, pin, allowBigBlock bool) (cid.Cid, error) {
	var icodec, scodec, mhType mc.Code
	if err := icodec.Set(inputCodec); err != nil {
		return cid.Undef, err
	}
	if err := scodec.Set(storeCodec); err != nil {
		return cid.Undef, err
	}
	if err := mhType.Set(hash); err != nil {
		return cid.Undef, err
	}
	cidPrefix := cid.Prefix{Version: 1, Codec: uint64(scodec), MhType: uint64(mhType), MhLength: -1}

	decoder, err := multicodec.LookupDecoder(uint64(icodec))
	if err != nil {
		return cid.Undef, err
	}
	encoder, err := multicodec.LookupEncoder(uint64(scodec))
	if err != nil {
		return cid.Undef, err
	}

	var adder format.NodeAdder = api.Dag()
	if pin {
		adder = api.Dag().Pinning()
	}
	b := format.NewBatch(ctx, adder)

	node := basicnode.Prototype.Any.NewBuilder()
	if err := decoder(node, bytes.NewReader(data)); err != nil {
		return cid.Undef, err
	}
	n := node.Build()

	bd := bytes.NewBuffer([]byte{})
	if err := encoder(n, bd); err != nil {
		return cid.Undef, err
	}
	blockCid, err := cidPrefix.Sum(bd.Bytes())
	if err != nil {
		return cid.Undef, err
	}
	blk, err := blocks.NewBlockWithCid(bd.Bytes(), blockCid)
	if err != nil {
		return cid.Undef, err
	}
	ln := ipldlegacy.LegacyNode{Block: blk, Node: n}

	if !allowBigBlock && bd.Len() > softBlockLimit {
		return cid.Undef, fmt.Errorf("produced block is over 2MiB: big blocks can't be exchanged with other peers. consider using UnixFS for automatic chunking of bigger files, or pass --allow-big-block to override")
	}
	if err := b.Add(ctx, &ln); err != nil {
		return cid.Undef, err
	}
	if err := b.Commit(); err != nil {
		return cid.Undef, err
	}
	return ln.Cid(), nil
}

// dagGet é o dagGet do kubo: resolve [p] (com o resto do caminho dentro do
// nó) e codifica o nó com o codec de saída.
func dagGet(ctx context.Context, api iface.CoreAPI, p path.Path, outputCodec string) ([]byte, error) {
	var codec mc.Code
	if err := codec.Set(outputCodec); err != nil {
		return nil, err
	}
	rp, remainder, err := api.ResolvePath(ctx, p)
	if err != nil {
		return nil, err
	}
	obj, err := api.Dag().Get(ctx, rp.RootCid())
	if err != nil {
		return nil, err
	}
	universal, ok := obj.(ipldlegacy.UniversalNode)
	if !ok {
		return nil, fmt.Errorf("%T is not a valid IPLD node", obj)
	}
	finalNode := universal.(ipld.Node)
	if len(remainder) > 0 {
		remainderPath := ipld.ParsePath(path.SegmentsToString(remainder...))
		if finalNode, err = traversal.Get(finalNode, remainderPath); err != nil {
			return nil, err
		}
	}
	encoder, err := multicodec.LookupEncoder(uint64(codec))
	if err != nil {
		return nil, fmt.Errorf("invalid encoding: %s - %s", codec, err)
	}
	var out bytes.Buffer
	if err := encoder(finalNode, &out); err != nil { // panic do codec: o guard do invoke
		return nil, err
	}
	return out.Bytes(), nil
}

// WIRE.md, ids 32 e 33.
func init() {
	// CoreAPI, ctx, dados, input-codec, store-codec, hash, pin, allow-big-block → CID
	table[32] = entry{key: "kubo/core/commands/dag.put", fn: func(_ *req, r *reader, w *writer) error {
		api, err := decH[iface.CoreAPI](r)
		if err != nil {
			return err
		}
		ctx, err := decH[context.Context](r)
		if err != nil {
			return err
		}
		data := r.bytes()
		inputCodec, storeCodec, hash := r.str(), r.str(), r.str()
		pin, allowBigBlock := r.bool(), r.bool()
		if err := r.done(); err != nil {
			return err
		}
		c, err := dagPut(ctx, api, data, inputCodec, storeCodec, hash, pin, allowBigBlock)
		if err != nil {
			return err
		}
		encCid(w, c)
		return nil
	}}
	// CoreAPI, ctx, path, output-codec → bytes
	table[33] = entry{key: "kubo/core/commands/dag.get", fn: func(_ *req, r *reader, w *writer) error {
		api, err := decH[iface.CoreAPI](r)
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
		codec := r.str()
		if err := r.done(); err != nil {
			return err
		}
		out, err := dagGet(ctx, api, p, codec)
		if err != nil {
			return err
		}
		w.bytes(out)
		return nil
	}}
}
