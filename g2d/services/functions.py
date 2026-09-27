"""Funções e métodos: cabeçalho, receptor, parâmetros (tipo, `$rd`), corpo com defers."""

from g2d.engine.behavior import Service
from g2d.engine.scope import FunctionScope, TypeParams
from g2d.model import (Unsupported, assigns_var, has_bare_return, has_defer, has_recover, mutates_receiver,
                       uses_decl)
from g2d.services.literals import doc_comment, tuple_expr
from g2d.services.naming import member_name


class Functions(Service):
    """Funções e métodos: cabeçalho, receptor, parâmetros (tipo, `$rd`), corpo com defers."""

    name = "functions"

    def func_decl(self, d):
        if d["body"] is None:
            raise Unsupported("func-sem-corpo", "função sem corpo (assembly ou go:linkname): substituição", d)
        sig = self.pkg.type_at(d["name"]["$obj"]["type"])
        self.scope = FunctionScope()
        prologue = []
        if d["recv"]:
            recv_t = self.pkg.recv_type(d)
            names = d["recv"]["list"][0]["names"]
            if names and names[0]["name"] != "_":
                ident = names[0]
                mutated = mutates_receiver(d["body"], ident["$obj"]["decl"])
                if self.typesys.is_struct_pointer(recv_t):
                    # Receptor ponteiro: pode ser nil (sentinela `$nil` numa
                    # interface, ou chamada direta sobre ponteiro nil).
                    if uses_decl(d["body"], ident["$obj"]["decl"]):
                        local = self.names.declare_local(ident)
                        # `if s == nil { s = &T{} }`: o corpo pode reatribuir.
                        kw = "" if assigns_var(d["body"], ident["$obj"]["decl"]) else "final "
                        prologue.append(f"{kw}{self.types.dart(recv_t)} {local} = $nilPtr ? null : this;")
                elif self.typesys.is_value(recv_t) and mutated:
                    # Receptor valor é uma cópia no Go: mutações não vazam.
                    local = self.names.declare_local(ident)
                    prologue.append(f"final {self.types.dart(recv_t)} {local} = this.$copy();")
                elif (mutated or ident["$obj"]["decl"] in self.facts.boxed) and recv_t["kind"] == "named":
                    # Tipos básicos nomeados são imutáveis: basta uma variável
                    # (em caixa se o método toma o endereço, ex. `c.inc()` com
                    # receptor ponteiro).
                    prologue.append(self.names.local_decl(ident, recv_t, "this"))
                else:
                    self.scope.recv = ident["$obj"]["decl"]
            name = member_name(d["name"]["name"])
            if self.typesys.is_value(recv_t):
                # Receptor valor sobre `(*T)(nil)`: o auto-deref do Go dá panic.
                prologue.insert(0, f"if ($nilPtr) {self.imports.qualify(None, 'nilDeref')}();")
        else:
            name = self.names.top_name(d["name"]["name"], "func", d["name"]["$obj"].get("fold"))
            if d["name"]["name"] == "init":
                # Várias por pacote, nunca referenciadas: chamadas por $goInit.
                name = f"_init${len(self.facts.init_funcs)}"
                self.facts.init_funcs.append(name)
        tps = self.type_params(d["type"]["typeParams"])
        tparams, dicts = tps.decl, ", ".join(tps.dicts)
        params, boxes = self.params(d["type"]["params"], sig)
        self.scope.rd = None
        rd = ""
        if has_recover(d["body"]) and not (name == "main" and not d["recv"]):
            self.scope.rd, rd = "$rd", self.rd_param()
        params = ", ".join(p for p in (dicts, params, rd) if p)
        head = f"{self.types.results(sig['results'])} {name}{tparams}({params})"
        body = self.func_body(d["type"], d["body"], sig)
        self.scope = None
        if name == "main" and not d["recv"]:
            # Panic não recuperado: mensagem no stderr e exit 2, como o Go.
            body = [f"{self.imports.qualify(None, 'runMain')}(() {{", "$goInit();"] + prologue + boxes + body + ["});"]
            prologue, boxes = [], []
        return doc_comment(d["doc"]) + [head + " {"] + prologue + boxes + body + ["}"]

    def rd_param(self):
        """Parâmetro oculto de quem chama recover(): a pilha de defers que a
        invocou diretamente (só o defer o passa)."""
        return f"{{{self.imports.qualify(None, 'Defers')}? $rd}}"

    def type_params(self, fields):
        """`[T C, U any]` → TypeParams: `<T extends Bound, U>` e um parâmetro
        dicionário `go.Elem<T> $T` por parâmetro (zero, tamanho, T(n))."""
        idents = [i for f in ((fields or {}).get("list") or []) for i in f["names"]]
        names, bounds, dicts = [], [], []
        for ident in idents:
            tp = self.pkg.type_at(ident["$obj"]["type"])
            names.append(tp["name"])
            bounds.append(self.bound(tp))
            dicts.append(f"{self.imports.qualify(None, 'Elem')}<{tp['name']}> ${tp['name']}")
        return TypeParams(tuple(names), tuple(bounds), tuple(dicts))

    def bound(self, tp):
        """Bound Dart da constraint de um parâmetro de tipo: interface com
        métodos → a interface; união de tipos → a base comum de fixed_types
        (IntBase, GoReal, GoOrdered, StringBase); any/comparable → nenhum."""
        core = self.typesys.underlying(tp)
        if core["kind"] in ("slice", "map", "array"):
            return self.types.dart(core).non_null()  # `S ~[]E` → go.Slice<E>
        c = self.pkg.type_at(tp["constraint"])
        u = self.typesys.underlying(c)
        if u["kind"] != "interface":
            return None
        terms = self.typesys.constraint_terms(u)
        if not terms:
            return self.types.dart(c).non_null() if u["methods"] else None
        cats = {self.typesys.basic(x).cat if self.typesys.basic(x) else None for x in terms}
        name = tp["name"]
        g = self.types.golang
        if cats <= {"wint"}:
            return f"{g('IntBase')}<{name}>"
        if cats <= {"wint", "float"}:
            return f"{g('GoReal')}<{name}>"
        if cats <= {"wint", "float", "string"}:
            return f"{g('GoOrdered')}<{name}>"
        if cats == {"string"}:
            return f"{g('StringBase')}<{name}>"
        if any(self.typesys.underlying(x)["kind"] == "pointer" for x in terms):
            return self.pointer_bound(u)
        # União mista (`bool | int64 | string`, `[]byte | string`) ou de
        # funcs: sem bound comum. O corpo só move e compara valores; operador
        # sobre T é recusado (`loose`), índice/len/range/chamada já recusam.
        return None

    def pointer_bound(self, u):
        """`P interface{ *T; M }`: P é o ponteiro, cujo objeto implementa a
        interface de métodos M embutida; ela é o bound."""
        ms = [et for et in (self.pkg.type_at(e) for e in u["embeddeds"])
              if et["kind"] == "named" and self.typesys.underlying(et)["kind"] == "interface"
              and self.typesys.underlying(et)["methods"]]
        if len(ms) == 1 and ({m["name"] for m in u["methods"]}
                             == {m["name"] for m in self.typesys.underlying(ms[0])["methods"]}):
            return self.types.dart(ms[0]).as_nullable()  # ponteiro: pode ser nil
        if not u["methods"]:
            return None
        raise Unsupported("constraint:ponteiro", "constraint com ponteiro e métodos próprios (sem interface Dart comum)")

    def pointer_tparam(self, t):
        """Parâmetro de tipo cujos termos são ponteiros (`P interface{ *T; M }`):
        o valor pode ser nil (bound anulável)."""
        if t is None or t["kind"] != "typeparam":
            return False
        c = self.typesys.underlying(self.pkg.type_at(t["constraint"]))
        return c["kind"] == "interface" and any(
            self.typesys.underlying(x)["kind"] == "pointer" for x in self.typesys.constraint_terms(c))

    def loose(self, t):
        """Parâmetro de tipo com termos na constraint mas sem bound Dart comum
        (união mista ou de funcs): operadores sobre ele não têm tradução."""
        if t is None or t["kind"] != "typeparam" or self.typesys.core(t) is not None:
            return False
        c = self.typesys.underlying(self.pkg.type_at(t["constraint"]))
        return c["kind"] == "interface" and bool(self.typesys.constraint_terms(c)) and self.bound(t) is None

    def params(self, fields, sig):
        """Lista de parâmetros Dart + prólogo (parâmetros com `&p` vão para
        uma caixa local)."""
        idents = [i for f in (fields["list"] or []) for i in (f["names"] or [None])]
        out, prologue = [], []
        for i, ident in enumerate(idents):
            t = self.pkg.type_at(sig["params"][i])
            if ident is None or ident["name"] == "_":
                name = "_"
            elif ident["$obj"]["decl"] in self.facts.boxed:
                name = self.names.temp()
                prologue.append(self.names.local_decl(ident, t, name))
            else:
                name = self.names.declare_local(ident)
            out.append(f"{self.types.dart(t)} {name}")
        return ", ".join(out), prologue

    def func_body(self, ftype, body, sig):
        """Corpo de função; resultados nomeados viram locais inicializados.
        Com `defer`: resultados sempre em variáveis (os defers podem alterá-los)
        e o corpo roda sob go.Defers (try/catch/finally). O estado da função
        externa volta mesmo se o corpo levantar (func literal aninhada)."""
        saved = self.scope.results, self.scope.sig, self.scope.defers, self.scope.breaks, self.scope.rangefuncs
        # Func literal: `return`/`break` lá dentro são dela, não de um range
        # sobre func que a contenha.
        self.scope.breaks, self.scope.rangefuncs = [], []
        try:
            return self._func_body(ftype, body, sig)
        finally:
            (self.scope.results, self.scope.sig, self.scope.defers,
             self.scope.breaks, self.scope.rangefuncs) = saved

    def _func_body(self, ftype, body, sig):
        out = []
        results = ftype["results"]
        named = results and results["list"] and results["list"][0]["names"]
        deferring = has_defer(body)
        # Resultado nomeado só vira local se algo o usa (o Go aceita nunca
        # lê-lo; o Dart acusaria local não usada).
        named = named and (deferring or has_bare_return(body) or any(
            uses_decl(body, ident["$obj"]["decl"]) for f in results["list"] for ident in f["names"]))
        self.scope.results, self.scope.sig, self.scope.defers = None, sig, None
        if deferring and not named and sig["results"]:
            self.scope.results = []
            for rt in sig["results"]:
                nm = self.names.temp()
                out.append(f"{self.types.dart(rt)} {nm} = {self.types.zero(rt)};")
                self.scope.results.append(nm)
        if named:
            self.scope.results = []
            for f in results["list"]:
                for ident in f["names"]:
                    obj = ident["$obj"]
                    t = self.pkg.type_at(obj["type"])
                    if ident["name"] == "_":
                        nm = self.names.temp()
                        out.append(f"{self.types.dart(t)} {nm} = {self.types.zero(t)};")
                    else:
                        out.append(self.names.local_decl(ident, t, self.types.zero(t)))
                        nm = self.scope.locals[obj["decl"]] + self.names.box_suffix(obj)
                    self.scope.results.append(nm)
        if deferring:
            d = self.scope.defers = self.names.temp()
        stmts = [ln for s in body["list"] or [] for ln in self.stmt(s)]
        if deferring:
            e, st = self.names.temp(), self.names.temp()
            finish = [f"return {tuple_expr(self.scope.results)};"] if self.scope.results else []
            out += [f"final {d} = {self.imports.qualify(None, 'Defers')}();", "try {"] + stmts + [
                f"}} catch ({e}, {st}) {{", f"{d}.fail({e}, {st});", "} finally {", f"{d}.run();"
            ] + finish + ["}"]
        else:
            out += stmts
        return out
