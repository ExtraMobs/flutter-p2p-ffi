"""Descritores de reflexão (M5, decisão D1): o dicionário estático de cada
tipo que o `reflect` do golib_dart lê.

Só num grafo que usa reflexão (algum pacote importa `reflect` ou um shim
construído sobre ele, `REFLECT_PKGS`): fora disso nada muda no Dart gerado.
Com reflexão, cada tipo nomeado não genérico ganha na sua classe

    static final go.RType<T> $rt = go.rtStruct<T>(...);   // ou rtNamed...
    @override go.RType get $rtype => $rt;                  // `implements go.Typed`

com nome, pacote, kind, tamanho, method sets e, nas structs, os campos (nome,
tag, tipo, getter e setter como closures). Tipos sem nome saem em runtime dos
descritores dos elementos (`go.rtPtr(...)`, `go.rtSlice(...)`, com cache), e
cada `go.Elem` leva o descritor do seu tipo (`type:`), de onde o `reflect`
tira o tipo dinâmico de um `[]T`/`map[K]V` guardado numa interface.

ponytail: o recorte é "todo tipo nomeado não genérico de um grafo com
reflexão", não "só os que chegam a uma interface" (exigiria uma análise de
fluxo do grafo inteiro); o Dart compilado (AOT/dart2js) ainda descarta o que
nenhum `$rtype` alcança. Genéricos instanciados e tipos de shim sem
descritor viram `go.rtOpaque` (nome e kind; campos desconhecidos: o reflect
dá panic explícito ao listá-los).
"""

from g2d.model import Unsupported
from g2d.config import REFLECT_PKGS, SHIM_RTYPES, STDLIB_SHIMS
from g2d.engine.behavior import Service
from g2d.services.naming import member_name, type_name

# Kind Go de cada básico (nome na typeTable → constante `go.k*`).
_BASIC_KIND = {
    "bool": "kBool", "int": "kInt", "int8": "kInt8", "int16": "kInt16", "int32": "kInt32", "rune": "kInt32",
    "int64": "kInt64", "uint": "kUint", "uint8": "kUint8", "byte": "kUint8", "uint16": "kUint16",
    "uint32": "kUint32", "uint64": "kUint64", "uintptr": "kUintptr", "float32": "kFloat32",
    "float64": "kFloat64", "complex64": "kComplex64", "complex128": "kComplex128", "string": "kString",
    "unsafe.Pointer": "kUnsafePointer", "Pointer": "kUnsafePointer",
}

_BASIC_RT = {
    "bool": "rtBool", "int": "rtInt", "int8": "rtInt8", "int16": "rtInt16", "int32": "rtInt32", "rune": "rtInt32",
    "int64": "rtInt64", "uint": "rtUint", "uint8": "rtUint8", "byte": "rtUint8", "uint16": "rtUint16",
    "uint32": "rtUint32", "uint64": "rtUint64", "uintptr": "rtUintptr", "float32": "rtFloat32",
    "float64": "rtFloat64", "complex64": "rtComplex64", "complex128": "rtComplex128", "string": "rtString",
    "unsafe.Pointer": "rtUnsafePointer", "Pointer": "rtUnsafePointer",
}

_KIND = {"slice": "kSlice", "map": "kMap", "array": "kArray", "func": "kFunc", "chan": "kChan",
         "pointer": "kPointer", "interface": "kInterface", "struct": "kStruct"}

_CHAN_DIR = {"recv": 1, "send": 2, "both": 3}


def reflective_pkg(pkg):
    """O pacote importa `reflect` ou um shim que reflete (`encoding/json`)?"""
    return any(i["path"] in REFLECT_PKGS for i in pkg.imports)


class Reflection(Service):
    """Descritores `go.RType` dos tipos Go (ver o docstring do módulo)."""

    name = "reflection"

    @property
    def enabled(self):
        """Grafo com reflexão: a ColorTable do grafo diz (`reflective`); sem
        ela (pacote sozinho), o próprio pacote."""
        colors = self.engine.colors
        if colors is not None and getattr(colors, "reflective", None) is not None:
            return colors.reflective
        return reflective_pkg(self.pkg)

    def go(self, name):
        return self.imports.qualify(None, name)

    # ----------------------------------------------------------- expressões
    def rtype(self, t):
        """Expressão Dart do descritor do tipo Go t."""
        t = self.pkg.type_at(t)
        k = t["kind"]
        if k == "basic":
            name = t["name"].replace("untyped ", "")
            return self.go(_BASIC_RT.get(name, "rtUnsafePointer"))
        if k == "named":
            return self.named_rtype(t)
        if k == "pointer":
            return f"{self.go('rtPtr')}({self.rtype(t['elem'])})"
        if k == "slice":
            return f"{self.go('rtSlice')}({self.rtype(t['elem'])})"
        if k == "array":
            return f"{self.go('rtArray')}({t['len']}, {self.rtype(t['elem'])})"
        if k == "map":
            return f"{self.go('rtMap')}({self.rtype(t['key'])}, {self.rtype(t['elem'])})"
        if k == "chan":
            return f"{self.go('rtChan')}({_CHAN_DIR.get(t['dir'], 3)}, {self.rtype(t['elem'])})"
        if k == "func":
            return self.func_rtype(t)
        if k == "interface":
            if not t["methods"]:
                return self.go("rtAny")
            ms = ", ".join(self.str_lit(m["name"]) for m in t["methods"])
            return (f"{self.go('rtIface')}({self.str_lit(self.goinfo.sharp_type_name(t))}, const [{ms}]"
                    f"{self.sigs_arg(t['methods'])})")
        if k == "struct":
            if not t["fields"]:
                return self.go("rtEmptyStruct")
            return f"{self.types.dart(t).non_null()}.$rt"
        if k == "typeparam":
            return f"{self.go('rtOfElem')}(${t['name']})"
        return f"{self.go('rtOpaque')}({self.str_lit(k)}, {self.go('kInvalid')})"

    def func_rtype(self, t):
        """`go.rtFuncOf` de um tipo func sem nome: parâmetros, resultados,
        variádico e cor `async` (com parâmetro de tipo, o texto Go sai dos
        tipos em runtime)."""
        sig = "''" if self.descriptors.has_tparam(t) else self.str_lit(self.goinfo.sharp_type_name(t))
        ins = ", ".join(self.rtype(p) for p in t["params"])
        outs = ", ".join(self.rtype(r) for r in t["results"])
        extra = ""
        if t.get("variadic"):
            extra += ", variadic: true"
        if self.concurrency.is_async(self.concurrency.sig_key(t)):
            extra += ", async: true"
        dt = self.types.dart(t).as_nullable()
        return f"{self.go('rtFuncOf')}<{dt}>({sig}, () => [{ins}], () => [{outs}]{extra})"

    def named_rtype(self, t):
        if self.typesys.is_universe(t, "error"):
            return self.go("rtError")
        u = self.typesys.underlying(t)
        targs = self.typesys.type_args(t)
        if targs and u["kind"] in ("struct", "slice", "map", "func") and t["pkg"] not in STDLIB_SHIMS and self.imports.transpiled(t["pkg"]):
            dt = str(self.types.dart(t).non_null())
            base, _, rest = dt.partition("<")
            elems = ", ".join(self.descriptors.elem(a) for a in targs)
            return f"{base}.$rtOf<{rest}({elems})"
        if targs or not t["pkg"]:  # instância de genérico não struct; `comparable`
            return self.opaque(t, u)
        if t["pkg"] in STDLIB_SHIMS or not self.imports.transpiled(t["pkg"]):
            if (t["pkg"], t["name"]) in SHIM_RTYPES:
                return f"{self.types.dart(t).non_null()}.$rt"
            if u["kind"] == "interface" and u["methods"]:
                return self.shim_iface(t, u)
            return self.opaque(t, u)
        return f"{self.types.dart(t).non_null()}.$rt"

    def shim_iface(self, t, u):
        """Interface de shim (`json.Marshaler`, `io.Reader`...): descritor com
        o method set, canônico por nome (`go.rtShimIface`). Sem a classe no
        shim, ou com assinatura que o g2d não descreve, fica opaco."""
        key = f"{t['pkg']}.{t['name']}"
        building = self.__dict__.setdefault("_shim_ifaces", set())
        if key in building:  # método que cita a própria interface (thunk: já no cache)
            return f"{self.go('rtShimIfaceRef')}({self.str_lit(key)})"
        building.add(key)
        try:
            cls = self.types.dart(t).as_nullable()
            pkg, name, s = self.common(t)
            ms = ", ".join(self.str_lit(m["name"]) for m in u["methods"])
            return (f"{self.go('rtShimIface')}<{cls}>({pkg}, {name}, {s}, const [{ms}]"
                    f"{self.sigs_arg(u['methods'])})")
        except Unsupported:
            return self.opaque(t, u)
        finally:
            building.discard(key)

    def opaque(self, t, u):
        kind = _KIND.get(u["kind"]) or _BASIC_KIND.get(u.get("name", ""), "kInvalid")
        return f"{self.go('rtOpaque')}({self.str_lit(self.goinfo.sharp_type_name(t))}, {self.go(kind)})"

    @staticmethod
    def str_lit(s):
        return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"

    def map_key(self, t):
        """`, key: <Elem da chave>` dos construtores de `go.GoMap` (só num
        grafo com reflexão: o reflect acha o tipo da chave de um map vazio)."""
        if not self.enabled:
            return ""
        u = self.typesys.underlying(self.pkg.type_at(t))
        if self.descriptors.has_tparam(u["key"]):
            return ""
        return f", key: {self.descriptors.elem(u['key'])}"

    def elem_type_fn(self, t):
        """Nome da função top-level `go.RType _$tN() => ...` do `type:` de um
        `go.Elem` const (None sem reflexão)."""
        if not self.enabled:
            return None
        name = f"_$t{len(self.descriptors.elem_decls)}_{len(self.descriptors.elems)}"
        self.descriptors.elem_decls.append(f"{self.go('RType')} {name}() => {self.rtype(t)};")
        return name

    # ----------------------------------------------------------- membros
    def typed(self):
        """Entrada do `implements` das classes com descritor."""
        return self.go("Typed")

    def instance_member(self):
        return ["@override", f"{self.go('RType')} get $rtype => $rt;"]

    def pkg_path(self, path):
        """`PkgPath()` do Go: o pacote main é `main`, qualquer que seja o
        import path do módulo."""
        return "main" if path == self.pkg.path and self.pkg.name == "main" else path

    def common(self, t):
        """(pacote, nome, String() Go) de um tipo nomeado."""
        return (self.str_lit(self.pkg_path(t["pkg"])), self.str_lit(t["name"]),
                self.str_lit(self.goinfo.sharp_type_name(t)))

    def method_args(self, t, value_methods=True, cls=None):
        vm = ", ".join(self.str_lit(n) for n in self.goinfo.method_names(t, True))
        pm = ", ".join(self.str_lit(n) for n in self.goinfo.method_names(t, False))
        out = f"methods: const [{vm}], ptrMethods: const [{pm}]{self.sigs_arg(t.get('methods') or [])}"
        return out + (self.binds_arg(t, cls) if cls else "")

    def binds_arg(self, t, cls):
        """`binds`/`pbinds`: cada método exportado ligado a um receptor
        (tear-off), para `Value.Method`. Struct: o receptor é o objeto, para
        T e *T. Nomeado não struct: os de receptor valor sobre N, os de `*N`
        sobre a vista `N$Ptr`."""
        struct = self.typesys.underlying(t)["kind"] == "struct"
        tps = self.typesys.type_args(t)
        binds, pbinds = [], []
        for m in sorted(t.get("methods") or [], key=lambda m: m["name"]):
            name = m["name"]
            if not name[:1].isupper() or len(m.get("index") or [0]) > 1 and tps:
                continue  # genérico: sem os promovidos (sem mixin)
            sig = self.pkg.type_at(m["type"])
            dn = self.dualio.members(self.concurrency.method_key(t, name), name, sig)[0][0]
            if struct or not m["ptr"]:
                binds.append(f"{self.str_lit(name)}: (o) => (o as {cls}).{dn}")
            else:
                pcls = self.types.dart(t).non_null().name + "$Ptr"
                targs = cls[len(cls.partition("<")[0]):]
                pbinds.append(f"{self.str_lit(name)}: (o) => {pcls}{targs}(o as {self.imports.qualify(None, 'Ptr')}<{cls}>).{dn}")
        out = ""
        if binds:
            out += ", binds: {" + ", ".join(binds) + "}"
        if pbinds:
            out += ", pbinds: {" + ", ".join(pbinds) + "}"
        return out

    def sigs_arg(self, methods):
        """`, sigs: const {...}`: a assinatura Go de cada método, sem o
        receptor (`Method.Type`); vazio sem métodos."""
        sigs = sorted((m["name"], self.rtype(self.pkg.type_at(m["type"])))
                      for m in methods if m.get("type") is not None)
        if not sigs:
            return ""
        return ", sigs: {" + ", ".join(f"{self.str_lit(n)}: () => {g}" for n, g in sigs) + "}"

    def struct_members(self, cls, t, st, named=True):
        """`$rt`/`$rtype` de uma classe de struct (nomeada, ou sem nome com
        `named` falso)."""
        size, align, ptrs = self.typesys.layout(st)
        pkg, name, s = self.common(t) if named else ("''", "''", self.str_lit(self.goinfo.sharp_type_name(st)))
        fields = ", ".join(self.field(cls, f, off) for f, off in zip(st["fields"], self.offsets(st)))
        methods = self.method_args(t, cls=cls) if named else "methods: const [], ptrMethods: const []"
        desc = (f"{self.go('rtStruct')}<{cls}>({pkg}, {name}, {s}, size: {size}, align: {align}, "
                f"ptrs: {'true' if ptrs else 'false'}, zero: {cls}.new, nil: () => {cls}.$nil, {methods}, "
                f"fields: () => [{fields}])")
        return ["", "/// Descritor de reflexão (`reflect.Type`).",
                f"static final {self.go('RType')}<{cls}> $rt = {desc};"] + self.instance_member()

    def generic_struct_members(self, self_t, decl, tnames, t, st):
        """Struct genérica: `$rtOf<T>($T)` monta (uma vez por argumentos de
        tipo) o descritor da instância, com tamanho e offsets calculados no
        runtime a partir dos campos."""
        pkg = self.str_lit(self.pkg_path(t.get("pkg") or self.pkg.path))
        name = self.str_lit(t.get("name") or "")
        short = self.str_lit(self.pkg.name)
        base = self_t.partition("<")[0]
        fields = ", ".join(self.field(self_t, f, 0) for f in st["fields"])
        args = ", ".join(f"{self.go('rtOfElem')}(${n})" for n in tnames)
        dicts = ", ".join(f"${n}" for n in tnames)
        params = ", ".join(f"{self.imports.qualify(None, 'Elem')}<{n}> ${n}" for n in tnames)
        tl = f"<{', '.join(tnames)}>"
        desc = (f"{self.go('rtStruct')}<{self_t}>({pkg}, n, s, size: -1, align: -1, ptrs: true, "
                f"zero: () => {base}{tl}({dicts}), nil: () => {base}{tl}({dicts})..$nilPtr = true, "
                f"{self.method_args(t, cls=self_t)}, fields: () => [{fields}])")
        return ["", "/// Descritor de reflexão da instância (`reflect.Type`).",
                f"static {self.go('RType')}<{self_t}> $rtOf{decl}({params}) => "
                f"{self.go('rtGeneric')}<{self_t}>({pkg}, {name}, {short}, [{args}], (n, s) => {desc});",
                "@override", f"{self.go('RType')} get $rtype => $rtOf{tl}({dicts});"]

    def offsets(self, st):
        """`unsafe.Offsetof` de cada campo (amd64), como em `layout`."""
        out, off = [], 0
        for f in st["fields"]:
            size, align, _ = self.typesys.layout(f["type"])
            off = (off + align - 1) // align * align
            out.append(off)
            off += size
        return out

    def field(self, cls, f, off):
        ft = self.pkg.type_at(f["type"])
        pkg = "''" if f["name"][:1].isupper() else self.str_lit(self.pkg_path(f.get("pkg") or self.pkg.path))
        args = [self.str_lit(f["name"]), pkg, f"() => {self.rtype(ft)}"]
        if f.get("tag"):
            args.append(f"tag: {self.str_lit(f['tag'])}")
        if f["embedded"]:
            args.append("embedded: true")
        if off:
            args.append(f"offset: {off}")
        if f["name"] == "_":
            zero = self.types.zero(ft)
            args += [f"get: (o) => {zero}", "set: (o, v) {}"]
        else:
            m = member_name(f["name"])
            dt = self.types.dart(ft)
            args.append(f"get: (o) => (o as {cls}).{m}")
            if self.typesys.is_value(ft):
                args.append(f"set: (o, v) => (o as {cls}).{m}.$set(v as {dt.non_null()})")
            elif str(dt) == "Object?":
                args.append(f"set: (o, v) => (o as {cls}).{m} = v")
            else:
                args.append(f"set: (o, v) => (o as {cls}).{m} = v as {dt}")
        return f"{self.go('rtField')}({', '.join(args)})"

    def named_members(self, cls, t, u, tps=None):
        """`$rt`/`$rtype` de um tipo nomeado que não é struct nem interface;
        genérico (`tps`): a fábrica `$rtOf<T>($T)`, como na struct."""
        size, align, ptrs = self.typesys.layout(u) if u["kind"] != "func" else (8, 8, True)
        pkg, name, s = self.common(t)
        k = u["kind"]
        kind = _KIND.get(k) or _BASIC_KIND.get(u.get("name", ""), "kInvalid")
        conv = self.conv(cls, t, u)
        extra = f", conv: {conv}" if conv else ""
        if k == "array":
            extra += f", nil: () => {cls}.$nil"
        if tps is not None and tps.names:
            pkg = self.str_lit(self.pkg_path(t.get("pkg") or self.pkg.path))
            tl = f"<{', '.join(tps.names)}>"
            self_t = cls + tl
            ctor = f"{cls}{tl}({', '.join('$' + n for n in tps.names)}, "
            extra = f", conv: (v) => {ctor}v as {self.types.dart(u)})"
            desc = (f"{self.go('rtNamed')}<{self_t}>({pkg}, n, s, () => {self.rtype(u)}, kind: {self.go(kind)}, "
                    f"size: -1, align: -1, ptrs: {'true' if ptrs else 'false'}, "
                    f"zero: () => {ctor}{self.types.zero(u)}){extra}, {self.method_args(t, cls=self_t)})")
            args = ", ".join(f"{self.go('rtOfElem')}(${n})" for n in tps.names)
            dicts = ", ".join(f"${n}" for n in tps.names)
            params = ", ".join(f"{self.imports.qualify(None, 'Elem')}<{n}> ${n}" for n in tps.names)
            return ["", "/// Descritor de reflexão da instância (`reflect.Type`).",
                    f"static {self.go('RType')}<{self_t}> $rtOf{tps.decl}({params}) => "
                    f"{self.go('rtGeneric')}<{self_t}>({pkg}, {self.str_lit(t.get('name') or '')}, "
                    f"{self.str_lit(self.pkg.name)}, [{args}], (n, s) => {desc});",
                    "@override", f"{self.go('RType')} get $rtype => $rtOf{tl}({dicts});"]
        desc = (f"{self.go('rtNamed')}<{cls}>({pkg}, {name}, {s}, () => {self.rtype(u)}, kind: {self.go(kind)}, "
                f"size: {size}, align: {align}, ptrs: {'true' if ptrs else 'false'}, "
                f"zero: () => {self.types.zero(t)}{extra}, {self.method_args(t, cls=cls)})")
        return ["", "/// Descritor de reflexão (`reflect.Type`).",
                f"static final {self.go('RType')}<{cls}> $rt = {desc};"] + self.instance_member()

    def conv(self, cls, t, u):
        """Função que cria o nomeado a partir do valor canônico do kind."""
        k = u["kind"]
        if k == "basic":
            b = self.typesys.basic(u)
            g = self.types.golang
            if b.cat == "wint":
                return f"(v) => {cls}.from(v as {g('IntBase')})"
            if b.cat == "float":
                return f"(v) => {cls}(v as double)"
            if b.cat == "string":
                return f"(v) => {cls}(v as {g('String')})"
            if b.cat == "bool":
                return f"(v) => {cls}(v as bool)"
            if b.cat == "complex":
                if b.cls == "Complex64":
                    return f"(v) => {cls}({g('Complex64')}.fromComplex128(v as {g('Complex128')}))"
                return f"(v) => {cls}(v as {g('Complex128')})"
            return None
        if k in ("slice", "map", "array", "func"):
            return f"(v) => {self.types.wrap(t, f'v as {self.types.dart(u)}')}" if k != "array" \
                else f"(v) => {cls}(v as {self.types.dart(u)})"
        return None

    def iface_members(self, cls, t, u):
        """`$rt` estático de uma interface nomeada (`reflect.TypeOf((*I)(nil)).Elem()`)."""
        pkg, name, s = self.common(t)
        ms = ", ".join(self.str_lit(m["name"]) for m in u["methods"])
        return ["", "/// Descritor de reflexão (`reflect.Type`).",
                f"static final {self.go('RType')}<{cls}?> $rt = "
                f"{self.go('rtNamedIface')}<{cls}?>({pkg}, {name}, {s}, const [{ms}]{self.sigs_arg(u['methods'])});"]
