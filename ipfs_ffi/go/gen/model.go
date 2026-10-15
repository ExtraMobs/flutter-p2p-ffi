package main

import (
	"fmt"
	"go/types"
	"sort"
	"strings"
)

// kind: como um tipo Go atravessa a ponte.
type kind int

const (
	kUnsupported kind = iota
	kBasic            // bool, inteiros, floats, string (e tipos nomeados sobre eles)
	kBytes            // []byte → Uint8List (base64 no JSON)
	kValue            // tipo-valor da tabela valueTypes (string no JSON)
	kDTO              // struct só com campos exportados → classe com os campos
	kSnap             // interface só com getters (BlockStat, Pin...) → classe com os valores
	kHandle           // objeto com estado (ponteiro, interface) → handle
	kSlice            // []T
	kMap              // map[string]T
	kOpts             // opção funcional (options.UnixfsAddOption) → GoOption
	kCtx              // context.Context
	kWriter           // io.Writer: o Dart não passa; o Go usa io.Discard
	kChanSend         // chan<- T passado pelo chamador (o kubo fecha)
	kChanRecv         // <-chan T devolvido
	kError
	kAny // any / interface{}: valor dinâmico com etiqueta (WIRE.md)
)

// valueSpec: tipo-valor convertido por funções escritas à mão em wire.go.
type valueSpec struct {
	dec, enc   string // funções Go em wire.go
	dartClass  string // classe Dart ("" = tipo do dart:core)
	dartExtend string // classe base Dart (ImmutablePath extends Path)
	dartDec    string // decodificação Dart de %s (só para tipos do dart:core)
	json       bool   // classe Dart que guarda o JSON cru (config.Config)
}

var valueTypes = map[string]valueSpec{
	"github.com/ipfs/go-cid.Cid":                     {dec: "decCid", enc: "encCid", dartClass: "Cid"},
	"github.com/ipfs/boxo/path.Path":                 {dec: "decPath", enc: "encPath", dartClass: "Path"},
	"github.com/ipfs/boxo/path.ImmutablePath":        {dec: "decImmutablePath", enc: "encImmutablePath", dartClass: "ImmutablePath", dartExtend: "Path"},
	"github.com/libp2p/go-libp2p/core/peer.ID":       {dec: "decPeerID", enc: "encPeerID", dartClass: "Id"},
	"github.com/multiformats/go-multiaddr.Multiaddr": {dec: "decMultiaddr", enc: "encMultiaddr", dartClass: "Multiaddr"},
	"time.Time":                          {dec: "decTime", enc: "encTime", dartDec: "DateTime.parse(%s as String)"},
	"github.com/ipfs/kubo/config.Config": {dec: "decConfig", enc: "encConfig", dartClass: "Config", json: true},
	"github.com/ipfs/boxo/ipns.Name":     {dec: "decIpnsName", enc: "encIpnsName", dartClass: "Name"},
}

// handleTypes: interfaces que parecem só-getters mas são recursos (handle).
var handleTypes = setOf(`os.FileInfo`)

type tinfo struct {
	k      kind
	t      types.Type
	key    string       // types.TypeString completo (identidade)
	named  *types.Named // tipo nomeado (classe Dart) de kValue/kDTO/kSnap/kHandle/kOpts
	ptr    bool         // kDTO/kValue por ponteiro (*BuildCfg, *config.Config)
	elem   *tinfo       // kSlice, kMap, kChanSend, kChanRecv
	mkey   *tinfo       // kMap com chave tipo-valor (nil = chave string)
	val    valueSpec
	why    string // kUnsupported
	fields []field
	gets   []getter
	ctors  []optCtor // kOpts
	super  *tinfo    // kHandle de interface: primeira interface embutida com classe
	reader bool      // handle de io.Reader: o Dart também pode passar bytes
}

type field struct {
	name    string
	t       *tinfo
	skipped string // motivo, se o campo não atravessa
}

type getter struct {
	name   string
	t      *tinfo
	hasErr bool
}

// optCtor: construtor de opção, ex. path [Unixfs Pin] → options.Unixfs.Pin(...).
type optCtor struct {
	path   []string
	params []*tinfo
	pnames []string
	hasErr bool
}

type model struct {
	load    func(path string) *types.Package // pacote completo (dependências vêm parciais)
	types   map[string]*tinfo
	optPkgs map[*types.Package]map[string][]optCtor // tipo da opção → construtores
	omitted []string                                // linhas do API.md
}

func newModel() *model {
	return &model{types: map[string]*tinfo{}, optPkgs: map[*types.Package]map[string][]optCtor{}}
}

func objKey(o types.Object) string {
	if o.Pkg() == nil {
		return o.Name()
	}
	return o.Pkg().Path() + "." + o.Name()
}

func (m *model) classify(t types.Type) *tinfo {
	key := types.TypeString(t, nil)
	if ti, ok := m.types[key]; ok {
		return ti
	}
	ti := &tinfo{t: t, key: key}
	m.types[key] = ti // antes de descer: tipos recursivos
	m.fill(ti)
	return ti
}

func unsupported(ti *tinfo, format string, a ...any) {
	ti.k = kUnsupported
	ti.why = fmt.Sprintf(format, a...)
}

func (m *model) fill(ti *tinfo) {
	switch t := ti.t.(type) {
	case *types.Basic:
		switch {
		case t.Info()&(types.IsBoolean|types.IsInteger|types.IsFloat|types.IsString) != 0 && t.Kind() != types.UnsafePointer && t.Kind() != types.Uintptr:
			ti.k = kBasic
		default:
			unsupported(ti, "tipo básico %s", t)
		}
	case *types.Slice:
		if b, ok := t.Elem().(*types.Basic); ok && b.Kind() == types.Byte {
			ti.k = kBytes
			return
		}
		ti.k, ti.elem = kSlice, m.classify(t.Elem())
		if ti.elem.k == kUnsupported {
			unsupported(ti, "[]%s", ti.elem.why)
		}
	case *types.Map:
		// chave string (ou nomeado sobre string) vai direto no JSON; chave
		// tipo-valor (peer.ID) passa pelo conversor da tabela.
		if b, ok := t.Key().Underlying().(*types.Basic); !ok || b.Kind() != types.String {
			unsupported(ti, "mapa com chave %s", t.Key())
			return
		}
		if kt := m.classify(t.Key()); kt.k == kValue && !kt.val.json {
			ti.mkey = kt
		}
		ti.k, ti.elem = kMap, m.classify(t.Elem())
		if ti.elem.k == kUnsupported {
			unsupported(ti, "map[string]%s", ti.elem.why)
		}
	case *types.Chan:
		ti.elem = m.classify(t.Elem())
		switch {
		case ti.elem.k == kUnsupported:
			unsupported(ti, "chan de %s", ti.elem.why)
		case t.Dir() == types.SendOnly:
			ti.k = kChanSend
		case t.Dir() == types.RecvOnly:
			ti.k = kChanRecv
		default:
			unsupported(ti, "chan bidirecional")
		}
	case *types.Pointer:
		n, ok := types.Unalias(t.Elem()).(*types.Named)
		if !ok {
			unsupported(ti, "ponteiro para %s", t.Elem())
			return
		}
		inner := m.classify(n)
		switch inner.k {
		case kDTO, kValue:
			*ti = *inner
			ti.t, ti.key, ti.ptr = t, types.TypeString(t, nil), true
		case kHandle:
			ti.k, ti.named = kHandle, n
		default:
			if inner.k == kUnsupported {
				unsupported(ti, "*%s", inner.why)
			} else {
				unsupported(ti, "ponteiro para %s", n)
			}
		}
	case *types.Named:
		m.fillNamed(ti, t)
	case *types.Interface:
		if t.Empty() {
			ti.k = kAny
			return
		}
		unsupported(ti, "interface sem nome %s", ti.t)
	case *types.Alias:
		// any e interface{} têm a mesma chave: preenche aqui, sem voltar ao
		// cache (que devolveria este mesmo tinfo, ainda vazio)
		if u := types.Unalias(t); types.TypeString(u, nil) == ti.key {
			ti.t = u
			m.fill(ti)
		} else {
			*ti = *m.classify(u)
		}
	default:
		unsupported(ti, "%s", ti.t)
	}
}

func (m *model) fillNamed(ti *tinfo, n *types.Named) {
	obj := n.Obj()
	key := objKey(obj)
	ti.named = n
	if v, ok := valueTypes[key]; ok {
		ti.k, ti.val = kValue, v
		return
	}
	switch key {
	case "context.Context":
		ti.k = kCtx
		return
	case "error":
		ti.k = kError
		return
	case "io.Writer":
		ti.k = kWriter
		return
	case "io.Reader":
		ti.k, ti.reader = kHandle, true
		return
	}
	if obj.Pkg() == nil || !obj.Exported() || strings.Contains(obj.Pkg().Path()+"/", "/internal/") {
		unsupported(ti, "tipo não exportável %s", key)
		return
	}
	if n.TypeArgs().Len() > 0 {
		unsupported(ti, "genérico %s", ti.key)
		return
	}
	switch u := n.Underlying().(type) {
	case *types.Basic: // nomeado sobre básico: atravessa como o básico
		b := m.classify(u)
		ti.k, ti.why, ti.named = b.k, b.why, nil
	case *types.Signature:
		if ctors := m.optCtors(obj.Pkg(), key); len(ctors) > 0 {
			ti.k, ti.ctors = kOpts, ctors
			return
		}
		ti.k = kHandle // valor de função opaco (ex. libp2p.RoutingOption): só o Go o cria e o chama
	case *types.Interface:
		m.fillInterface(ti, n, u)
	case *types.Struct:
		m.fillStruct(ti, n, u)
	default:
		unsupported(ti, "tipo %s", key)
	}
}

// Interface: só-getters (sem parâmetros, valores atravessáveis, sem Close)
// vira instantâneo; o resto é handle.
func (m *model) fillInterface(ti *tinfo, n *types.Named, u *types.Interface) {
	ti.k = kHandle
	for i := 0; i < u.NumEmbeddeds(); i++ {
		if en, ok := u.EmbeddedType(i).(*types.Named); ok {
			if e := m.classify(en); e.k == kHandle && !e.reader {
				ti.super = e
				break
			}
		}
	}
	if handleTypes[objKey(n.Obj())] || u.NumMethods() == 0 {
		return
	}
	var gets []getter
	for i := 0; i < u.NumMethods(); i++ {
		f := u.Method(i)
		sig := f.Type().(*types.Signature)
		if !f.Exported() || f.Name() == "Close" || sig.Params().Len() > 0 {
			return
		}
		res, hasErr := splitErr(sig.Results())
		var rt *tinfo
		switch {
		case len(res) == 0 && hasErr: // Err() error: o erro é o valor lido
			rt, hasErr = m.classify(sig.Results().At(0).Type()), false
		case len(res) == 1:
			rt = m.classify(res[0])
		default:
			return
		}
		switch rt.k {
		case kBasic, kBytes, kValue, kDTO, kSnap, kSlice, kMap, kError:
		default:
			return
		}
		gets = append(gets, getter{f.Name(), rt, hasErr})
	}
	sort.Slice(gets, func(i, j int) bool { return gets[i].name < gets[j].name })
	ti.k, ti.gets, ti.super = kSnap, gets, nil
}

// Struct com campo não exportado é handle; senão DTO (campos que não
// atravessam ficam de fora, registrados no API.md).
func (m *model) fillStruct(ti *tinfo, n *types.Named, u *types.Struct) {
	for i := 0; i < u.NumFields(); i++ {
		f := u.Field(i)
		// campo não exportado, ou interface embutida (merkledag.RawNode embute
		// blocks.Block e ipld.Node): é um objeto, não um registro de dados.
		if !f.Exported() || (f.Embedded() && types.IsInterface(f.Type()) && m.classify(f.Type()).k != kValue) {
			ti.k = kHandle
			return
		}
	}
	ti.k = kDTO
	for i := 0; i < u.NumFields(); i++ {
		f := u.Field(i)
		ft := m.classify(f.Type())
		fd := field{name: f.Name(), t: ft}
		switch ft.k {
		case kBasic, kBytes, kValue, kDTO, kSnap, kHandle, kSlice, kMap, kError:
			if ft.k == kSnap {
				fd.skipped = "interface só de leitura"
			}
		default:
			fd.skipped = ft.why
			if fd.skipped == "" {
				fd.skipped = "tipo " + types.TypeString(f.Type(), nil)
			}
		}
		ti.fields = append(ti.fields, fd)
	}
}

func splitErr(res *types.Tuple) ([]types.Type, bool) {
	var out []types.Type
	for i := 0; i < res.Len(); i++ {
		out = append(out, res.At(i).Type())
	}
	if n := len(out); n > 0 && types.TypeString(out[n-1], nil) == "error" {
		return out[:n-1], true
	}
	return out, false
}

// optCtors acha os construtores de uma opção funcional: métodos (exportados)
// de variáveis do pacote, até dois níveis de campos (options.Pin.Ls.All),
// que devolvem a opção (ou opção e erro).
func (m *model) optCtors(pkg *types.Package, optKey string) []optCtor {
	if full := m.load(pkg.Path()); full != nil {
		pkg = full
	}
	byType, ok := m.optPkgs[pkg]
	if !ok {
		byType = map[string][]optCtor{}
		m.optPkgs[pkg] = byType
		scope := pkg.Scope()
		for _, name := range scope.Names() {
			switch o := scope.Lookup(name).(type) {
			case *types.Var:
				if o.Exported() {
					m.walkOpts(pkg, byType, []string{name}, o.Type(), 0)
				}
			case *types.Func: // construtor como função do pacote (mfs.WithMaxLinks)
				if o.Exported() && optShaped(o) {
					m.addOptCtor(pkg, byType, nil, o)
				}
			}
		}
	}
	return byType[optKey]
}

// chanElem: o tipo real dos itens de um canal `chan<- any` passado numa opção
// (o kubo documenta o que envia; o tipo Go não diz).
var chanElem = map[string][2]string{
	"github.com/ipfs/kubo/core/coreiface/options.Unixfs.Events": {"github.com/ipfs/kubo/core/coreiface", "AddEvent"},
}

// sinkParam: parâmetro `chan<- T` de construtor de opção vira, no Dart, um
// StreamSink; os itens têm o tipo de chanElem quando o canal é de `any`.
func (m *model) sinkParam(ctorKey string, ch *types.Chan) *tinfo {
	ti := &tinfo{k: kChanSend, t: ch, key: "sink:" + ctorKey}
	elem := ch.Elem()
	if e, ok := chanElem[ctorKey]; ok {
		if p := m.load(e[0]); p != nil {
			if tn, ok := p.Scope().Lookup(e[1]).(*types.TypeName); ok {
				elem = types.NewPointer(tn.Type())
			}
		}
	}
	ti.elem = m.classify(elem)
	if !okElem(ti.elem) {
		unsupported(ti, "canal de %s", describe(ti.elem))
	}
	return ti
}

func (m *model) walkOpts(pkg *types.Package, byType map[string][]optCtor, path []string, t types.Type, depth int) {
	ms := types.NewMethodSet(t)
	for i := 0; i < ms.Len(); i++ {
		if f := ms.At(i).Obj().(*types.Func); f.Exported() {
			m.addOptCtor(pkg, byType, path, f)
		}
	}
	if s, ok := t.Underlying().(*types.Struct); ok && depth < 2 {
		for i := 0; i < s.NumFields(); i++ {
			if f := s.Field(i); f.Exported() {
				m.walkOpts(pkg, byType, append(append([]string{}, path...), f.Name()), f.Type(), depth+1)
			}
		}
	}
}

// optShaped: [f] devolve uma opção funcional de verdade, `func(*T)` ou
// `func(*T) error` (mfs.Option, namesys.ResolveOption); uma função que
// devolve outro tipo func (libp2p.ConstructDefaultRouting → RoutingOption)
// não é construtor de opção.
func optShaped(f *types.Func) bool {
	res, _ := splitErr(f.Type().(*types.Signature).Results())
	if len(res) != 1 {
		return false
	}
	sig, ok := res[0].Underlying().(*types.Signature)
	if !ok || sig.Params().Len() != 1 {
		return false
	}
	if _, ok := sig.Params().At(0).Type().(*types.Pointer); !ok {
		return false
	}
	r := sig.Results()
	return r.Len() == 0 || (r.Len() == 1 && types.TypeString(r.At(0).Type(), nil) == "error")
}

// addOptCtor registra [f] (método de uma variável em [path], ou função do
// pacote com path vazio) se ele devolve uma opção funcional (ou opção e erro).
func (m *model) addOptCtor(pkg *types.Package, byType map[string][]optCtor, path []string, f *types.Func) {
	sig := f.Type().(*types.Signature)
	res, hasErr := splitErr(sig.Results())
	if len(res) != 1 {
		return
	}
	rn, ok := res[0].(*types.Named)
	if !ok {
		return
	}
	if _, isSig := rn.Underlying().(*types.Signature); !isSig {
		return
	}
	c := optCtor{path: append(append([]string{}, path...), f.Name()), hasErr: hasErr}
	for j := 0; j < sig.Params().Len(); j++ {
		p := sig.Params().At(j)
		if ch, ok := p.Type().(*types.Chan); ok && ch.Dir() == types.SendOnly {
			c.params = append(c.params, m.sinkParam(pkg.Path()+"."+strings.Join(c.path, "."), ch))
		} else {
			c.params = append(c.params, m.classify(p.Type()))
		}
		c.pnames = append(c.pnames, p.Name())
	}
	k := objKey(rn.Obj())
	byType[k] = append(byType[k], c)
}

// okOptCtor: construtor cujos parâmetros atravessam.
func okOptCtor(c optCtor) (bool, string) {
	for i, p := range c.params {
		switch p.k {
		case kBasic, kBytes, kValue, kSlice, kMap, kHandle, kChanSend, kAny, kOpts:
		default:
			why := p.why
			if why == "" {
				why = types.TypeString(p.t, nil)
			}
			return false, fmt.Sprintf("parâmetro %s: %s", c.pnames[i], why)
		}
	}
	return true, ""
}

// usableCtors: construtores da opção cujos parâmetros atravessam, por caminho
// (o Dart). No fio vai o índice em t.ctors (WIRE.md), não a posição aqui.
func usableCtors(t *tinfo) []optCtor {
	var out []optCtor
	for _, c := range t.ctors {
		if ok, _ := okOptCtor(c); ok {
			out = append(out, c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return strings.Join(out[i].path, ".") < strings.Join(out[j].path, ".") })
	return out
}
