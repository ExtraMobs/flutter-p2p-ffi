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

from g2d.engine.behavior import Analysis
from g2d.model import unparen, walk
from g2d.services.concurrency import LOCKS, ONCE_DO, SUSPENDING_SHIM, WAITGROUP_GO, Concurrency


class ColorSummary:
    """O que um pacote contribui para a cor do grafo."""

    def __init__(self):
        self.direct = set()  # chaves que suspendem no próprio corpo
        self.edges = collections.defaultdict(set)  # chave → callees (chamada que espera o resultado)
        self.unions = set()  # pares de chaves com a mesma assinatura Dart
        # (função, mutex, seção suspende direto, callees da seção, mutexes
        # travados na seção, vaza): ver Concurrency.lock_sites
        self.lock_sites = []
        self.value_uses = []  # (chave, nó) de funções usadas como valor (não serializado)

    def to_json(self):
        return {"direct": sorted(map(list, self.direct)),
                "edges": sorted([list(k), sorted(map(list, v))] for k, v in self.edges.items()),
                "unions": sorted([list(a), list(b)] for a, b in self.unions),
                "locks": [[list(f), list(m), h, sorted(map(list, c)), sorted(map(list, n)), lk]
                          for f, m, h, c, n, lk in self.lock_sites]}

    @classmethod
    def from_json(cls, doc):
        s = cls()
        s.direct = {tuple(k) for k in doc["direct"]}
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
            if ck is None or ck in SUSPENDING_SHIM or ck == WAITGROUP_GO:
                continue
            if ck == ONCE_DO:  # espera f
                ck = func_ref_key(conc, (n["args"] or [None])[0])
                if ck is None:
                    continue
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
            if conc.callee_key(n) in (ONCE_DO, WAITGROUP_GO) and n["args"]:
                callees.add(id(unparen(n["args"][0])))
        elif k == "SelectorExpr":
            sels.add(id(n["sel"]))
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
            s.value_uses.append((key, n))


class ColorTable:
    """A cor do grafo: resumos de todos os pacotes, uniões e propagação."""

    def __init__(self, summaries=()):
        self.parent = {}
        self.direct = set()
        self.edges = collections.defaultdict(set)
        self.lock_sites = []
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
        forced = {self.find(k) for k in list(self.parent) if Concurrency.forced_sync(k)}
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
        self.facts.async_values = {id(n) for key, n in summary.value_uses if table.is_async(key)}
