"""Concorrência (M4): chaves de cor das funções, suspensão direta (canais,
`select`, `range` sobre chan, `sync` que espera) e a consulta da cor na
emissão. A cor em si (quem é `async`, no grafo inteiro) é calculada pela
`ColorTable` de `g2d/analysis/color.py`; este serviço só sabe dar nome às
funções e reconhecer, num corpo isolado, o que ELE MESMO faz."""

from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported, first_pos, unparen, walk

# Métodos do shim `sync` que esperam outra goroutine: chave → variante
# suspensiva (`golib_dart/lib/src/sync/`). `soft`: num contexto que precisa
# ficar síncrono, a versão síncrona serve (só falha, com `fatal g2d:`, se
# estiver disputada); as outras não têm como esperar sem suspender.
SUSPENDING_SHIM = {
    ("m", "sync", "Mutex", "Lock"): ("lock$async", True),
    ("m", "sync", "RWMutex", "Lock"): ("lock$async", True),
    ("m", "sync", "RWMutex", "RLock"): ("rLock$async", True),
    ("m", "sync", "WaitGroup", "Wait"): ("wait$async", False),
    ("m", "sync", "Cond", "Wait"): ("wait$async", False),
}
# Trava → destrava correspondente (seção crítica de um Mutex/RWMutex).
LOCKS = {
    ("m", "sync", "Mutex", "Lock"): "Unlock",
    ("m", "sync", "RWMutex", "Lock"): "Unlock",
    ("m", "sync", "RWMutex", "RLock"): "RUnlock",
}
# Recebem uma função: `Once.Do(f)` espera `f` (vira `do$async` se `f` é
# async); `WaitGroup.Go(f)` agenda `f` como goroutine (aceita qualquer cor).
ONCE_DO = ("m", "sync", "Once", "Do")
WAITGROUP_GO = ("m", "sync", "WaitGroup", "Go")

# Métodos que o shim (fmt, errors, sort...) chama por nome, de forma
# síncrona: nunca podem ser `async`, seja qual for a interface.
SYNC_METHODS = frozenset({"String", "Error", "GoString", "Format"})


class Concurrency(Service):
    """Chaves de cor, suspensão direta e consulta da cor na emissão."""

    name = "concurrency"

    # ------------------------------------------------------------ chaves
    # Uma função tem uma chave estável no grafo inteiro (tupla):
    #   ("f", pacote, nome)              função de pacote
    #   ("m", pacote, tipo, método)      método declarado em `tipo` (ou
    #                                    método de interface nomeada)
    #   ("anon", método)                 método de interface anônima
    #   ("lit", pacote, posição)         func literal
    def decl_key(self, d):
        """Chave de uma FuncDecl."""
        if not d["recv"]:
            return ("f", self.pkg.path, d["name"]["name"])
        t = self.pkg.recv_type(d)
        if t["kind"] == "pointer":
            t = self.pkg.type_at(t["elem"])
        return ("m", t["pkg"], t["name"], d["name"]["name"])

    def lit_key(self, n):
        pos = first_pos(n)
        return ("lit", self.pkg.path, f"{pos['file']}:{pos['offset']}")

    def method_key(self, t, name):
        """Chave do método `name` do tipo t (valor, ponteiro, parâmetro de
        tipo ou interface): segue a promoção por embedding até o tipo que o
        declara. None se não dá para saber (struct anônima com embedding)."""
        t = self.pkg.type_at(t)
        if t["kind"] == "pointer":
            t = self.pkg.type_at(t["elem"])
        if t["kind"] == "typeparam":
            t = self.pkg.type_at(t["constraint"])
        u = self.typesys.underlying(t)
        if u["kind"] == "interface":
            return self.iface_key(t, name)
        if t["kind"] != "named":
            return None
        m = next((m for m in t.get("methods") or [] if m["name"] == name), None)
        if m is None or len(m["index"]) == 1:
            return ("m", t["pkg"], t["name"], name)
        f = u["fields"][m["index"][0]]
        return self.method_key(f["type"], name)

    def iface_key(self, t, name):
        t = self.pkg.type_at(t)
        if t["kind"] == "named":
            return ("m", t["pkg"], t["name"], name)
        return ("anon", name)

    def callee_key(self, call):
        """Chave do que a chamada invoca diretamente (função, método,
        literal), ou None: valor de função, builtin, conversão."""
        fun = unparen(call["fun"])
        if fun.get("$isType") or fun.get("$builtin"):
            return None
        if fun["node"] in ("IndexExpr", "IndexListExpr"):  # f[T](x)
            fun = unparen(fun["x"])
        if fun["node"] == "FuncLit":
            return self.lit_key(fun)
        if fun["node"] == "Ident":
            obj = fun.get("$obj") or {}
            return ("f", obj["pkg"], obj["name"]) if obj.get("kind") == "func" else None
        if fun["node"] == "SelectorExpr":
            info = fun.get("$sel")
            if info is None:
                obj = fun["sel"].get("$obj") or {}
                return ("f", obj["pkg"], obj["name"]) if obj.get("kind") == "func" else None
            if info["kind"] == "method":
                return self.method_key(self.pkg.type_of(fun["x"]), fun["sel"]["name"])
        return None

    @staticmethod
    def std(pkg):
        """Pacote da stdlib (shim): o `main` do modo loose não conta."""
        return pkg != "main" and is_std(pkg)

    @staticmethod
    def forced_sync(key):
        """A chave precisa ficar síncrona: método que o shim chama por nome
        (`String`, `Error`...) ou de tipo/interface da stdlib (`io.Reader`)."""
        if key[0] == "anon":
            return key[1] in SYNC_METHODS
        if key[0] == "m":
            return key[3] in SYNC_METHODS or key[1] == "" or Concurrency.std(key[1])
        return key[0] == "f" and Concurrency.std(key[1])

    # ------------------------------------------------------------ suspensão direta
    def direct_suspend(self, node):
        """(hard, soft) da função/literal (sem contar func literals
        aninhadas): `hard` = operação de canal, `select` sem `default`,
        `range` sobre chan, `WaitGroup.Wait`/`Cond.Wait`; `soft` = `Lock`
        (que só suspende se o Mutex for disputável: `lock_sites`)."""
        hard = soft = False
        polled = set()  # operações dos cases de `select` com `default`: nunca esperam
        for n in walk(node, funclits=False):
            k = n.get("node")
            if id(n) in polled:
                continue
            if k == "SendStmt" or (k == "UnaryExpr" and n["op"] == "<-"):
                hard = True
            elif k == "SelectStmt" and self.has_default(n):
                for c in n["body"]["list"] or []:
                    comm = c["comm"]
                    if comm is not None:
                        polled.add(id({"ExprStmt": lambda: comm["x"], "AssignStmt": lambda: comm["rhs"][0]}
                                      .get(comm["node"], lambda: comm)()))
            elif k == "SelectStmt":
                hard = True
            elif k == "RangeStmt" and self.is_chan_range(n):
                hard = True
            elif k == "CallExpr":
                shim = SUSPENDING_SHIM.get(self.callee_key(n))
                if shim:
                    soft, hard = soft or shim[1], hard or not shim[1]
        return hard, soft

    # ------------------------------------------------------------ Mutex
    # Num event loop cooperativo, um `Lock` só encontra o Mutex travado se
    # quem o trava suspende antes de destravar. Um Mutex cujas seções
    # críticas nunca suspendem fica com `lock()` síncrono e não colore
    # ninguém; os outros (`ColorTable.mutex_async`) usam `lock$async`.
    def mutex_id(self, call):
        """Identidade estática do Mutex de `x.Lock()`/`x.Unlock()`: campo de
        struct nomeada, var de pacote ou local; ("?", ...) se não dá para
        saber (ponteiro passado adiante)."""
        fun = unparen(call["fun"])
        info = fun.get("$sel") or {}
        x = unparen(fun["x"])
        path = info.get("index") or [0]
        if len(path) > 1:  # Lock promovido de um campo embutido
            t = self.pkg.type_of(x)
            for fi in path[:-1]:
                owner = self.pkg.type_at(t["elem"]) if t["kind"] == "pointer" else t
                f = self.typesys.underlying(owner)["fields"][fi]
                t = self.pkg.type_at(f["type"])
            return self.field_id(owner, f["name"])
        if x["node"] == "SelectorExpr" and (x.get("$sel") or {}).get("kind") == "field":
            owner = self.pkg.type_of(x["x"])
            if owner["kind"] == "pointer":
                owner = self.pkg.type_at(owner["elem"])
            for fi in x["$sel"]["index"][:-1]:
                owner = self.pkg.type_at(self.typesys.underlying(owner)["fields"][fi]["type"])
                if owner["kind"] == "pointer":
                    owner = self.pkg.type_at(owner["elem"])
            return self.field_id(owner, x["sel"]["name"])
        if x["node"] == "SelectorExpr" and (x["x"].get("$obj") or {}).get("kind") == "package":
            return ("var", x["x"]["$obj"]["pkg"], x["sel"]["name"])
        obj = x.get("$obj") or {} if x["node"] == "Ident" else {}
        if obj.get("kind") == "var" and self.pkg.type_of(x)["kind"] != "pointer":
            return ("var", obj["pkg"], obj["name"]) if obj.get("top") else ("local", self.pkg.path, obj["decl"])
        pos = first_pos(call)
        return ("?", self.pkg.path, f"{pos['file']}:{pos['offset']}")

    @staticmethod
    def field_id(owner, name):
        if owner["kind"] != "named":
            return ("?", "", name)
        return ("field", owner["pkg"], owner["name"], name)

    def lock_sites(self, node):
        """[(mutex, seção, vaza)] dos `Lock`/`RLock` do corpo (sem func
        literals): a seção vai até o `Unlock` correspondente no mesmo bloco,
        ou até o fim da função com `defer Unlock`; sem destravar no bloco o
        Mutex fica travado depois dele (`vaza`: conservador, disputável)."""
        sites = []
        for blk in walk(node, funclits=False):
            stmts = blk.get("list") if blk.get("node") == "BlockStmt" else blk.get("body")
            if blk.get("node") not in ("BlockStmt", "CaseClause", "CommClause") or not stmts:
                continue
            for i, s in enumerate(stmts):
                lock = self.lock_call(s)
                if lock is None:
                    continue
                mid, unlock = self.mutex_id(lock), LOCKS[self.callee_key(lock)]
                section, leak = None, True
                for j in range(i + 1, len(stmts)):
                    nxt = stmts[j]
                    call = nxt.get("call") if nxt["node"] == "DeferStmt" else (
                        nxt["x"] if nxt["node"] == "ExprStmt" else None)
                    if (call and call["node"] == "CallExpr" and unparen(call["fun"])["node"] == "SelectorExpr"
                            and unparen(call["fun"])["sel"]["name"] == unlock and self.mutex_id(call) == mid):
                        if nxt["node"] == "DeferStmt":
                            section = [node]  # até o fim da função
                        else:
                            section = stmts[i + 1:j]
                        leak = False
                        break
                sites.append((mid, section if section is not None else [node], leak))
        return sites

    def lock_call(self, s):
        if s.get("node") != "ExprStmt" or s["x"]["node"] != "CallExpr":
            return None
        return s["x"] if self.callee_key(s["x"]) in LOCKS else None

    @staticmethod
    def has_default(select_stmt):
        return any(c["comm"] is None for c in select_stmt["body"]["list"] or [])

    def is_chan_range(self, range_stmt):
        return self.typesys.underlying(self.pkg.type_of(range_stmt["x"]))["kind"] == "chan"

    # ------------------------------------------------------------ emissão
    def is_async(self, key):
        colors = self.facts.colors
        return key is not None and colors is not None and colors.is_async(key)

    def is_forced(self, key):
        """O grupo da chave precisa ficar síncrono (ver `forced_sync`)."""
        colors = self.facts.colors
        return colors.is_forced(key) if colors is not None else self.forced_sync(key)

    def results(self, key, sig):
        """Tipo de retorno Dart de uma função/método com a chave: `Future<R>`
        se a cor dela é `async`."""
        ret = self.types.results(sig["results"])
        return self.types.future(ret) if self.is_async(key) else ret

    def awaits(self, call):
        """A chamada é emitida com `await`: callee `async`, `Lock`/`Wait`
        do shim num contexto `async`, ou `Once.Do(f)` com `f` async."""
        key = self.callee_key(call)
        shim = SUSPENDING_SHIM.get(key)
        if shim:
            if not shim[1]:
                return True
            colors = self.facts.colors
            return bool(self.scope and self.scope.async_ctx and colors is not None
                        and colors.mutex_async(self.mutex_id(call)))
        if key == ONCE_DO:
            from g2d.analysis.color import func_ref_key

            return self.is_async(func_ref_key(self, (call["args"] or [None])[0]))
        return self.is_async(key)

    def require_async(self, node, what):
        """Ponto de suspensão (`await`) na função corrente: ela tem que ser
        `async`; senão é um contexto que o g2d não tem como suspender."""
        scope = self.scope
        if scope is None or not scope.async_ctx:
            reason = scope.sync_reason if scope is not None else "contexto-sincrono"
            raise Unsupported(f"async:{reason}", f"{what} num contexto que não pode suspender ({reason})", node)
