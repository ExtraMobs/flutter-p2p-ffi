"""Cor das funções (M4): quem vira `async` no grafo inteiro.

Uma função Go vira `async` no Dart se suspende no próprio corpo (operação
de canal, `select` sem `default`, `range` sobre chan, `Wait` do `sync`,
`Lock` de um Mutex disputável) ou se chama, direta ou indiretamente, quem
suspende. Um Mutex é disputável se alguma seção crítica dele suspende (ou
não destrava no mesmo bloco): no event loop cooperativo, só assim um `Lock`
encontra o Mutex travado. Os outros ficam com `lock()` síncrono. A cor é
transitiva e atravessa pacotes, por isso é calculada em dois passos:

1. cada pacote vira um `ColorSummary` (`summarize`): quem suspende direto,
   quem chama quem e as ligações que o Dart exige — um método de interface
   e todas as implementações dele têm a mesma assinatura, logo a mesma cor
   (união-busca), assim como uma interface e as que ela embute;
2. a `ColorTable` junta os resumos do grafo e propaga a cor dos callees
   para os chamadores. O Engine de cada pacote consulta a tabela.

`go f()` não colore quem chama (o `go.spawn` aceita qualquer cor). Um grupo
com método que o shim chama de forma síncrona (`String`, `Error`, interface
da stdlib) nunca é `async`: lá dentro o `Lock` fica síncrono e o resto que
precisaria suspender é recusado na emissão (`async:contexto-sincrono`).
Valor de função (closure guardada, method value) com cor `async` é
recusado (`async:valor-func`): chamadas por valor são sempre síncronas.
"""

import collections

from g2d.config import STDLIB_SHIMS
from g2d.engine.behavior import Analysis
from g2d.model import unparen, walk
from g2d.services.concurrency import (COLOR_POLYMORPHIC_SHIM, LOCKS, ONCE_DO, SPAWNING_SHIM, SUSPENDING_FUNCS,
                                      SUSPENDING_SHIM, WAITGROUP_GO, Concurrency)


class ColorSummary:
    """O que um pacote contribui para a cor do grafo."""

    def __init__(self):
        self.direct = set()  # chaves que suspendem no próprio corpo
        self.edges = collections.defaultdict(set)  # chave → callees (chamada que espera o resultado)
        self.unions = set()  # pares de chaves com a mesma assinatura Dart
        # (função, mutex, seção suspende direto, callees da seção, mutexes
        # travados na seção, vaza): ver Concurrency.lock_sites
        self.lock_sites = []
        self.value_uses = []  # (chave, classe, nó) de funções usadas como valor (não serializado)
        self.forced = set()  # classes de func com formato Dart fixo (shim, genérico): síncronas

    def to_json(self):
        return {"direct": sorted(map(list, self.direct)),
                "forced": sorted(map(list, self.forced)),
                "edges": sorted([list(k), sorted(map(list, v))] for k, v in self.edges.items()),
                "unions": sorted([list(a), list(b)] for a, b in self.unions),
                "locks": [[list(f), list(m), h, sorted(map(list, c)), sorted(map(list, n)), lk]
                          for f, m, h, c, n, lk in self.lock_sites]}

    @classmethod
    def from_json(cls, doc):
        s = cls()
        s.direct = {tuple(k) for k in doc["direct"]}
        s.forced = {tuple(k) for k in doc["forced"]}
        for k, v in doc["edges"]:
            s.edges[tuple(k)] = {tuple(x) for x in v}
        s.unions = {(tuple(a), tuple(b)) for a, b in doc["unions"]}
        s.lock_sites = [(tuple(f), tuple(m), h, frozenset(map(tuple, c)), frozenset(map(tuple, n)), lk)
                        for f, m, h, c, n, lk in doc["locks"]]
        return s


def init_key(pkg):
    """Chave do `$goInit` do pacote (inicializadores de var e funções init)."""
    return ("init", pkg.path)


def summarize(engine, decls=None):
    """ColorSummary de um pacote (só lê a AST tipada; nada é emitido)."""
    pkg, conc = engine.pkg, engine.services["concurrency"]
    typesys = engine.services["typesys"]
    if decls is None:
        decls = [d for f in pkg.files for d in f["ast"]["decls"] or []]
    s = ColorSummary()
    for key, ref in field_classes(engine, decls):
        s.edges[key].add(ref)  # o campo é async se recebe uma função async

    def callees(node):
        """(callees que a função espera, mutexes que ela trava)."""
        out, locks = set(), set()
        go_calls = {id(n["call"]) for n in walk(node, funclits=False) if n.get("node") == "GoStmt"}
        for n in walk(node, funclits=False):
            if n.get("node") != "CallExpr" or id(n) in go_calls:
                continue
            ck = conc.callee_key(n)
            if ck in LOCKS:
                locks.add(conc.mutex_id(n))
            if ck in SUSPENDING_SHIM or ck in SUSPENDING_FUNCS or ck == WAITGROUP_GO:
                continue
            if ck == ONCE_DO:  # espera f
                ck = conc.once_arg_key(n)
            elif ck is None:  # chamada por valor: espera a classe da func
                ck = conc.value_call_key(n)
            if ck is not None:
                out.add(ck)
        return out, locks

    def body(key, node):
        if conc.direct_suspend(node)[0]:
            s.direct.add(key)
        s.edges[key] |= callees(node)[0]
        for mid, section, leak in conc.lock_sites(node):
            hard = any(conc.direct_suspend(x)[0] for x in section)
            cs, ls = set(), set()
            for x in section:
                c, lk = callees(x)
                cs |= c
                ls |= lk
            s.lock_sites.append((key, mid, hard, frozenset(cs), frozenset(ls), leak))

    for d in decls:
        if d["node"] == "FuncDecl" and d["body"]:
            key = conc.decl_key(d)
            body(key, d["body"])
            if not d["recv"] and d["name"]["name"] == "init":
                s.edges[init_key(pkg)].add(key)
            if not d["recv"] and d["name"]["name"] == "main" and pkg.name == "main":
                s.edges[key].add(init_key(pkg))  # o main espera o $goInit
        elif d["node"] == "GenDecl" and d["tok"] == "var":
            for spec in d["specs"]:
                for v in spec["values"] or []:
                    body(init_key(pkg), v)
    if pkg.name == "main":  # o $goInit do main inicializa o grafo inteiro
        s.edges[init_key(pkg)] |= {("init", dep) for dep in pkg.init_deps or []}
    for n in walk(decls):
        if n.get("node") == "FuncLit":
            body(conc.lit_key(n), n["body"])
    value_uses(conc, decls, s)
    for key, cls, _ in s.value_uses:
        s.edges[cls].add(key)  # a classe é async se uma função async vira valor dela
    fixed_classes(engine, decls, s)
    for e in pkg.implements:
        t = pkg.type_at(e["type"])
        for i in e["interfaces"]:
            for m in typesys.underlying(pkg.type_at(i))["methods"]:
                a, b = conc.method_key(t, m["name"]), conc.iface_key(i, m["name"])
                if a is not None:
                    s.unions.add((a, b))
    for t in pkg.type_table:
        if t["kind"] != "named" or typesys.underlying(t)["kind"] != "interface":
            continue
        for e in typesys.underlying(t)["embeddeds"]:
            et = pkg.type_at(e)
            if et["kind"] == "named" and typesys.underlying(et)["kind"] == "interface":
                for m in typesys.underlying(et)["methods"]:
                    s.unions.add((conc.iface_key(t, m["name"]), conc.iface_key(et, m["name"])))
    return s


def field_classes(engine, decls):
    """Campos com classe de cor própria: campo não exportado de tipo `func`
    sem nome, de struct nomeada não genérica do pacote (todo acesso a ele
    está aqui), que só é chamado (`x.f()`), comparado com nil ou escrito, e
    só recebe nil, função citada direto (literal, `f`, `x.M`) ou um tipo de
    função nomeado da stdlib (`context.CancelFunc`). A classe dele é
    `("field", pacote, declaração)`, `async` só se recebe uma função
    `async`; um `cancelInner func()` que guarda um `CancelFunc` fica
    síncrono mesmo com a `func()` `async` no grafo. O tipo do campo na
    struct e nos seletores vira uma cópia do tipo func com `$class` (lida
    por `Concurrency.sig_key`). Devolve as arestas (classe do campo, chave da
    função escrita); idempotente por pacote."""
    pkg, conc = engine.pkg, engine.services["concurrency"]
    cached = pkg.__dict__.get("_field_classes")
    if cached is not None:
        return cached
    typesys = conc.typesys
    owner = {}  # declaração do campo → (dict da struct, nome)
    slots = collections.Counter()
    for d in decls:
        if d["node"] != "GenDecl" or d["tok"] != "type":
            continue
        for spec in d["specs"]:
            if spec.get("typeParams") or spec.get("assign") or spec["type"]["node"] != "StructType":
                continue
            st = typesys.underlying(pkg.type_at(spec["name"]["$obj"]["type"]))
            for fld in spec["type"]["fields"]["list"] or []:
                for name in fld["names"] or []:
                    obj = name.get("$obj") or {}
                    t = pkg.type_at(obj.get("type")) if obj.get("type") is not None else None
                    if (t is None or t["kind"] != "func" or name["name"][:1].isupper()
                            or name["name"] == "_"):
                        continue
                    owner[obj["decl"]] = (st, name["name"])
                    slots[(id(st), name["name"])] += 1
    # Structs idênticas no pacote compartilham o subjacente: campo ambíguo fica na assinatura.
    owner = {k: v for k, v in owner.items() if slots[(id(v[0]), v[1])] == 1}
    if not owner:
        pkg._field_classes = []
        return []
    bad, edges, sels, ok = set(), [], {}, set()

    def field_of(n):
        n = unparen(n)
        if n.get("node") == "SelectorExpr" and (n.get("$sel") or {}).get("kind") == "field":
            decl = (n["sel"].get("$obj") or {}).get("decl")
            return decl if decl in owner else None
        return None

    def write(decl, value, vt=None):
        if decl is None:
            return
        ref = func_ref_key(conc, value) if value is not None else None
        vt = vt if vt is not None else pkg.type_of(value)
        if ref is not None:
            edges.append((("field", pkg.path, decl), ref))
        elif vt is not None and vt["kind"] == "basic" and vt["name"] == "untyped nil":
            pass
        elif not conc.std_named_func(vt):
            bad.add(decl)

    for n in walk(decls):
        k = n.get("node")
        decl = field_of(n)
        if decl is not None:
            sels[id(n)] = decl
        if k == "CallExpr":
            ok.add(id(unparen(n["fun"])))
        elif k == "BinaryExpr" and n["op"] in ("==", "!="):
            for a, b in ((n["x"], n["y"]), (n["y"], n["x"])):
                bt = pkg.type_of(b)
                if bt is not None and bt["kind"] == "basic" and bt["name"] == "untyped nil":
                    ok.add(id(unparen(a)))
        elif k == "AssignStmt" and n["tok"] == "=":
            lhs, rhs = n["lhs"], n["rhs"]
            tuple_t = pkg.type_of(rhs[0]) if len(rhs) == 1 and len(lhs) > 1 else None
            for i, x in enumerate(lhs):
                d = field_of(x)
                if d is None:
                    continue
                ok.add(id(unparen(x)))
                if len(rhs) == len(lhs):
                    write(d, rhs[i])
                elif tuple_t is not None and tuple_t["kind"] == "tuple":
                    write(d, None, pkg.type_at(tuple_t["elems"][i]))
                else:
                    bad.add(d)
        elif k == "CompositeLit":
            t = pkg.type_of(n)
            st = typesys.underlying(t) if t is not None else None
            if st is None or st["kind"] != "struct":
                continue
            for i, e in enumerate(n["elts"] or []):
                if e["node"] == "KeyValueExpr":
                    d = (e["key"].get("$obj") or {}).get("decl")
                    if d in owner:
                        write(d, e["value"])
                elif i < len(st["fields"]):
                    name = st["fields"][i]["name"]
                    for d, (ost, oname) in owner.items():
                        if ost is st and oname == name:
                            write(d, e)
    bad |= {d for i, d in sels.items() if i not in ok}
    for d, (st, name) in owner.items():
        if d in bad:
            continue
        for f in st["fields"]:
            if f["name"] == name:
                f["type"] = dict(pkg.type_at(f["type"]), **{"$class": ("field", pkg.path, d)})
                synthetic = f["type"]
        for n in walk(decls):
            if field_of(n) == d:
                n["$type"] = synthetic
    pkg._field_classes = [e for e in edges if e[0][2] not in bad]
    return pkg._field_classes


def func_ref_key(conc, n):
    """Chave de uma referência direta a função (literal, função, método)."""
    n = unparen(n) if n else None
    if not n:
        return None
    if n["node"] == "FuncLit":
        return conc.lit_key(n)
    if n["node"] in ("Ident", "SelectorExpr"):
        return conc.callee_key({"fun": n})
    return None


def value_uses(conc, decls, s):
    """Funções usadas como valor (não chamadas direto): literal guardado ou
    passado adiante, `f` sem chamar, method value `x.M`, `T.M`."""
    callees, sels = set(), set()
    for n in walk(decls):
        k = n.get("node")
        if k == "CallExpr":
            fun = unparen(n["fun"])
            callees.add(id(fun))
            if fun["node"] in ("IndexExpr", "IndexListExpr"):
                callees.add(id(unparen(fun["x"])))
            spawn = SPAWNING_SHIM.get(conc.callee_key(n))
            if spawn is not None and len(n["args"] or []) > spawn:
                # Once.Do espera f (do$async); os outros a rodam numa goroutine
                callees.add(id(unparen(n["args"][spawn])))
        elif k == "SelectorExpr":
            sels.add(id(n["sel"]))
        elif k == "FuncDecl":
            sels.add(id(n["name"]))  # o nome na declaração não é uso
    for n in walk(decls):
        k = n.get("node")
        if id(n) in callees or id(n) in sels:
            continue
        key = None
        if k == "FuncLit":
            key = conc.lit_key(n)
        elif k == "Ident" and (n.get("$obj") or {}).get("kind") == "func":
            key = conc.callee_key({"fun": n})
        elif k == "SelectorExpr":
            info = n.get("$sel")
            if info is None or info["kind"] == "method":
                key = conc.callee_key({"fun": n})
            elif info["kind"] == "methodExpr":
                key = conc.method_key(info["recv"], n["sel"]["name"])
        if key is not None:
            s.value_uses.append((key, conc.sig_key(conc.pkg.type_of(n)), n))


def fixed_classes(engine, decls, s):
    """Classes de func cujo formato Dart é fixo por quem não é gerado com a
    cor: assinaturas de funções/métodos da stdlib (o shim recebe e devolve
    funções síncronas; exceto quem roda a função numa goroutine,
    `SPAWNING_SHIM`, quem serve às duas cores, `COLOR_POLYMORPHIC_SHIM`, e
    pacote sem shim) e formatos derivados de genéricos (parâmetros e
    resultados de uma chamada genérica, campos e métodos de instâncias de
    tipos genéricos: lá dentro o Dart vê `R Function(T)`)."""
    conc, pkg, calls = engine.services["concurrency"], engine.pkg, engine.services["calls"]
    for n in walk(decls):
        k = n.get("node")
        if k == "CallExpr":
            fun = unparen(n["fun"])
            if fun.get("$isType") or fun.get("$builtin"):
                continue
            ck = conc.callee_key(n)
            inst = calls.instantiation(fun)
            std = ck is not None and conc.std(ck[1]) and ck[0] in ("f", "m")
            if std and (ck in COLOR_POLYMORPHIC_SHIM or ck[1] not in STDLIB_SHIMS):
                continue  # sem shim o pacote cai na emissão: não prende a classe no grafo
            if inst is None and not std:
                continue
            sig = pkg.type_of(fun)
            if sig is None or conc.typesys.underlying(sig)["kind"] != "func":
                continue
            sig = conc.typesys.underlying(sig)
            skip = SPAWNING_SHIM.get(ck)
            args = None if std else inst[1]
            for i, p in enumerate(sig["params"]):
                if i != skip:
                    s.forced |= generic_classes(conc, p, args)
            for r in sig["results"]:
                s.forced |= generic_classes(conc, r, args)
        elif k in ("IndexExpr", "IndexListExpr") and calls.instantiation(n):
            s.forced |= generic_classes(conc, pkg.type_of(n), calls.instantiation(n)[1])  # `f[int]` como valor
    for t in pkg.type_table:
        if t["kind"] == "named" and t.get("args"):
            u = conc.typesys.underlying(t)
            for f in u.get("fields") or []:
                s.forced |= generic_classes(conc, f["type"], t["args"])
            for m in (t.get("methods") or []) + (u.get("methods") or []):
                s.forced |= generic_classes(conc, m["type"], t["args"])


def generic_classes(conc, t, args):
    """Classes de func em t com formato fixo. Sem args (assinatura da
    stdlib), todas. Numa instância genérica, só as que vêm de um parâmetro
    de tipo: lá dentro o Dart vê `R Function(T)`; uma `func()` que não cita
    o parâmetro tem a mesma classe dentro e fora do genérico e segue a cor
    dela (o tipo do método em si também não conta), assim como o próprio
    argumento quando ele é uma func (`StartStopHook[func()]`: lá dentro o
    valor é um `T` opaco, reificado com o formato da classe). Aproximação
    segura: a classe cita o texto de algum argumento de tipo (`func(int64)`
    também fica presa por `T = int`, nunca o contrário)."""
    classes = conc.func_classes(t)
    if args is None:
        return classes
    names = [conc.canon(a) for a in args]
    return {c for c in classes if any(a in c[1] and a != c[1] for a in names)}


class ColorTable:
    """A cor do grafo: resumos de todos os pacotes, uniões e propagação."""

    def __init__(self, summaries=()):
        self.parent = {}
        self.direct = set()
        self.edges = collections.defaultdict(set)
        self.lock_sites = []
        self.forced = set()
        self._async = None
        for s in summaries:
            self.add(s)

    def add(self, summary):
        for a, b in summary.unions:
            self.union(a, b)
        for k in summary.direct:
            self.find(k)
        self.direct |= summary.direct
        for k, v in summary.edges.items():
            self.edges[k] |= v
        self.lock_sites += summary.lock_sites
        self.forced |= summary.forced
        self._async = None

    def find(self, k):
        parent = self.parent
        root = parent.setdefault(k, k)
        while root != parent[root]:
            root = parent[root]
        while k != root:
            parent[k], k = root, parent[k]
        return root

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            # Raiz determinística (independe da ordem dos pacotes).
            ra, rb = sorted((ra, rb))
            self.parent[rb] = ra

    def solve(self):
        """Ponto fixo: Mutex disputável → seus `Lock` suspendem → mais cor →
        mais seções críticas que suspendem → mais Mutex disputáveis."""
        for k, v in self.edges.items():
            self.find(k)
            for c in v:
                self.find(c)
        for site in self.lock_sites:
            self.find(site[0])
            for c in site[3]:
                self.find(c)
        for k in self.forced:
            self.find(k)
        forced = {self.find(k) for k in list(self.parent) if Concurrency.forced_sync(k)}
        forced |= {self.find(k) for k in self.forced}
        callers = collections.defaultdict(set)  # grupo → grupos que o chamam
        for k, v in self.edges.items():
            for c in v:
                callers[self.find(c)].add(self.find(k))
        mutexes = {m for _, m, hard, _, _, leak in self.lock_sites if hard or leak or m[0] == "?"}
        while True:
            direct = self.direct | {f for f, m, *_ in self.lock_sites if m in mutexes}
            colored = set()
            work = [g for g in {self.find(k) for k in direct} if g not in forced]
            colored.update(work)
            while work:
                g = work.pop()
                for c in callers[g]:
                    if c not in colored and c not in forced:
                        colored.add(c)
                        work.append(c)
            more = {m for _, m, _, cs, ls, _ in self.lock_sites if m not in mutexes
                    and (any(self.find(c) in colored for c in cs) or ls & mutexes)}
            if not more:
                break
            mutexes |= more
        self._async, self._forced, self._mutexes = colored, forced, mutexes

    def mutex_async(self, mid):
        """O Mutex é disputável (alguma seção crítica dele suspende)."""
        if self._async is None:
            self.solve()
        return mid in self._mutexes

    def is_async(self, key):
        if self._async is None:
            self.solve()
        return key in self.parent and self.find(key) in self._async


    def is_forced(self, key):
        if self._async is None:
            self.solve()
        return self.find(key) in self._forced if key in self.parent else Concurrency.forced_sync(key)


class ColorAnalysis(Analysis):
    """Grava em `facts` a tabela de cor (a do grafo, se o Engine recebeu
    uma; senão a do próprio pacote) e os valores func async (recusados)."""

    def run(self, decls):
        summary = summarize(self.engine, decls)
        table = self.engine.colors or ColorTable([summary])
        self.facts.colors = table
        # Valor func: função async numa classe síncrona é recusada; função
        # síncrona numa classe async é embrulhada (`go.asyncN`, literal `async`).
        self.facts.async_values = {id(n) for key, cls, n in summary.value_uses
                                   if table.is_async(key) and not table.is_async(cls)}
        self.facts.wrap_values = {id(n) for key, cls, n in summary.value_uses
                                  if table.is_async(cls) and not table.is_async(key)}
