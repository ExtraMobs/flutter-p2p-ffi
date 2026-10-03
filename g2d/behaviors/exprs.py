"""Um comportamento por expressão Go."""

from g2d.engine.behavior import NOT_HANDLED, ExprBehavior
from g2d.engine.precedence import DART_PREC, NON_ASSOC, POSTFIX, UNARY
from g2d.model import Unsupported, has_recover, unparen
from g2d.services.concurrency import ONCE_DO, SUSPENDING_SHIM
from g2d.services.naming import member_name, param_name, top_member_name, type_name


class Ident(ExprBehavior):
    kinds = ("Ident",)

    def emit(self, n):
        return self.ident(n), POSTFIX + 1

    def ident(self, n):
        obj = n.get("$obj")
        if obj is None:
            raise Unsupported("ident-sem-objeto", f"identificador sem objeto {n['name']}", n)
        kind = obj["kind"]
        if kind == "nil":
            return "null"
        if kind in ("var", "func", "const") and obj.get("top"):
            if obj["pkg"] != self.pkg.path:
                return (self.imports.qualify(obj["pkg"], top_member_name(obj["name"], obj.get("fold")))
                        + self.names.box_suffix(obj))
            return self.names.top_ref(obj) + self.names.box_suffix(obj)
        if kind == "var":
            if self.scope and obj.get("decl") == self.scope.recv:
                return "this"
            if self.scope and obj.get("decl") in self.scope.locals:
                return self.scope.locals[obj["decl"]] + self.names.box_suffix(obj)
            raise Unsupported("local-nao-declarada", f"variável local não declarada {n['name']}", n)
        if kind == "type":
            return self.types.dart(n["$type"])
        raise Unsupported(f"ident:{kind}", f"identificador {kind} {n['name']}", n)


class ParenExpr(ExprBehavior):
    kinds = ("ParenExpr",)

    def emit(self, n):
        return f"({self.expr(n['x'])})", POSTFIX + 1


class BasicLit(ExprBehavior):
    kinds = ("BasicLit",)

    def emit(self, n):
        raise Unsupported("literal-sem-valor", "literal sem valor constante", n)


class BinaryExpr(ExprBehavior):
    kinds = ("BinaryExpr",)

    def emit(self, n):
        op = n["op"]
        b = self.typesys.basic(self.pkg.type_of(n["x"]))
        if op not in ("==", "!=", "&&", "||") and self.functions.loose(self.pkg.type_of(n["x"])):
            raise Unsupported("constraint:operador", f"operador {op} sobre parâmetro de tipo sem bound comum", n)
        if op in ("<<", ">>"):
            p = DART_PREC[op]
            return f"{self.expr(n['x'], p)} {op} {self.operands.shift_count(n['y'])}", p
        if op == "/" and self.pkg.type_of(n["x"])["kind"] == "typeparam":
            return f"{self.expr(n['x'], POSTFIX)}.$quo({self.expr(n['y'])})", POSTFIX
        if op == "/" and b is not None and b.integer:
            op = "~/"
        if op == "&^":
            return f"{self.expr(n['x'], POSTFIX)}.andNot({self.expr(n['y'])})", POSTFIX
        if op in ("==", "!=") and self.nil_compare(n) is not None:
            text = f"{self.expr(self.nil_compare(n), POSTFIX)}.isNil"
            return (text, POSTFIX) if op == "==" else (f"!{text}", UNARY)
        mixed = self.iface_ptr_compare(n) if op in ("==", "!=") else None
        if mixed:
            iface, ptr = mixed
            eq = (f"{self.imports.qualify(None, 'ifaceEq')}({self.expr(iface)}, "
                  f"{self.values.coerce(ptr, self.pkg.type_of(iface))})")
            return (eq, POSTFIX) if op == "==" else (f"!{eq}", UNARY)
        if op in ("==", "!=") and self.iface_compare(n):
            eq = f"{self.imports.qualify(None, 'ifaceEq')}({self.expr(n['x'])}, {self.expr(n['y'])})"
            return (eq, POSTFIX) if op == "==" else (f"!{eq}", UNARY)
        if op in ("==", "!=") and self.pointer_compare(n):
            eq = f"identical({self.expr(n['x'])}, {self.expr(n['y'])})"
            return (eq, POSTFIX) if op == "==" else (f"!{eq}", UNARY)
        if op not in DART_PREC:
            raise Unsupported(f"operador:{op}", f"operador {op}", n)
        p = DART_PREC[op]
        left = p + 1 if op in NON_ASSOC else p
        t = self.pkg.type_of(n)
        if op in ("&&", "||") and self.typesys.named_bool(t):
            # Flag && Flag: desembrulha e devolve o tipo nomeado.
            text = f"{self.operands.cond(n['x'], left)} {op} {self.operands.cond(n['y'], p + 1)}"
            return f"{self.types.dart(t)}({text})", POSTFIX
        if op in ("&&", "||"):
            return f"{self.operands.cond(n['x'], left)} {op} {self.operands.cond(n['y'], p + 1)}", p
        return f"{self.expr(n['x'], left)} {op} {self.expr(n['y'], p + 1)}", p

    def pointer_compare(self, n):
        """Ponteiros para struct (o próprio objeto): identidade, não o == estrutural.
        go.Ptr já compara por endereço no ==."""
        tx, ty = self.pkg.type_of(n["x"]), self.pkg.type_of(n["y"])
        return self.typesys.is_struct_pointer(tx) and self.typesys.is_struct_pointer(ty)

    def iface_compare(self, n):
        """Comparação entre dois valores de interface (não-nil)."""
        tx, ty = self.pkg.type_of(n["x"]), self.pkg.type_of(n["y"])
        is_iface = [t is not None and t.get("kind") != "basic" and self.typesys.underlying(t)["kind"] == "interface"
                    for t in (tx, ty)]
        return all(is_iface)

    def iface_ptr_compare(self, n):
        """`i == p` com i interface e p ponteiro: p entra na interface."""
        for a, b in (("x", "y"), ("y", "x")):
            ta, tb = self.pkg.type_of(n[a]), self.pkg.type_of(n[b])
            if (ta is not None and tb is not None and ta.get("kind") != "basic"
                    and self.typesys.underlying(ta)["kind"] == "interface" and tb["kind"] == "pointer"):
                return n[a], n[b]
        return None

    def nil_compare(self, n):
        """`s == nil` com slice/map: go.Slice/go.GoMap nunca são null."""
        for a, b in (("x", "y"), ("y", "x")):
            ta, tb = self.pkg.type_of(n[a]), self.pkg.type_of(n[b])
            if (tb is not None and tb["kind"] == "basic" and tb["name"] == "untyped nil"
                    and ta is not None and (self.typesys.underlying(ta)["kind"] in ("slice", "map")
                                            or self.typesys.named_func(ta))):
                return n[a]
        return None


class UnaryExpr(ExprBehavior):
    kinds = ("UnaryExpr",)

    def emit(self, n):
        op = n["op"]
        if op == "&":
            return self.address_of(n)
        if op == "<-":
            # `<-ch` (sem comma-ok): go.chanRecv (canal possivelmente nil
            # bloqueia pra sempre). `v, ok := <-ch` vai por Operands.multi_value.
            self.concurrency.require_async(n, "recepção de canal")
            recv = self.imports.qualify(None, "chanRecv")
            return f"await {recv}({self.expr(n['x'])})", UNARY
        dart_op = {"-": "-", "+": "", "!": "!", "^": "~"}.get(op)
        if dart_op is None:
            raise Unsupported(f"operador-unario:{op}", f"operador unário {op}", n)
        if self.functions.loose(self.pkg.type_of(n["x"])):
            raise Unsupported("constraint:operador", f"operador {op} sobre parâmetro de tipo sem bound comum", n)
        t = self.pkg.type_of(n)
        if op == "!" and self.typesys.named_bool(t):
            return f"{self.types.dart(t)}(!{self.operands.cond(n['x'], UNARY)})", POSTFIX
        x = self.expr(n["x"], UNARY)
        # "- -x" → evita "--x" (decremento).
        sep = " " if dart_op == "-" and x.startswith("-") else ""
        return f"{dart_op}{sep}{x}", UNARY

    def address_of(self, n):
        """`&x`: struct é o próprio endereço; variável em caixa é a caixa;
        `&s[i]` e `&o.f` viram go.ElemPtr / go.FieldPtr."""
        x = unparen(n["x"])
        if x["node"] == "CompositeLit" or self.typesys.is_value(self.pkg.type_of(x)):
            return self.expr_prec(x)
        if x["node"] == "Ident":
            return self.names.box_name(x["$obj"]), POSTFIX  # a caixa (BoxingAnalysis garantiu)
        if x["node"] == "SelectorExpr" and (x["x"].get("$obj") or {}).get("kind") == "package":
            # `&a.X`: var exportada de outro pacote sempre mora numa caixa.
            sel = x["sel"]
            return self.imports.qualify(x["x"]["$obj"]["pkg"], top_member_name(sel["name"], sel["$obj"].get("fold"))), POSTFIX
        xt = self.pkg.type_of(x)
        view = (lambda p: f"{self.types.ptr_view(xt)}({p})") if self.typesys.ptr_class(xt) else (lambda p: p)
        if x["node"] == "IndexExpr" and self.typesys.underlying(self.pkg.type_of(x["x"]))["kind"] in ("slice", "array"):
            return view(f"{self.expr(x['x'], POSTFIX)}.addr({self.operands.to_int(x['index'])})"), POSTFIX
        if x["node"] == "SelectorExpr" and x.get("$sel", {}).get("kind") == "field":
            owner_t = self.pkg.type_of(x["x"])
            self.imports.shim_member(owner_t, x["sel"]["name"], x)
            owner = self.expr(x["x"], POSTFIX)
            if owner_t["kind"] == "pointer":
                owner += "!"
                owner_t = self.pkg.type_at(owner_t["elem"])
            f = member_name(x["sel"]["name"])
            ot, ft = self.types.dart(owner_t), self.types.dart(self.pkg.type_of(x))
            return view(f"{self.imports.qualify(None, 'FieldPtr')}<{ot}, {ft}>({owner}, '{f}', "
                        f"(o) => o.{f}, (o, v) => o.{f} = v)"), POSTFIX
        raise Unsupported("endereco-expr", "& de expressão", n)


class StarExpr(ExprBehavior):
    kinds = ("StarExpr",)

    def emit(self, n):
        if self.typesys.is_struct_pointer(self.pkg.type_of(n["x"])):
            return f"{self.expr(n['x'], POSTFIX)}!", POSTFIX
        x = self.expr(n["x"], POSTFIX)
        return f"{x}{'' if x == 'this' else '!'}.value", POSTFIX


class SelectorExpr(ExprBehavior):
    kinds = ("SelectorExpr",)

    def emit(self, n):
        x, sel = n["x"], n["sel"]["name"]
        xobj = x.get("$obj") if x["node"] == "Ident" else None
        if xobj and xobj["kind"] == "package":
            obj = n["sel"]["$obj"]
            name = type_name(sel) if obj["kind"] == "type" else top_member_name(sel, obj.get("fold"))
            return self.imports.qualify(xobj["pkg"], name) + self.names.box_suffix(obj), POSTFIX + 1
        info = n.get("$sel")
        if info is None:
            raise Unsupported("seletor", "seletor", n)
        if info["kind"] == "methodExpr":
            return self.method_expr(n, info), 0
        t = self.pkg.type_of(x)
        self.check_shim_members(t, info, sel, n)
        if info["kind"] == "method" and len(info["index"]) > 1:
            explicit = self.promoted_ptr_method(n, x, t, info)
            if explicit is not None:
                return self.emit(explicit)
        if info["kind"] == "method" and len(info["index"]) == 1 and self.calls.ptr_method_of(t, sel):
            if self.scope and self.scope.recv and x.get("$obj", {}).get("decl") == self.scope.recv:
                raise Unsupported("metodo-ptr-receptor-valor", "método de receptor ponteiro sobre o receptor valor", n)
            recv = self.expr({"node": "UnaryExpr", "op": "&", "x": x}, POSTFIX)
            return f"{recv}.{member_name(sel)}", POSTFIX
        recv = self.expr(x, POSTFIX)
        if (recv != "this" and info["kind"] == "method" and len(info["index"]) == 1
                and self.typesys.is_struct_pointer(t) and self.calls.ptr_method(t, sel)):
            # Método com receptor ponteiro aceita ponteiro nil: sentinela.
            elem = self.pkg.type_at(t["elem"])
            if not self.typesys.type_args(elem):
                return f"({recv} ?? {self.types.dart(elem)}.$nil).{member_name(sel)}", POSTFIX
        # Ponteiro ou interface nil → panic do Go (via `!`).
        if recv != "this" and (t["kind"] == "pointer" or self.typesys.underlying(t)["kind"] == "interface"
                               or self.functions.pointer_tparam(t)):
            recv += "!"
        # Seleção promovida por embedding: caminho de campos do go/types.
        for fi in info["index"][:-1]:
            if t["kind"] == "pointer":
                t = self.pkg.type_at(t["elem"])
            f = self.typesys.underlying(t)["fields"][fi]
            recv += "." + member_name(f["name"])
            t = self.pkg.type_at(f["type"])
            if t["kind"] == "pointer" or self.typesys.underlying(t)["kind"] == "interface":
                recv += "!"
        if info["kind"] == "method" and not n.get("$called") and self.calls.value_method(t, sel):
            # Method value `x.M` (receptor valor): liga uma cópia de x feita agora.
            recv += ".$copy()"
        return f"{recv}.{member_name(sel)}", POSTFIX

    def promoted_ptr_method(self, n, x, t, info):
        """`h.Inc()` com Inc de receptor ponteiro de um N não-struct
        embutido por valor (`type Counter int` em `Holder{Counter}`): vira a
        seleção explícita `h.Counter.Inc()`, que usa `&h.Counter` (a vista
        N$Ptr sobre go.FieldPtr). Outros casos: None (caminho normal)."""
        fields, cur = [], t
        for fi in info["index"][:-1]:
            if cur["kind"] == "pointer":
                cur = self.pkg.type_at(cur["elem"])
            f = self.typesys.underlying(cur)["fields"][fi]
            fields.append((fi, f))
            cur = self.pkg.type_at(f["type"])
        if not self.calls.ptr_method_of(cur, n["sel"]["name"]):
            return None
        for fi, f in fields:
            x = {"node": "SelectorExpr", "x": x, "sel": {"node": "Ident", "name": f["name"]},
                 "$sel": {"kind": "field", "index": [fi]}, "$type": f["type"]}
        return dict(n, x=x, **{"$sel": dict(info, index=info["index"][-1:])})

    def check_shim_members(self, t, info, sel, n):
        """Cada campo do caminho de embedding e o membro final, quando o dono
        é tipo concreto de shim, têm de existir na classe Dart do shim."""
        for fi in info["index"][:-1]:
            if t["kind"] == "pointer":
                t = self.pkg.type_at(t["elem"])
            f = self.typesys.underlying(t)["fields"][fi]
            self.imports.shim_member(t, f["name"], n)
            t = self.pkg.type_at(f["type"])
        self.imports.shim_member(t, sel, n)

    def method_expr(self, n, info):
        """Method expression `T.M` / `(*T).M`: função com o receptor como
        primeiro parâmetro, que chama o método pelo caminho normal de seleção
        (nil sentinela, promoção por embedding)."""
        ft = self.pkg.type_of(n)
        params = [f"{self.types.dart(self.pkg.type_at(p))} ${i}" for i, p in enumerate(ft["params"])]
        recv = {"node": "G2DTemp", "text": "$0", "$type": info["recv"]}
        sel = dict(n, x=recv, **{"$sel": dict(info, kind="method"), "$called": True})
        args = ", ".join(f"${i}" for i in range(1, len(params)))
        return f"({', '.join(params)}) => {self.expr(sel, POSTFIX)}({args})"


class IndexExpr(ExprBehavior):
    kinds = ("IndexExpr",)

    def emit(self, n):
        u = self.typesys.underlying(self.pkg.type_of(n["x"]))
        x = self.expr(n["x"], POSTFIX)
        if u["kind"] == "pointer":  # p[i] com p *[N]T
            u, x = self.typesys.underlying(self.pkg.type_at(u["elem"])), x + "!"
        if u["kind"] in ("slice", "array"):
            return f"{x}[{self.operands.to_int(n['index'])}]", POSTFIX
        if u["kind"] == "basic":  # string: o byte no índice
            return f"{self.types.golang('Uint8')}({x}[{self.operands.to_int(n['index'])}])", POSTFIX
        i = self.expr(n["index"])
        if u["kind"] == "map":
            return f"{x}[{i}]", POSTFIX  # go.GoMap devolve o zero value
        raise Unsupported(f"indice:{u['kind']}", f"índice sobre {u['kind']}", n)


class SliceExpr(ExprBehavior):
    kinds = ("SliceExpr",)

    def emit(self, n):
        u = self.typesys.underlying(self.pkg.type_of(n["x"]))
        deref = ""
        if u["kind"] == "pointer":  # p[a:b] com p *[N]T
            u, deref = self.typesys.underlying(self.pkg.type_at(u["elem"])), "!"
        if u["kind"] not in ("slice", "array", "basic"):
            raise Unsupported(f"slicing:{u['kind']}", f"slicing de {u['kind']}", n)
        args = [self.operands.to_int(n["low"]) if n["low"] else "0"]
        if n["high"] or n["max"]:
            args.append(self.operands.to_int(n["high"]) if n["high"] else "null")
        if n["max"]:
            args.append(self.operands.to_int(n["max"]))
        text = f"{self.expr(n['x'], POSTFIX)}{deref}.slice({', '.join(args)})"
        return self.types.wrap(self.pkg.type_of(n), text), POSTFIX


class KeyValueExpr(ExprBehavior):
    kinds = ("KeyValueExpr",)

    def emit(self, n):
        raise Unsupported("keyvalue-fora-literal", "KeyValueExpr fora de literal composto", n)


class CompositeLit(ExprBehavior):
    kinds = ("CompositeLit",)

    def emit(self, n):
        t = self.pkg.type_of(n)
        if t["kind"] == "pointer" and self.typesys.is_value(self.pkg.type_at(t["elem"])):
            # `[]*P{{1, 2}}`: `&P{1, 2}` elidido; struct/array é o próprio endereço.
            return self.emit(dict(n, **{"$type": t["elem"]}))
        u = self.typesys.underlying(t)
        elts = n["elts"] or []
        if u["kind"] == "struct":
            args = []
            fields = [f for f in u["fields"]]
            for i, e in enumerate(elts):
                if e["node"] == "KeyValueExpr":
                    fname, val = e["key"]["name"], e["value"]
                else:
                    fname, val = fields[i]["name"], e
                if fname == "_":
                    continue
                ftype = next(self.pkg.type_at(f["type"]) for f in fields if f["name"] == fname)
                args.append(f"{param_name(fname)}: {self.values.coerce(val, ftype)}")
            args = [self.descriptors.elem(a) for a in self.typesys.type_args(t)] + args
            return f"{self.types.dart(t)}({', '.join(args)})", POSTFIX
        if u["kind"] in ("slice", "array"):
            elem = self.pkg.type_at(u["elem"])
            items = ", ".join(self.indexed(elts, elem, u.get("len")))
            lit = f"{self.types.dart(u)}.of([{items}], {self.descriptors.elem(elem)})"
            return self.types.wrap(t, lit), POSTFIX
        if u["kind"] == "map":
            kt, vt = self.pkg.type_at(u["key"]), self.pkg.type_at(u["elem"])
            items = ", ".join(f"{self.values.coerce(e['key'], kt)}: {self.values.coerce(e['value'], vt)}" for e in elts)
            lit = f"{self.types.dart(u)}.of({{{items}}}, {self.descriptors.elem(vt)}{self.typesys.map_args(t)})"
            return self.types.wrap(t, lit), POSTFIX
        raise Unsupported(f"literal-composto:{u['kind']}", f"literal composto de {u['kind']}", n)

    def indexed(self, elts, elem, length=None):
        """Elementos de `[]T{...}`/`[N]T{...}` em ordem de índice: chaves
        constantes (`{2: x, y}`) posicionam, lacunas e o fim do array recebem
        o zero value."""
        by_index, i = {}, 0
        for e in elts:
            if e["node"] == "KeyValueExpr":
                i, e = int(e["key"]["$value"]["value"]), e["value"]
            by_index[i] = self.values.coerce(e, elem)
            i += 1
        size = length if length is not None else max(by_index, default=-1) + 1
        return [by_index[k] if k in by_index else self.types.zero(elem) for k in range(size)]


class FuncLit(ExprBehavior):
    kinds = ("FuncLit",)

    def emit(self, n):
        if self.scope is None:
            raise Unsupported("func-literal-pacote", "func literal em nível de pacote", n)
        sig = self.pkg.type_of(n)
        params, boxes = self.functions.params(n["type"]["params"], sig)
        saved_rd, saved_breaks = self.scope.rd, self.scope.breaks
        saved_color = self.scope.async_ctx, self.scope.sync_reason
        self.scope.breaks = []
        self.scope.rd = "$rd" if has_recover(n["body"]) else None
        key = self.concurrency.lit_key(n)
        is_async = self.concurrency.is_async(key)
        try:
            self.functions.enter_color(is_async, n["body"], key, n)
            if self.scope.rd:
                params = ", ".join(p for p in (params, self.functions.rd_param()) if p)
            body = self.functions.func_body(n["type"], n["body"], sig)
        finally:  # Unsupported no corpo não pode deixar trocado o estado da função externa
            self.scope.rd, self.scope.breaks = saved_rd, saved_breaks
            self.scope.async_ctx, self.scope.sync_reason = saved_color
        # Literal síncrono numa classe de func async: o próprio literal vira
        # `async` (o corpo não espera nada; o resultado vira Future).
        kw = " async" if is_async or id(n) in self.facts.wrap_values else ""
        return f"({params}){kw} {{\n" + "\n".join(boxes + body) + "\n}", 0


class CallExpr(ExprBehavior):
    kinds = ("CallExpr",)

    def emit(self, n):
        fun, args = n["fun"], n["args"] or []
        if fun.get("$isType"):
            return self.engine.convert(n, fun, args[0])
        if fun.get("$builtin"):
            return self.engine.builtin(n, fun, args)
        fun_t = self.pkg.type_of(fun)
        sig = self.typesys.underlying(fun_t) if fun_t is not None else None
        if sig is None or sig["kind"] != "func":
            raise Unsupported("chamada-nao-funcao", "chamada de valor não-função", n)
        spread = self.pkg.type_of(args[0]) if len(args) == 1 else None
        if spread is not None and spread["kind"] == "tuple":
            # f(g()): o record de g() é desestruturado num switch expression
            # (liga os temporários sem statement) e espalhado nos argumentos.
            temps = [self.names.temp() for _ in spread["elems"]]
            nodes = [{"node": "G2DTemp", "text": t, "$type": e} for t, e in zip(temps, spread["elems"])]
            call, _ = self.emit(dict(n, args=nodes))
            pattern = ", ".join(f"final {t}" for t in temps)
            return f"(switch ({self.expr(args[0])}) {{ ({pattern}) => {call} }})", POSTFIX
        inst = self.calls.instantiation(fun)
        # Ordem do gc: `fun` (receptor de método inclusive) e os argumentos
        # formam uma só lista; uma chamada entre eles roda antes de qualquer
        # operando simples que ela possa alterar (`t.M(f())`, `f(x, g())`,
        # variádicos; TODO/P1-construcao-ordem-avaliacao). Instanciação
        # genérica (`f[T]`) não entra: o índice é o argumento de tipo, não
        # uma expressão de runtime.
        items = list(args) if inst else [fun] + list(args)
        pending, rewritten, risky = self.evalorder.gather(items)
        if pending and risky:
            if inst:
                args = rewritten
            else:
                fun, *args = rewritten
            call, _ = self.emit(dict(n, fun=fun, args=args))
            return self.evalorder.wrap(pending, call), POSTFIX
        ptypes = [self.pkg.type_at(t) for t in sig["params"]]
        if sig["variadic"] and n["ellipsis"] is None:
            elem = self.pkg.type_at(ptypes[-1]["elem"])
            ptypes = ptypes[:-1] + [elem] * (len(args) - len(ptypes) + 1)
        out = [self.values.coerce(a, t) for a, t in zip(args, ptypes)]
        origin = self.genptr.origin_sig(inst[0]) if inst else None
        if origin is not None:
            # `*T` genérico ← `*P` (struct/array é o próprio objeto).
            optypes = list(origin["params"])
            if origin["variadic"] and n["ellipsis"] is None:
                optypes = optypes[:-1] + [self.pkg.type_at(optypes[-1])["elem"]] * (len(args) - len(optypes) + 1)
            out = [self.genptr.arg(text, o, t, a) for text, o, t, a in zip(out, optypes, ptypes, args)]
        if inst:
            generic, targs = inst
            callee = self.expr(generic, POSTFIX) + "<" + ", ".join(self.types.dart(a) for a in targs) + ">"
            out = [self.descriptors.elem(a) for a in targs] + out
        else:
            callee = self.expr(dict(fun, **{"$called": True}), POSTFIX)
        if not inst and not self.calls.declared_func(fun) and not self.typesys.named_func(fun_t):
            callee += "!"  # valor de função: anulável (zero value nil)
        if sig["variadic"] and n["ellipsis"] is None:
            fixed = len(sig["params"]) - 1 + (len(inst[1]) if inst else 0)
            st = self.pkg.type_at(sig["params"][-1])
            e = self.descriptors.elem(st["elem"])
            rest = out[fixed:]
            # f() sem argumentos variádicos recebe um slice nil (como no Go).
            packed = f"{self.types.dart(st)}.of([{', '.join(rest)}], {e})" if rest else self.types.zero(st)
            out = out[:fixed] + [packed]
        if n.get("$rdArg"):
            out.append(f"$rd: {n['$rdArg']}")
        if origin is not None:
            return self.genptr.result(f"{callee}({', '.join(out)})", origin, sig, n), POSTFIX
        return f"{callee}({', '.join(out)})", POSTFIX


class TypeAssertExpr(ExprBehavior):
    kinds = ("TypeAssertExpr",)

    def emit(self, n):
        mode, dt, t = self.asserts.assert_parts(n)
        x = self.expr(n["x"])
        target = self.goinfo.go_type_name(t)
        if mode == "iface":
            names = ", ".join(f"'{m['name']}'" for m in sorted(self.typesys.underlying(t)["methods"],
                                                                key=lambda m: m["name"]))
            return f"{self.imports.qualify(None, 'assertIface')}<{dt}>({x}, '{target}', const [{names}])", POSTFIX
        iface = self.goinfo.go_type_name(self.pkg.type_of(n["x"]))
        if mode == "func":
            return f"{self.imports.qualify(None, 'assertFunc')}<{dt}>({x}, '{iface}', '{target}')", POSTFIX
        struct = self.asserts.struct_flag(mode)
        return f"{self.imports.qualify(None, 'assertType')}<{dt}>({x}, '{iface}', '{target}'{struct})", POSTFIX


class FuncInstance(ExprBehavior):
    """`f[int]` / `pkg.New[K, V]` usado como valor (sem chamada): closure que
    instancia e passa os dicionários, `(p0) => f<Golang.Int>(_$e0, p0)`.
    A chamada direta `f[int](x)` é tratada no CallExpr."""

    kinds = ("IndexExpr", "IndexListExpr")

    def emit(self, n):
        inst = self.calls.instantiation(n)
        if inst is None:
            return NOT_HANDLED
        generic, targs = inst
        sig = self.pkg.type_of(n)
        origin = self.genptr.origin_sig(generic)
        params = [f"{self.types.dart(p)} p{i}" for i, p in enumerate(sig["params"])]
        args = [f"p{i}" for i in range(len(sig["params"]))]
        if origin is not None:  # `*T` genérico ← `*P` (struct/array é o próprio objeto)
            args = [self.genptr.arg(a, o, t, n) for a, o, t in zip(args, origin["params"], sig["params"])]
        args = [self.descriptors.elem(a) for a in targs] + args
        callee = self.expr(generic, POSTFIX) + "<" + ", ".join(self.types.dart(a) for a in targs) + ">"
        call = f"{callee}({', '.join(args)})"
        if origin is not None:
            call = self.genptr.result(call, origin, sig, n)
        return f"(({', '.join(params)}) => {call})", POSTFIX


class G2DTemp(ExprBehavior):
    kinds = ("G2DTemp",)

    def emit(self, n):
        return n["text"], POSTFIX + 1


class AsyncCall(ExprBehavior):
    """Chamada que espera (cor `async`, g2d/analysis/color.py): `await f(x)`.
    `Lock`/`Wait`/`Once.Do` do shim `sync` viram a variante suspensiva
    (`lock$async`...) num contexto `async`; num síncrono forçado o `Lock`
    fica `lock()`. A chamada em si é a do CallExpr (despacho com `$awaited`)."""

    kinds = ("CallExpr",)

    def emit(self, n):
        if n.get("$awaited") or not self.concurrency.awaits(n):
            return NOT_HANDLED
        self.concurrency.require_async(n, "chamada que suspende")
        key = self.concurrency.callee_key(n)
        fun = unparen(n["fun"])
        shim = SUSPENDING_SHIM.get(key)
        if shim or key == ONCE_DO:
            go_name = fun["sel"]["name"] + "$async"  # member_name: Lock$async → lock$async
            n = dict(n, fun=dict(fun, sel=dict(fun["sel"], name=go_name)))
        return f"await {self.expr(dict(n, **{'$awaited': True}), UNARY)}", UNARY


class AsyncValueGuard(ExprBehavior):
    """Função usada como valor (closure guardada, `f` sem chamar, method
    value) com cor diferente da classe da assinatura dela
    (g2d/analysis/color.py): `async` numa classe síncrona é recusada
    (formato Dart fixo pelo shim ou por um genérico); síncrona numa classe
    `async` é embrulhada (`go.async1(f)`; o literal vira `async` no FuncLit)."""

    kinds = ("Ident", "SelectorExpr", "FuncLit")

    def emit(self, n):
        if id(n) in self.facts.async_values:
            raise Unsupported("async:valor-func",
                              "função que suspende usada como valor de uma assinatura que precisa ficar síncrona", n)
        if id(n) not in self.facts.wrap_values or n["node"] == "FuncLit":
            return NOT_HANDLED
        arity = len(self.typesys.underlying(self.pkg.type_of(n))["params"])
        if arity > MAX_ASYNC_ARITY:
            raise Unsupported("async:valor-func-aridade", f"valor func síncrono com {arity} parâmetros numa classe async", n)
        inner = self.expr(dict(n), POSTFIX)  # cópia: id novo, não volta aqui
        return f"{self.imports.qualify(None, f'async{arity}')}({inner})", POSTFIX


# `go.async0`..`go.async8` (golib_dart/lib/src/runtime/async_fn.dart).
MAX_ASYNC_ARITY = 8
