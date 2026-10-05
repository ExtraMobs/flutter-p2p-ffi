"""Interfaces satisfeitas entre pacotes (D8): quem precisa de `implements`
de uma interface que o próprio pacote não enxerga.

O Go satisfaz interfaces estruturalmente; o Dart exige `implements`. O
`implements` do goast só olha as interfaces que o pacote do tipo enxerga
(as dele, as dos imports diretos e `error`). Um `a.T` passado como `b.Namer`
num terceiro pacote `c` (que importa os dois) não é um `b.Namer` no Dart.

A regra, em dois passos como a cor (`g2d/analysis/color.py`):

1. cada pacote vira um `IfaceSummary` (`summarize`): os tipos nomeados que
   ele declara, com o method set (assinaturas canônicas), as conversões
   tipo concreto → interface que acontecem nele (`conversions` do goast) e
   os alvos dinâmicos (`asserts`: type assertion, type switch, interface →
   interface);
2. a `IfaceTable` junta os resumos do grafo. Um tipo precisa da interface I
   se algum pacote o converte para I, ou se ele vira interface em algum
   lugar (escapa) e algum pacote testa I por type assertion e o method set
   dele cobre I. As interfaces que os shims testam por dentro
   (`fmt.Stringer` no `fmt.Println`...) contam como testadas sempre.

Só entram interfaces nomeadas não genéricas de pacote transpilado ou de shim
(`SHIM_INTERFACES`) e anônimas canônicas (`Iface$<hash>`, `g2d/services/
anon.py`); tipos nomeados não genéricos de pacote transpilado. A library do
tipo passa a importar a da interface (o Dart aceita import cíclico); se essa
library não existe (pacote que não emitiu), a interface fica de fora
(`missing`, preenchido pelo audit).
"""

import collections

from g2d.config import SHIM_INTERFACES
from g2d.graph import is_std
from g2d.services.naming import is_exported

# Interfaces que os shims testam por type assertion no runtime (o `fmt`
# chama `String()`, o `json` chama `MarshalJSON()`...): todo tipo que escapa
# para interface e as satisfaz as declara. Assinaturas na chave de `type_key`.
SHIM_ASSERTED = {
    ("fmt", "Stringer"): {"String": "func()(string)"},
    ("fmt", "GoStringer"): {"GoString": "func()(string)"},
    ("fmt", "Formatter"): {"Format": "func(fmt.State,int32)()"},
    ("encoding", "TextMarshaler"): {"MarshalText": "func()([]uint8,error)"},
    ("encoding", "TextUnmarshaler"): {"UnmarshalText": "func([]uint8)(error)"},
    ("encoding/json", "Marshaler"): {"MarshalJSON": "func()([]uint8,error)"},
    ("encoding/json", "Unmarshaler"): {"UnmarshalJSON": "func([]uint8)(error)"},
}

_BASIC_ALIAS = {"byte": "uint8", "rune": "int32"}


def type_key(pkg, t, seen=None):
    """Chave estrutural de um tipo (igual entre dumps de pacotes diferentes),
    com import path completo dos nomeados e o pacote dos nomes não
    exportados. None se depende de parâmetro de tipo."""
    t = pkg.type_at(t)
    k = t["kind"]
    if k == "basic":
        return _BASIC_ALIAS.get(t["name"], t["name"])
    if k == "named":
        args = [type_key(pkg, a, seen) for a in t.get("args") or []]
        if None in args:
            return None
        return (f"{t['pkg']}." if t["pkg"] else "") + t["name"] + (f"[{','.join(args)}]" if args else "")
    if k in ("pointer", "slice", "array", "chan"):
        elem = type_key(pkg, t["elem"], seen)
        if elem is None:
            return None
        prefix = {"pointer": "*", "slice": "[]", "array": f"[{t.get('len')}]", "chan": f"chan({t.get('dir')})"}[k]
        return prefix + elem
    if k == "map":
        key, elem = type_key(pkg, t["key"], seen), type_key(pkg, t["elem"], seen)
        return None if key is None or elem is None else f"map[{key}]{elem}"
    if k == "func":
        parts = [type_key(pkg, p, seen) for p in t["params"]] + [type_key(pkg, r, seen) for r in t["results"]]
        if None in parts:
            return None
        n = len(t["params"])
        return f"func({','.join(parts[:n])}{'...' if t['variadic'] else ''})({','.join(parts[n:])})"
    if k == "interface":
        ms = iface_methods(pkg, t)
        if ms is None:
            return None
        return "interface{" + "; ".join(f"{n} {s}" for n, s in sorted(ms.items())) + "}"
    if k == "struct":
        fields = []
        for f in t["fields"]:
            ft = type_key(pkg, f["type"], seen)
            if ft is None:
                return None
            name = (f"{f['pkg']}." if f.get("pkg") else "") + f["name"]
            fields.append(f"{'embedded ' if f['embedded'] else ''}{name} {ft} {f['tag']!r}")
        return "struct{" + "; ".join(fields) + "}"
    return None  # typeparam, tuple, union


def method_name(m):
    """Nome do método na identidade: o não exportado leva o pacote."""
    return (f"{m['pkg']}." if m.get("pkg") else "") + m["name"]


def iface_methods(pkg, t):
    """{nome: assinatura} do method set completo de uma interface (o goast
    já lista os embutidos), ou None se depende de parâmetro de tipo."""
    t = pkg.type_at(t)
    if t["kind"] == "named":
        t = pkg.type_at(t["underlying"])
    out = {}
    for m in t["methods"]:
        s = type_key(pkg, m["type"])
        if s is None:
            return None
        out[method_name(m)] = s
    return out


def iface_ref(engine, t):
    """Identidade de uma interface com métodos que pode ir em `implements`
    fora do pacote dela: ("n", pacote, nome) para nomeada não genérica de
    pacote transpilado ou de shim, ("a", chave) para anônima canônica
    (`Iface$<hash>`, `AnonTypes.key`). None para as outras."""
    pkg = engine.pkg
    t = pkg.type_at(t)
    if t["kind"] == "named":
        if t.get("args") or not t["pkg"] or not is_exported(t["name"]):
            return None  # genérica, `error` (já vem do goast) ou privada
        if is_std(t["pkg"]) and (t["pkg"], t["name"]) not in SHIM_INTERFACES:
            return None
        return ("n", t["pkg"], t["name"])
    if t["kind"] != "interface" or not t["methods"] or engine.services["goinfo"].runtime_iface(t):
        return None  # a do runtime (`go.ErrorIs`): o `implements` já vem do método
    key = engine.services["anon"].key(t)
    return None if key is None else ("a", key)


class IfaceSummary:
    """O que um pacote contribui para os `implements` entre pacotes."""

    def __init__(self):
        # (pacote, nome) → {"methods": {nome: assinatura} de *T, "value":
        # nomes do method set de T, "keys": {nome: chave de cor}}
        self.types = {}
        self.convs = set()  # ((pacote, nome) do tipo, iface_ref)
        self.asserts = {}  # iface_ref → {nome: assinatura}
        self.methods = {}  # iface_ref → nomes dos métodos (das convs)

    def to_json(self):
        return {"types": sorted([list(k), {"methods": v["methods"], "value": sorted(v["value"]),
                                           "keys": {m: list(c) for m, c in v["keys"].items()}}]
                                for k, v in self.types.items()),
                "convs": sorted([list(t), list(i)] for t, i in self.convs),
                "asserts": sorted([list(i), m] for i, m in self.asserts.items()),
                "methods": sorted([list(i), sorted(m)] for i, m in self.methods.items())}

    @classmethod
    def from_json(cls, doc):
        s = cls()
        for k, v in doc["types"]:
            s.types[tuple(k)] = {"methods": v["methods"], "value": set(v["value"]),
                                 "keys": {m: tuple(c) for m, c in v["keys"].items()}}
        s.convs = {(tuple(t), tuple(i)) for t, i in doc["convs"]}
        s.asserts = {tuple(i): m for i, m in doc["asserts"]}
        s.methods = {tuple(i): set(m) for i, m in doc["methods"]}
        return s


def summarize(engine):
    """IfaceSummary do pacote do engine."""
    pkg, conc = engine.pkg, engine.services["concurrency"]
    s = IfaceSummary()
    for f in pkg.files:
        for d in f["ast"]["decls"] or []:
            if d["node"] != "GenDecl" or d["tok"] != "type":
                continue
            for spec in d["specs"]:
                if spec["typeParams"] or spec["assign"]:
                    continue
                t = pkg.type_at(spec["name"]["$obj"]["type"])
                if t["kind"] != "named" or pkg.type_at(t["underlying"])["kind"] == "interface":
                    continue
                methods, value, keys = {}, set(), {}
                for m in t.get("methods") or []:
                    sig = type_key(pkg, m["type"])
                    if sig is None:
                        continue
                    methods[method_name(m)] = sig
                    if not m["ptr"]:
                        value.add(method_name(m))
                    key = conc.method_key(t, m["name"])
                    if key is not None:
                        keys[method_name(m)] = key
                s.types[(t["pkg"], t["name"])] = {"methods": methods, "value": value, "keys": keys}
    for c in pkg.conversions:
        t = pkg.type_at(c["type"])
        if t["kind"] == "pointer":
            t = pkg.type_at(t["elem"])
        if t["kind"] != "named" or t.get("args") or not t["pkg"] or is_std(t["pkg"]):
            continue
        ref = iface_ref(engine, c["iface"])
        tid = (t["pkg"], t["name"])
        if ref is None:
            s.convs.add((tid, ("any",)))  # só escapa
            continue
        ms = iface_methods(pkg, c["iface"])
        if ms is None:
            continue
        s.convs.add((tid, ref))
        s.methods[ref] = set(ms)
    for a in pkg.asserts:
        ref = iface_ref(engine, a)
        ms = iface_methods(pkg, a)
        if ref is not None and ms is not None:
            s.asserts[ref] = ms
    return s


def iface_key(ref, method):
    """Chave de cor do método `method` da interface `ref`
    (`Concurrency.iface_key`)."""
    if ref[0] == "n":
        return ("m", ref[1], ref[2], method)
    return ("anon", ref[1], method)


class IfaceTable:
    """Os `implements` entre pacotes do grafo inteiro."""

    def __init__(self, summaries=()):
        types, convs, asserts, methods = {}, set(), {}, {}
        for s in summaries:
            types.update(s.types)
            convs |= s.convs
            asserts.update(s.asserts)
            methods.update(s.methods)
        for (p, n), ms in SHIM_ASSERTED.items():
            asserts.setdefault(("n", p, n), ms)
        self.types = types
        self.methods = {**methods, **{r: set(ms) for r, ms in asserts.items()}}
        self.needs = collections.defaultdict(set)
        escaped = set()
        for tid, ref in convs:
            escaped.add(tid)
            if ref != ("any",) and tid in types:
                self.needs[tid].add(ref)
        by_method = collections.defaultdict(list)  # método → tipos que escapam com ele
        for tid in sorted(escaped & types.keys()):
            for m in types[tid]["methods"]:
                by_method[m].append(tid)
        for ref, ms in asserts.items():
            if not ms:
                continue
            for tid in by_method.get(min(ms), ()):
                have = types[tid]["methods"]
                if all(have.get(m) == sig for m, sig in ms.items()):
                    self.needs[tid].add(ref)
        self.missing = set()  # libraries que não existem (pacote que não emitiu)

    def interfaces(self, tid):
        """Interfaces (iface_ref) que o tipo (pacote, nome) precisa declarar,
        em ordem determinística."""
        return sorted(self.needs.get(tid, ()))

    def method_names(self, ref):
        return {m.rsplit(".", 1)[-1] for m in self.methods.get(ref, ())}

    def unions(self):
        """Pares de chaves de cor (método do tipo, método da interface): a
        mesma assinatura Dart, logo a mesma cor."""
        out = set()
        for tid, refs in self.needs.items():
            keys = self.types[tid]["keys"]
            for ref in refs:
                for m in self.methods.get(ref, ()):
                    if m in keys:
                        out.add((keys[m], iface_key(ref, m)))
        return out
