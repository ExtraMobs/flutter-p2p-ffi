// Os comandos do RPC do kubo (`ipfs files stat`, `ipfs config`...) pelo canal
// (WIRE.md, "Commands", função 36): o host monta a requisição do go-ipfs-cmds e
// chama a árvore do kubo como o servidor HTTP dele (Root.Call, sem o PreRun do
// CLI), com o nó do app; cada valor emitido vai como item do stream, codificado
// pelo esquema de cmdschema (o mesmo que gerou o DTO Dart).
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/ExtraMobs/transpiled_ipfs/go/cmdschema"
	"github.com/ipfs/boxo/files"
	cmds "github.com/ipfs/go-ipfs-cmds"
	oldcmds "github.com/ipfs/kubo/commands"
	"github.com/ipfs/kubo/core"
	corecmds "github.com/ipfs/kubo/core/commands"
	"github.com/ipfs/kubo/misc/fsutil"
)

// fnCommand: a função dos comandos (WIRE.md).
const fnCommand = 36

// Etiquetas de cada item emitido (WIRE.md, "Commands").
const (
	cmdTyped   = 0 // o tipo declarado do comando (o DTO)
	cmdDynamic = 1 // outro tipo: o valor dinâmico (kAny)
	cmdBytes   = 2 // um pedaço de um io.Reader emitido
)

// cmdChunk: o tamanho dos pedaços de um io.Reader emitido.
const cmdChunk = 256 << 10

func init() {
	table[fnCommand] = entry{key: "kubo/core/commands.Call", fn: callCommand, stream: true}
}

// callCommand: IpfsNode, ctx, str caminho, kSlice de string args, kSlice de
// handles files.Node (os FileArg), i32 n + (str nome, kAny valor) opções →
// os itens emitidos.
func callCommand(q *req, r *reader, w *writer) error {
	node, err := decH[*core.IpfsNode](r)
	if err != nil {
		return err
	}
	ctx, err := decH[context.Context](r)
	if err != nil {
		return err
	}
	path := strings.Fields(r.str())
	var args []string
	for range r.count() {
		args = append(args, r.str())
	}
	var entries []files.DirEntry
	for range r.count() {
		n, err := decH[files.Node](r)
		if err != nil {
			return err
		}
		entries = append(entries, files.FileEntry("", n))
	}
	raw := map[string]any{}
	for range r.count() {
		k := r.str()
		v, err := decAny(r)
		if err != nil {
			return err
		}
		raw[k] = v
	}
	if err := r.done(); err != nil {
		return err
	}
	if node == nil {
		return errors.New("p2p_host: command without a node")
	}

	cmd, err := corecmds.Root.Get(path)
	if err != nil {
		return err
	}
	opts, err := cmdOptions(path, raw)
	if err != nil {
		return err
	}
	var dir files.Directory
	if len(entries) > 0 {
		dir = files.NewSliceDirectory(entries)
	}
	creq, err := cmds.NewRequest(ctx, path, opts, args, dir, corecmds.Root)
	if err != nil {
		return err
	}
	if err := creq.FillDefaults(); err != nil {
		return err
	}
	env := &oldcmds.Context{
		ConfigRoot:    node.Repo.Path(), // o mesmo Open (repoPath)
		ReqLog:        &oldcmds.ReqLog{},
		ConstructNode: func() (*core.IpfsNode, error) { return node, nil },
	}
	// o PreRun é do CLI e o Root.Call (como o servidor HTTP) não o roda; o
	// urlArgsEncoder do pubsub é o lado cliente do contrato (o cliente RPC do
	// kubo faz o mesmo): os args vão em multibase, e o Run os decodifica
	if sameFunc(cmd.PreRun, urlArgsEncoder) {
		if err := cmd.PreRun(creq, env); err != nil {
			return err
		}
	}
	declared := reflect.TypeOf(cmd.Type)
	if declared != nil && declared.Kind() == reflect.Pointer {
		declared = declared.Elem()
	}
	re := &cmdEmitter{q: q, declared: declared}
	func() {
		// o Call não se protege de um panic do comando
		defer func() {
			if p := recover(); p != nil {
				re.err = fmt.Errorf("p2p_host: panic in command %q: %v", strings.Join(path, " "), p)
			}
		}()
		corecmds.Root.Call(creq, re, env) // fecha re com o erro do Run
	}()
	return re.err
}

// cmdEmitter: o ResponseEmitter do host. Como o do servidor HTTP do kubo, o
// Emit escreve o valor (um io.Reader inteiro) antes de voltar: o comando fecha
// o que emitiu (o fd do `files read`) quando o Run volta.
type cmdEmitter struct {
	q        *req
	declared reflect.Type
	mu       sync.Mutex
	closed   bool
	err      error
}

func (e *cmdEmitter) Emit(v any) error {
	switch ch := v.(type) {
	case chan any:
		return cmds.EmitChan(e, ch)
	case <-chan any:
		return cmds.EmitChan(e, ch)
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.closed {
		return cmds.ErrClosedEmitter
	}
	if s, ok := v.(cmds.Single); ok {
		v = s.Value
	}
	if rd, ok := v.(io.Reader); ok {
		return emitReader(e.q, rd)
	}
	emitValue(e.q, v, e.declared)
	return nil
}

func (e *cmdEmitter) CloseWithError(err error) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.closed {
		return cmds.ErrClosingClosedEmitter
	}
	e.closed, e.err = true, err
	return nil
}

func (e *cmdEmitter) Close() error                      { return e.CloseWithError(nil) }
func (e *cmdEmitter) SetLength(uint64)                  {}
func (e *cmdEmitter) SetEncodingType(cmds.EncodingType) {}
func (e *cmdEmitter) SetContentType(string)             {}

// repoPath: o caminho do fsrepo.Open na forma que o FSRepo guarda e o
// Repo.Path() devolve (fsutil.ExpandHome(filepath.Clean(p)), o newFSRepo do
// kubo); o argPre do gerador o aplica antes do Open.
func repoPath(p string) string {
	if e, err := fsutil.ExpandHome(filepath.Clean(p)); err == nil {
		return e
	}
	return p
}

// urlArgsEncoder: o PreRun dos comandos de pubsub (pubsub.go do kubo, não
// exportado), pela referência do `pubsub pub`.
var urlArgsEncoder = corecmds.Root.Subcommands["pubsub"].Subcommands["pub"].PreRun

func sameFunc(a, b func(*cmds.Request, cmds.Environment) error) bool {
	return a != nil && b != nil && reflect.ValueOf(a).Pointer() == reflect.ValueOf(b).Pointer()
}

// emitValue: o valor no tipo declarado (deref de ponteiros), ou dinâmico.
// Um valor de outro tipo com o mesmo JSON (o `diag cmds` emite o ReqLogEntry
// do kubo e declara o do go-ipfs-cmds) vai no declarado, pelo JSON: o que o
// cliente HTTP do kubo recebe.
func emitValue(q *req, v any, declared reflect.Type) {
	rv := reflect.ValueOf(v)
	for rv.IsValid() && rv.Kind() == reflect.Pointer && !rv.IsNil() && rv.Type() != declared {
		rv = rv.Elem()
	}
	if declared != nil && rv.IsValid() && rv.Type() != declared {
		if b, err := json.Marshal(v); err == nil {
			nv := reflect.New(declared)
			if json.Unmarshal(b, nv.Interface()) == nil {
				rv = nv.Elem()
			}
		}
	}
	if declared != nil && rv.IsValid() && rv.Type() == declared {
		q.item(func(w *writer) {
			w.u8(cmdTyped)
			encTyped(w, rv, declared)
		})
		return
	}
	q.item(func(w *writer) {
		w.u8(cmdDynamic)
		encAny(w, v)
	})
}

// emitReader: um io.Reader emitido (cat, files read...) em pedaços.
func emitReader(q *req, rd io.Reader) error {
	return readChunks(rd, func(chunk []byte) {
		q.item(func(w *writer) {
			w.u8(cmdBytes)
			w.bytes(chunk)
		})
	})
}

// readChunks: reads [rd] to the end in cmdChunk pieces, each one a fresh
// slice handed to [each]; closes [rd] when it is an io.Closer.
func readChunks(rd io.Reader, each func([]byte)) error {
	switch c := rd.(type) {
	case interface{ CloseRead() error }: // a stream (network.Stream): its write side stays open
		defer c.CloseRead()
	case io.Closer:
		defer c.Close()
	}
	buf := make([]byte, cmdChunk)
	for {
		n, err := rd.Read(buf)
		if n > 0 {
			each(append([]byte(nil), buf[:n]...))
		}
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
	}
}

// cmdOptions: as opções do Dart (valores dinâmicos) nos tipos que as opções do
// comando declaram (as do comando, as herdadas e as globais do Root).
func cmdOptions(path []string, raw map[string]any) (cmds.OptMap, error) {
	defs, err := corecmds.Root.GetOptions(path)
	if err != nil {
		return nil, err
	}
	out := cmds.OptMap{}
	for k, v := range raw {
		def, ok := defs[k]
		if !ok {
			return nil, fmt.Errorf("p2p_host: unknown option %q for %q", k, strings.Join(path, " "))
		}
		c, err := convOption(def.Type(), v)
		if err != nil {
			return nil, fmt.Errorf("p2p_host: option %q: %w", k, err)
		}
		out[k] = c
	}
	return out, nil
}

func convOption(kind reflect.Kind, v any) (any, error) {
	switch kind {
	case reflect.Bool:
		if b, ok := v.(bool); ok {
			return b, nil
		}
	case reflect.Int:
		if i, ok := v.(int64); ok {
			return int(i), nil
		}
	case reflect.Uint:
		if i, ok := v.(int64); ok && i >= 0 {
			return uint(i), nil
		}
	case reflect.Int64:
		if i, ok := v.(int64); ok {
			return i, nil
		}
	case reflect.Uint64:
		if i, ok := v.(int64); ok && i >= 0 {
			return uint64(i), nil
		}
	case reflect.Float64:
		switch x := v.(type) {
		case float64:
			return x, nil
		case int64:
			return float64(x), nil
		}
	case reflect.String:
		if s, ok := v.(string); ok {
			return s, nil
		}
	case reflect.Array: // StringsOption, DelimitedStringsOption
		if xs, ok := v.([]any); ok {
			out := make([]string, len(xs))
			for i, x := range xs {
				s, ok := x.(string)
				if !ok {
					return nil, fmt.Errorf("item %d is %T, not a string", i, x)
				}
				out[i] = s
			}
			return out, nil
		}
	}
	return nil, fmt.Errorf("%T is not a %s option", v, kind)
}

// encTyped: [v] (do tipo [t]) pelo esquema de cmdschema; o Dart lê na mesma
// ordem pelo DTO gerado do mesmo reflect.Type.
func encTyped(w *writer, v reflect.Value, t reflect.Type) {
	switch cmdschema.Of(t) {
	case cmdschema.Bool:
		w.bool(v.Bool())
	case cmdschema.Int, cmdschema.Duration:
		w.i64(v.Int())
	case cmdschema.Uint:
		w.i64(int64(v.Uint()))
	case cmdschema.Float:
		w.f64(v.Float())
	case cmdschema.String:
		w.str(v.String())
	case cmdschema.Bytes:
		if v.Kind() == reflect.Slice {
			if v.IsNil() {
				w.i32(-1)
				return
			}
			w.bytes(v.Bytes())
			return
		}
		b := make([]byte, v.Len()) // array de bytes
		reflect.Copy(reflect.ValueOf(b), v)
		w.bytes(b)
	case cmdschema.Text:
		w.str(cmdschema.TextOf(v))
	case cmdschema.Time:
		encTime(w, v.Interface().(time.Time))
	case cmdschema.List:
		if v.Kind() == reflect.Slice && v.IsNil() {
			w.i32(-1)
			return
		}
		w.i32(int32(v.Len()))
		for i := range v.Len() {
			encTyped(w, v.Index(i), t.Elem())
		}
	case cmdschema.Map:
		if v.IsNil() {
			w.i32(-1)
			return
		}
		keys := v.MapKeys()
		names := make([]string, len(keys))
		for i, k := range keys {
			names[i] = anyKey(k)
		}
		order := make([]int, len(keys))
		for i := range order {
			order[i] = i
		}
		sort.Slice(order, func(a, b int) bool { return names[order[a]] < names[order[b]] })
		w.i32(int32(len(keys)))
		for _, i := range order {
			w.str(names[i])
			encTyped(w, v.MapIndex(keys[i]), t.Elem())
		}
	case cmdschema.Struct:
		for _, f := range cmdschema.Fields(t) {
			encTyped(w, v.FieldByIndex(f.Index), f.Type)
		}
	case cmdschema.Ptr:
		if v.IsNil() {
			w.u8(0)
			return
		}
		w.u8(1)
		encTyped(w, v.Elem(), t.Elem())
	case cmdschema.Any:
		encAnyValue(w, v)
	}
}
