"""Concorrência (M4): chaves de cor das funções, suspensão direta (canais,
`select`, `range` sobre chan, `sync` que espera) e a consulta da cor na
emissão. A cor em si (quem é `async`, no grafo inteiro) é calculada pela
`ColorTable` de `g2d/analysis/color.py`; este serviço só sabe dar nome às
funções e reconhecer, num corpo isolado, o que ELE MESMO faz."""

from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported, first_pos, unparen, walk
from g2d.services.dualio import dual_capable

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
    # Canais pelo reflect: `select$async`, `send$async`, `recv$async`.
    ("f", "reflect", "Select"): ("select$async", False),
    ("m", "reflect", "Value", "Send"): ("send$async", False),
    ("m", "reflect", "Value", "Recv"): ("recv$async", False),
}
# Funções do shim que sempre suspendem (devolvem Future): `await time.sleep(d)`.
SUSPENDING_FUNCS = frozenset({("f", "time", "Sleep")})
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

# Funções/métodos da stdlib que recebem uma função e a rodam numa goroutine
# nova (ou, no `Once.Do`, com `do$async`): o shim aceita `FutureOr<void>
# Function()`, então o parâmetro (índice) não força a classe da func a
# ficar síncrona.
SPAWNING_SHIM = {
    ("f", "time", "AfterFunc"): 1,
    ("f", "context", "AfterFunc"): 1,
    WAITGROUP_GO: 0,
    ONCE_DO: 0,
}

# Funções do shim que devolvem uma função da mesma classe da que recebem e
# são genéricas no formato Dart (`R Function() onceFunc<R>(R Function()?)`):
# servem a uma classe síncrona ou `async`, então não a prendem.
COLOR_POLYMORPHIC_SHIM = frozenset({("f", "sync", "OnceFunc")})

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

    # ------------------------------------------------------------ classes de func
    # Um valor de função tem o tipo Dart da CLASSE da assinatura dele: a
    # assinatura subjacente canônica (identidade de tipo do Go, igual em
    # todo pacote). A classe é `async` (`Future<R> Function(...)`) se alguma
    # função `async` vira valor dela; aí toda chamada por valor da classe
    # espera. Chave: ("sig", texto canônico).
    def sig_key(self, t):
        """Classe de um tipo func (nomeado ou não): a assinatura subjacente.
        Tipo nomeado da stdlib (`context.CancelFunc`) é classe própria: o
        shim fixa o formato dele (síncrono), sem prender a `func()` comum."""
        t = self.pkg.type_at(t)
        if t.get("$class"):  # campo com classe própria (analysis/color.field_classes)
            return t["$class"]
        if self.std_named_func(t):
            return ("sig", self.canon(t))
        return ("sig", self.canon(self.typesys.underlying(t)))

    def std_named_func(self, t):
        return (t is not None and t["kind"] == "named" and bool(t["pkg"]) and self.std(t["pkg"])
                and self.typesys.underlying(t)["kind"] == "func")

    def canon(self, t):
        """Texto canônico da identidade Go de um tipo (caminho completo dos
        pacotes; `byte`/`rune` são `uint8`/`int32`)."""
        t = self.pkg.type_at(t)
        memo = self.__dict__.setdefault("_canon", {})
        if id(t) in memo:
            return memo[id(t)]
        k, c = t["kind"], self.canon
        if k == "basic":
            out = {"byte": "uint8", "rune": "int32"}.get(t["name"], t["name"])
        elif k == "named":
            args = t.get("args") or []
            out = (f"{t['pkg']}." if t["pkg"] else "") + t["name"] + (
                "[" + ",".join(c(a) for a in args) + "]" if args else "")
        elif k == "typeparam":
            out = "$tp:" + t["name"]
        elif k == "pointer":
            out = "*" + c(t["elem"])
        elif k == "slice":
            out = "[]" + c(t["elem"])
        elif k == "array":
            out = f"[{t['len']}]" + c(t["elem"])
        elif k == "chan":
            out = f"chan{t.get('dir', '')} " + c(t["elem"])
        elif k == "map":
            out = f"map[{c(t['key'])}]" + c(t["elem"])
        elif k == "func":
            out = ("func(" + ",".join(c(p) for p in t["params"]) + ("..." if t["variadic"] else "")
                   + ")(" + ",".join(c(r) for r in t["results"]) + ")")
        elif k == "interface":
            ms = sorted(m["name"] + c(m["type"])[4:] for m in t["methods"])
            out = "interface{" + ";".join(ms + sorted(c(e) for e in t["embeddeds"])) + "}"
        elif k == "struct":
            out = "struct{" + ";".join(("~" if f["embedded"] else "") + f["name"] + " " + c(f["type"])
                                       + (f" {f['tag']!r}" if f.get("tag") else "") for f in t["fields"]) + "}"
        elif k == "tuple":
            out = "(" + ",".join(c(e) for e in t["elems"]) + ")"
        else:
            out = k
        memo[id(t)] = out
        return out

    def func_classes(self, t, out=None, seen=None):
        """Classes de func que aparecem em t (dentro de compostos sem nome e
        de tipos nomeados sobre func): o formato Dart delas está fixo ali."""
        out = set() if out is None else out
        seen = set() if seen is None else seen
        t = self.pkg.type_at(t)
        if id(t) in seen:
            return out
        seen.add(id(t))
        k = t["kind"]
        if k == "named":
            u = self.typesys.underlying(t)
            if u["kind"] == "func" and self.std_named_func(t):
                out.add(self.sig_key(t))  # classe própria; as funcs dentro dela, não
                for x in u["params"] + u["results"]:
                    self.func_classes(x, out, seen)
            elif u["kind"] == "func":
                self.func_classes(u, out, seen)
        elif k == "func":
            out.add(("sig", self.canon(t)))
            for x in t["params"] + t["results"]:
                self.func_classes(x, out, seen)
        elif k in ("pointer", "slice", "array", "chan"):
            self.func_classes(t["elem"], out, seen)
        elif k == "map":
            self.func_classes(t["key"], out, seen)
            self.func_classes(t["elem"], out, seen)
        elif k == "struct":
            for f in t["fields"]:
                self.func_classes(f["type"], out, seen)
        elif k == "tuple":
            for e in t["elems"]:
                self.func_classes(e, out, seen)
        return out

    def value_call_key(self, call):
        """Classe da func de uma chamada por valor (variável, campo, resultado
        de chamada, method value guardado...), ou None se não é chamada por
        valor (função/método declarado, literal, builtin, conversão)."""
        fun = unparen(call["fun"])
        if fun.get("$isType") or fun.get("$builtin") or self.callee_key(call) is not None:
            return None
        if fun["node"] in ("IndexExpr", "IndexListExpr") and self.calls.instantiation(fun):
            return None
        if fun["node"] == "SelectorExpr" and (fun.get("$sel") or {}).get("kind") == "method":
            return None  # método de struct anônima com embedding (sem chave)
        t = self.pkg.type_of(fun)
        if t is None or self.typesys.underlying(t)["kind"] != "func":
            return None
        return self.sig_key(t)

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
        if key[0] == "sig":  # parâmetro de tipo (genérico) ou tipo nomeado da stdlib: formato fixo
            return "$tp:" in key[1] or not key[1].startswith("func(")
        if key[0] == "m":
            # I/O com versão dupla (D2) segue a cor das implementações.
            return key[3] in SYNC_METHODS or key[1] == "" or (Concurrency.std(key[1]) and not dual_capable(key))
        return key[0] == "f" and Concurrency.std(key[1])

    # ------------------------------------------------------------ suspensão direta
    def direct_suspend(self, node):
        """(hard, soft) da função/literal (sem contar func literals
        aninhadas): `hard` = operação de canal, `select` sem `default`,
        `range` sobre chan, `WaitGroup.Wait`/`Cond.Wait`, `time.Sleep`; `soft` = `Lock`
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
                ck = self.callee_key(n)
                shim = SUSPENDING_SHIM.get(ck)
                if shim:
                    soft, hard = soft or shim[1], hard or not shim[1]
                elif ck in SUSPENDING_FUNCS:
                    hard = True
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

    def has_twin(self, key):
        """A função tem a gêmea síncrona `$sync` (I/O dual, D2)."""
        colors = self.facts.colors
        return key is not None and colors is not None and colors.has_twin(key)

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
        if key in SUSPENDING_FUNCS:
            return True
        if self.dualio.dual_call(call):
            return any(self.is_async(k) for k in self.dualio.call_deps(call))
        if key == ONCE_DO:
            return self.is_async(self.once_arg_key(call))
        if key is None:
            return self.is_async(self.value_call_key(call))
        return self.is_async(key)

    def reclass(self, n, src, target):
        """Valor func passando de uma classe para outra (só acontece entre um
        tipo nomeado da stdlib, `context.CancelFunc`, e a assinatura comum):
        None se o formato Dart é o mesmo; "wrap" se sai síncrono e entra
        numa classe `async` (`go.async0(cancel)`; "wrap-bare" se citada direto);
        "bare" se é uma função
        síncrona citada direto (literal, `f`, `x.M`) entrando numa classe
        síncrona a partir de uma `async` (emitida sem o embrulho). Recusa
        `async` virando síncrona."""
        from g2d.analysis.color import func_ref_key

        if src is None or target is None or src["kind"] == "typeparam" or target["kind"] == "typeparam":
            return None
        if self.typesys.underlying(src)["kind"] != "func" or self.typesys.underlying(target)["kind"] != "func":
            return None
        cs, ct = self.sig_key(src), self.sig_key(target)
        if cs == ct:
            return None
        a_src, a_tgt = self.is_async(cs), self.is_async(ct)
        ref = func_ref_key(self, n)
        if ref is not None:  # a cor que conta é a da própria função
            a_src = self.is_async(ref)
        if a_src == a_tgt:
            return "bare" if ref is not None else None
        if a_tgt:
            return "wrap-bare" if ref is not None else "wrap"
        raise Unsupported("async:valor-func",
                          "função que suspende usada como valor de uma assinatura que precisa ficar síncrona", n)

    def once_arg_key(self, call):
        """O que `Once.Do(f)` espera: a função de `f`, ou a classe dela se `f`
        é um valor."""
        from g2d.analysis.color import func_ref_key

        arg = (call["args"] or [None])[0]
        if arg is None:
            return None
        return func_ref_key(self, arg) or self.sig_key(self.pkg.type_of(arg))

    def require_async(self, node, what):
        """Ponto de suspensão (`await`) na função corrente: ela tem que ser
        `async`; senão é um contexto que o g2d não tem como suspender."""
        scope = self.scope
        if scope is None or not scope.async_ctx:
            reason = scope.sync_reason if scope is not None else "contexto-sincrono"
            raise Unsupported(f"async:{reason}", f"{what} num contexto que não pode suspender ({reason})", node)
