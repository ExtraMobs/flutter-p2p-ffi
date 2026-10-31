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
	kAny  // any / interface{}: valor dinâmico com etiqueta (WIRE.md)
	kFunc // função passada pelo Dart (callback sob demanda, WIRE.md): só em parâmetro
)

// Resultado de um callback (kFunc): nada, bool (false para) ou error (para);
// fretVal: a basic value (pubsub.ValidationResult), only for a retained one.
const (
	fretNone = iota
	fretBool
	fretErr
	fretVal
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

// handleTypes: interfaces que parecem só-getters mas são recursos, e structs
// só de campos exportados que são objetos (o LinkSystem guarda funções; the
// NullDatastore has no fields, only the methods of a datastore).
var handleTypes = setOf(`os.FileInfo github.com/ipld/go-ipld-prime/linking.LinkSystem github.com/ipfs/go-datastore.NullDatastore
github.com/libp2p/go-libp2p/p2p/muxer/yamux.Transport`)

// ioMethods: os métodos de uma interface de E/S (io.ReaderAt, io.ReadSeeker,
// car.SectionReader...): em parâmetro ela aceita bytes ou qualquer handle,
// como o io.Reader (tinfo.reader).
var ioMethods = setOf(`Read ReadAt Seek Write WriteAt Close`)

type tinfo struct {
	k      kind
	t      types.Type
	key    string       // types.TypeString completo (identidade)
	named  *types.Named // tipo nomeado (classe Dart) de kValue/kDTO/kSnap/kHandle/kOpts
	ptr    bool         // kDTO/kValue por ponteiro (*BuildCfg, *config.Config)
	elem   *tinfo       // kSlice, kMap, kChanSend, kChanRecv
	mkey   *tinfo       // kMap com chave tipo-valor ou inteira (nil = chave string)
	val    valueSpec
	why    string // kUnsupported
	fields []field
	gets   []getter
	ctors  []optCtor // kOpts
	super  *tinfo    // kHandle de interface: primeira interface embutida com classe
	reader bool      // handle de interface de E/S (io.Reader, io.ReaderAt...): o Dart também pode passar bytes
	fargs  []*tinfo  // kFunc: os argumentos do callback
	fnames []string  // kFunc: os nomes deles ("" se o Go não nomeia)
	fret   int       // kFunc: fretNone, fretBool ou fretErr
	dur    bool      // kBasic time.Duration: Duration in Dart (nanoseconds on the wire)
	// kFunc: Go keeps the function past the call (retainedFuncs, a Dart
	// implementation of an interface): WIRE.md, "Retained callback"
	retained bool
	// kFunc retained by default (a "pkg.*" root nobody checked): Go may call
	// it during the call or keep it, so the call is asynchronous and each
	// invocation waits for Dart, which runs them all before the call returns
	unchecked bool
	fres      *tinfo    // kFunc fretVal: the type of the value
	fthrow    [2]string // kFunc fretVal: the Go constant (package, name) when Dart throws (cbOnThrow); "" = the zero value
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
	pkg      *types.Package // the package of the constructor (libp2p's options build config.Option)
	path     []string
	params   []*tinfo
	pnames   []string
	hasErr   bool
	variadic bool // the last parameter is variadic (libp2p.EnableHolePunching(opts ...holepunch.Option))
	isVar    bool // a package variable of the option type (libp2p.NoListenAddrs): no call
	varSig   *types.Signature
	fn       *types.Func // the constructor (its parameters: ctorParams)
	omit     string      // omitCtors: o motivo
}

// omitCtors: construtores de opção que ficam de fora de propósito (o
// parâmetro é de um módulo que não vale um namespace), com o motivo (API.md).
var omitCtors = map[string]string{
	"github.com/ipfs/boxo/gateway.WithPrometheusRegistry":     "Prometheus metrics (no namespace; the gateway uses the default registry)",
	"github.com/libp2p/go-libp2p.PrometheusRegisterer":        "Prometheus metrics (no namespace; libp2p uses the default registerer)",
	"github.com/libp2p/go-libp2p.DefaultPrometheusRegisterer": "Prometheus metrics (no namespace; libp2p uses the default registerer)",
	"github.com/libp2p/go-libp2p.WithFxOption":                "the fx dependency injection inside libp2p (Go values only)",
}

type model struct {
	load     func(path string) *types.Package // pacote completo (dependências vêm parciais)
	newTypes map[string]bool                  // structs com construtor vazio (raiz que é só o tipo): handles
	types    map[string]*tinfo
	optPkgs  map[*types.Package]map[string][]optCtor // tipo da opção → construtores
	omitted  []string                                // linhas do API.md
	// optAlias: the packages that declare an alias of an option type
	// (libp2p.Option = config.Option): its constructors live there.
	optAlias map[string][]*types.Package
	// via: an internal package reached through an exported alias of the same
	// name (dht.Option = internal/config.Option): its types are spelled, and
	// their Dart class lives, in the alias's package.
	via    map[string]*types.Package // an internal type (objKey) → the exported package that aliases it with its name
	viaPkg map[string]*types.Package // an internal package → one that aliases a type of it
	// toks: the type and function tokens (tokens.go)
	toks []*token
	// deprecated: the Go doc's "Deprecated:" text, by depKey (deprecated.go)
	deprecated map[string]string
	// expanded: the roots that came from a "pkg.*" line, not written out
	expanded map[string]bool
	// platform: the constants whose value depends on the target (platform.go)
	platform    map[string]string
	platformObj map[string]*types.Const // each one as a target that has it declares it
	// platformDecl: the other symbols some target lacks or declares otherwise
	platformDecl map[string]bool
}

func newModel() *model {
	return &model{types: map[string]*tinfo{}, optPkgs: map[*types.Package]map[string][]optCtor{}, newTypes: map[string]bool{},
		optAlias: map[string][]*types.Package{}, via: map[string]*types.Package{}, viaPkg: map[string]*types.Package{}}
}

// home: the package where [p] is seen from outside (its own, or an exported
// one that aliases a type of the internal [p]).
func (m *model) home(p *types.Package) *types.Package {
	if v, ok := m.viaPkg[p.Path()]; ok {
		return v
	}
	return p
}

// homeOf: the package where the type [o] is seen from outside: an internal
// type, the one that aliases it (pebble.KeyRange = base.KeyRange, while
// sstable aliases other types of base).
func (m *model) homeOf(o types.Object) *types.Package {
	if v, ok := m.via[objKey(o)]; ok {
		return v
	}
	return m.home(o.Pkg())
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
			unsupported(ti, "basic type %s", t)
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
		// chave string (ou nomeado sobre string) vai como string; chave
		// tipo-valor (peer.ID) passa pelo conversor da tabela; chave inteira
		// (multicodec.Code) vai como o inteiro.
		b, ok := t.Key().Underlying().(*types.Basic)
		switch {
		case ok && b.Kind() == types.String:
			if kt := m.classify(t.Key()); kt.k == kValue && !kt.val.json {
				ti.mkey = kt
			}
		case ok && b.Info()&types.IsInteger != 0 && b.Kind() != types.Uintptr:
			ti.mkey = m.classify(t.Key())
		default:
			unsupported(ti, "map keyed by %s", t.Key())
			return
		}
		ti.k, ti.elem = kMap, m.classify(t.Elem())
		if ti.elem.k == kUnsupported {
			unsupported(ti, "map[string]%s", ti.elem.why)
		}
	case *types.Chan:
		ti.elem = m.classify(t.Elem())
		switch {
		case ti.elem.k == kUnsupported:
			unsupported(ti, "chan of %s", ti.elem.why)
		case t.Dir() == types.SendOnly:
			ti.k = kChanSend
		case t.Dir() == types.RecvOnly:
			ti.k = kChanRecv
		default:
			unsupported(ti, "bidirectional chan")
		}
	case *types.Pointer:
		if b, ok := t.Elem().(*types.Basic); ok { // *int64 (DagByteRange.To): o básico ou nil
			*ti = *m.classify(b)
			ti.t, ti.key = t, types.TypeString(t, nil)
			if ti.k == kBasic {
				ti.ptr = true
			}
			return
		}
		n, ok := types.Unalias(t.Elem()).(*types.Named)
		if !ok {
			unsupported(ti, "pointer to %s", t.Elem())
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
				unsupported(ti, "pointer to %s", n)
			}
		}
	case *types.Named:
		m.fillNamed(ti, t)
	case *types.Interface:
		if t.Empty() {
			ti.k = kAny
			return
		}
		unsupported(ti, "unnamed interface %s", ti.t)
	case *types.Alias:
		// any e interface{} têm a mesma chave: preenche aqui, sem voltar ao
		// cache (que devolveria este mesmo tinfo, ainda vazio)
		if u := types.Unalias(t); types.TypeString(u, nil) == ti.key {
			ti.t = u
			m.fill(ti)
		} else {
			if n, ok := u.(*types.Named); ok && t.Obj().Exported() && t.Obj().Pkg() != nil {
				if _, isSig := n.Underlying().(*types.Signature); isSig {
					m.optAlias[objKey(n.Obj())] = append(m.optAlias[objKey(n.Obj())], t.Obj().Pkg())
				}
				if tp := n.Obj().Pkg(); tp != nil && isInternal(tp.Path()) && n.Obj().Name() == t.Obj().Name() {
					m.viaPkg[tp.Path()] = t.Obj().Pkg()
					// every type of tp the exported package aliases by name, before
					// descending (server.TaskComparator's func takes *decision.TaskInfo,
					// which server aliases too)
					scope := t.Obj().Pkg().Scope()
					for _, name := range scope.Names() {
						if a, ok := scope.Lookup(name).(*types.TypeName); ok && a.IsAlias() && a.Exported() {
							if an, ok := types.Unalias(a.Type()).(*types.Named); ok && an.Obj().Pkg() == tp && an.Obj().Name() == name {
								if _, seen := m.via[objKey(an.Obj())]; !seen {
									m.via[objKey(an.Obj())] = t.Obj().Pkg()
								}
							}
						}
					}
				}
			}
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
	if obj.Pkg() == nil || !obj.Exported() || (isInternal(obj.Pkg().Path()) && m.via[objKey(obj)] == nil) {
		unsupported(ti, "unexported type %s", key)
		return
	}
	if m.platformDecl[key] {
		unsupported(ti, "type %s %s", key, platformWhy)
		return
	}
	if n.TypeArgs().Len() > 0 {
		unsupported(ti, "generic %s", ti.key)
		return
	}
	switch u := n.Underlying().(type) {
	case *types.Basic: // nomeado sobre básico: atravessa como o básico
		b := m.classify(u)
		ti.k, ti.why, ti.named, ti.dur = b.k, b.why, nil, key == "time.Duration"
	case *types.Slice: // nomeado sobre []byte (multihash.Multihash): bytes
		if b, ok := u.Elem().(*types.Basic); ok && b.Kind() == types.Byte {
			ti.k, ti.named = kBytes, nil
			return
		}
		// a named slice (peer.IDSlice) crosses as the slice
		s := m.classify(u)
		ti.k, ti.why, ti.elem, ti.named = s.k, s.why, s.elem, nil
	case *types.Signature:
		ctors := m.optCtors(obj.Pkg(), n)
		for _, p := range m.optAlias[key] {
			ctors = append(ctors, m.optCtors(p, n)...)
		}
		if len(ctors) > 0 {
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
	if isIO(u) {
		ti.reader, ti.super = true, nil
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
	if handleTypes[objKey(n.Obj())] || m.newTypes[objKey(n.Obj())] {
		ti.k = kHandle
		return
	}
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
				fd.skipped = "read-only interface"
			}
			if (ft.k == kSlice || ft.k == kMap) && ft.elem.k == kOpts { // config.Config.RelayServiceOpts
				fd.skipped = "functional options: they cross only as call arguments"
			}
		default:
			fd.skipped = ft.why
			if fd.skipped == "" {
				fd.skipped = "type " + types.TypeString(f.Type(), nil)
			}
		}
		ti.fields = append(ti.fields, fd)
	}
}

// funcParam: parâmetro de tipo função (sem nome, ou nomeado como
// fetcher.FetchCallback) que o Dart passa: o callback sob demanda (WIRE.md).
// Só os que devolvem nada, bool ou error; nil se não é um desses (uma função
// que devolve outra coisa, como libp2p.RoutingOption, segue handle opaco).
func (m *model) funcParam(t types.Type) *tinfo {
	sig, ok := t.Underlying().(*types.Signature)
	if !ok || sig.Variadic() {
		return nil
	}
	ti := &tinfo{k: kFunc, t: t, key: "func:" + types.TypeString(t, nil)}
	if n, ok := types.Unalias(t).(*types.Named); ok {
		ti.named = n
	}
	switch r := sig.Results(); {
	case r.Len() == 0:
	case r.Len() == 1 && types.TypeString(r.At(0).Type(), nil) == "error":
		ti.fret = fretErr
	case r.Len() == 1:
		b, ok := r.At(0).Type().Underlying().(*types.Basic)
		switch {
		case ok && b.Kind() == types.Bool:
			ti.fret = fretBool
		case ok:
			if ti.fres = m.classify(r.At(0).Type()); ti.fres.k != kBasic {
				return nil
			}
			ti.fret = fretVal
			ti.fthrow = cbOnThrow[types.TypeString(t, nil)]
		default:
			return nil
		}
	default:
		return nil
	}
	for i := 0; i < sig.Params().Len(); i++ {
		v := sig.Params().At(i)
		a := m.classify(v.Type())
		if !okElem(a) && a.k != kCtx { // a context arrives as its handle (pubsub's validators)
			unsupported(ti, "callback with argument %s", describe(a))
			return ti
		}
		ti.fargs = append(ti.fargs, a)
		ti.fnames = append(ti.fnames, v.Name())
	}
	return ti
}

// cbOnThrow: what a retained callback that returns a value answers Go when
// the Dart function throws, by the callback's Go type (the zero value would
// accept a message: ValidationAccept is 0).
var cbOnThrow = map[string][2]string{
	"github.com/libp2p/go-libp2p-pubsub.ValidatorEx": {"github.com/libp2p/go-libp2p-pubsub", "ValidationReject"},
}

// isIO: interface só de métodos de E/S, com ao menos um de dados.
func isIO(u *types.Interface) bool {
	data := false
	for i := 0; i < u.NumMethods(); i++ {
		name := u.Method(i).Name()
		if !ioMethods[name] {
			return false
		}
		data = data || (name != "Seek" && name != "Close")
	}
	return data
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
func (m *model) optCtors(pkg *types.Package, opt *types.Named) []optCtor {
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
				if !o.Exported() {
					continue
				}
				// a variable that is an option (libp2p.NoListenAddrs, of the
				// option's type or of its unnamed func type)
				if sig, ok := o.Type().Underlying().(*types.Signature); ok {
					if optSig(sig) {
						c := optCtor{pkg: pkg, path: []string{name}, isVar: true, varSig: sig}
						if why, ok := omitCtors[pkg.Path()+"."+name]; ok {
							c.omit = why
						}
						byType[varCtors] = append(byType[varCtors], c)
					}
					continue
				}
				m.walkOpts(pkg, byType, []string{name}, o.Type(), 0)
			case *types.Func: // construtor como função do pacote (mfs.WithMaxLinks)
				if o.Exported() && optShaped(o) {
					m.addOptCtor(pkg, byType, nil, o)
				}
			}
		}
	}
	var out []optCtor
	for _, c := range byType[objKey(opt.Obj())] {
		out = append(out, m.ctorParams(c))
	}
	for _, c := range byType[varCtors] {
		if types.Identical(c.varSig, opt.Underlying()) {
			out = append(out, c)
		}
	}
	return out
}

// varCtors: the key of a package's option variables in optPkgs (matched to
// an option type by signature: libp2p.NoListenAddrs is a bare func literal).
const varCtors = "vars"

func isInternal(path string) bool { return strings.Contains(path+"/", "/internal/") }

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
		unsupported(ti, "channel of %s", describe(ti.elem))
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
	return ok && optSig(sig)
}

// optSig: `func(*T)` or `func(*T) error`.
func optSig(sig *types.Signature) bool {
	if sig.Params().Len() != 1 {
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
	rn, ok := types.Unalias(res[0]).(*types.Named)
	if !ok {
		return
	}
	if _, isSig := rn.Underlying().(*types.Signature); !isSig {
		return
	}
	c := optCtor{pkg: pkg, path: append(append([]string{}, path...), f.Name()), hasErr: hasErr, variadic: sig.Variadic(), fn: f}
	if why, ok := omitCtors[pkg.Path()+"."+strings.Join(c.path, ".")]; ok {
		c.omit = why // sem classificar os parâmetros: o tipo deles não entra
	}
	k := objKey(rn.Obj())
	byType[k] = append(byType[k], c)
}

// ctorParams: the parameters of [c], classified only when its option type is
// asked for, after the whole package was scanned (a parameter may be another
// option of the same package: pubsub.WithDefaultValidator takes ValidatorOpt).
func (m *model) ctorParams(c optCtor) optCtor {
	if c.fn == nil || c.omit != "" {
		return c
	}
	sig := c.fn.Type().(*types.Signature)
	c.params, c.pnames = nil, nil
	for j := 0; j < sig.Params().Len(); j++ {
		p := sig.Params().At(j)
		ch, isChan := p.Type().(*types.Chan)
		switch ft := m.funcParam(p.Type()); {
		case isChan && ch.Dir() == types.SendOnly:
			c.params = append(c.params, m.sinkParam(c.pkg.Path()+"."+strings.Join(c.path, "."), ch))
		case ft != nil && ft.k != kUnsupported && m.classify(p.Type()).k != kOpts: // an option inside an option stays one (namesys.ResolveOption)
			// a function the option keeps (pubsub.WithMessageFilter): a
			// retained callback, called for as long as Go holds the option's
			// result
			ft.retained = true
			c.params = append(c.params, ft)
		default:
			c.params = append(c.params, m.classify(p.Type()))
		}
		c.pnames = append(c.pnames, p.Name())
	}
	return c
}

// okOptCtor: construtor cujos parâmetros atravessam.
func okOptCtor(c optCtor) (bool, string) {
	if c.omit != "" {
		return false, c.omit
	}
	for i, p := range c.params {
		switch p.k {
		case kBasic, kBytes, kValue, kDTO, kMap, kHandle, kChanSend, kAny, kOpts:
		case kFunc: // retained (ctorParams): the option keeps it
		case kSlice:
			if p.elem.k == kOpts || okElem(p.elem) {
				break
			}
			return false, fmt.Sprintf("parameter %s: %s", c.pnames[i], describe(p))
		default:
			why := p.why
			if why == "" {
				why = types.TypeString(p.t, nil)
			}
			return false, fmt.Sprintf("parameter %s: %s", c.pnames[i], why)
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
