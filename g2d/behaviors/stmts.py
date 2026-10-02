"""Um comportamento por statement Go."""

from g2d.engine.behavior import StmtBehavior
from g2d.engine.precedence import DART_PREC, POSTFIX
from g2d.model import Unsupported, is_blank, pos_key, uses_decl
from g2d.services.control import RangeFuncFrame
from g2d.services.dart_type import DartType
from g2d.services.literals import tuple_expr


class BlockStmt(StmtBehavior):
    kinds = ("BlockStmt",)

    def emit(self, s):
        return self.block(s)


class ExprStmt(StmtBehavior):
    kinds = ("ExprStmt",)

    def emit(self, s):
        return [self.expr(s["x"]) + ";"]


class EmptyStmt(StmtBehavior):
    kinds = ("EmptyStmt",)

    def emit(self, s):
        return []


class IncDecStmt(StmtBehavior):
    kinds = ("IncDecStmt",)

    def emit(self, s):
        op = s["tok"][0]
        one = self.literals.literal({"kind": "int", "value": "1"}, self.pkg.type_of(s["x"]))
        if self.operands.is_map_index(s["x"]):
            return [f"{self.operands.lvalue(s['x'])} = ({self.expr(s['x'])}) {op} {one};"]
        if one != "1":  # wrapper: `x += T(1)` avalia o alvo uma vez só
            return [f"{self.operands.lvalue(s['x'])} {op}= {one};"]
        return [self.operands.lvalue(s["x"]) + s["tok"] + ";"]


class DeclStmt(StmtBehavior):
    kinds = ("DeclStmt",)

    def emit(self, s):
        d = s["decl"]
        if d["tok"] == "type":
            return []  # içado para a library (LocalTypesAnalysis)
        if d["tok"] == "const":
            return []  # cada uso já é o literal exato do go/types
        if d["tok"] not in ("var", "const"):
            raise Unsupported(f"decl-local:{d['tok']}", f"declaração local {d['tok']}", s)
        return [ln for spec in d["specs"] for ln in self.vars.value_spec(spec, d["tok"])]


class ReturnStmt(StmtBehavior):
    kinds = ("ReturnStmt",)

    def emit(self, s):
        if self.scope.rangefuncs:
            return self.from_range_func(s, self.scope.rangefuncs[-1])
        res = s["results"] or []
        if not res:
            if self.scope.results:
                return [f"return {tuple_expr(self.scope.results)};"]
            return ["return;"]
        rtypes = self.scope.sig["results"]
        if len(res) != len(rtypes):  # return f() com múltiplos resultados
            values = [self.expr(res[0])]
        else:
            values = [self.values.coerce(r, self.pkg.type_at(t)) for r, t in zip(res, rtypes)]
        if not self.scope.defers:
            return [f"return {tuple_expr(values)};"]
        # Com defer: `return x` atribui aos resultados; os defers rodam no
        # finally, que devolve os resultados (possivelmente alterados).
        names = self.scope.results
        if len(values) == 1 and len(names) > 1:
            tmp = self.names.temp()
            out = [f"final {tmp} = {values[0]};"]
            out += [f"{nm} = {tmp}.${i + 1};" for i, nm in enumerate(names)]
        else:
            out = [f"{nm} = {v};" for nm, v in zip(names, values)]
        return ["{"] + out + [f"return {tuple_expr(names)};", "}"]


    def from_range_func(self, s, frame):
        """`return` dentro de range sobre func: guarda os valores e sai da
        closure; o `return` de verdade é refeito depois da chamada."""
        res = s["results"] or []
        if not res:
            code = frame.exit(s)
            return [f"{frame.state} = {code};", f"{frame.done} = true;", "return false;"]
        rtypes = [self.pkg.type_at(t) for t in self.scope.sig["results"]]
        if len(res) != len(rtypes):
            value = self.expr(res[0])  # return f() com vários resultados
        else:
            value = tuple_expr([self.values.coerce(r, t) for r, t in zip(res, rtypes)])
        dt = tuple_expr([str(self.types.dart(t)) for t in rtypes]) if len(rtypes) > 1 else str(self.types.dart(rtypes[0]))
        if len(rtypes) > 1:
            temps = [{"node": "G2DTemp", "text": f"({frame.rv} as {dt}).${i + 1}", "$type": t}
                     for i, t in enumerate(self.scope.sig["results"])]
        else:
            temps = [{"node": "G2DTemp", "text": f"({frame.rv} as {dt})", "$type": self.scope.sig["results"][0]}]
        code = frame.exit(dict(s, results=temps))
        return [f"{frame.rv} = {value};", f"{frame.state} = {code};", f"{frame.done} = true;", "return false;"]


class AssignStmt(StmtBehavior):
    kinds = ("AssignStmt",)

    def emit(self, s):
        lhs, rhs, tok = s["lhs"], s["rhs"], s["tok"]
        if tok not in ("=", ":="):
            return [self.op_assign(lhs[0], tok[:-1], rhs[0])]
        if len(lhs) == 1:
            if lhs[0]["node"] == "Ident" and lhs[0]["name"] == "_":
                return [self.expr(rhs[0]) + ";"]
            if tok == ":=":
                t = self.pkg.type_at(lhs[0]["$obj"]["type"])
                return [self.names.local_decl(lhs[0], t, self.values.coerce(rhs[0], t))]
            return [self.values.assign(lhs[0], rhs[0])]

        if len(rhs) == len(lhs):
            value = tuple_expr([self.values.coerce(r, self.pkg.type_of(x)) for r, x in zip(rhs, lhs)])
        else:  # v, ok := x.(T) / m[k], ou 1 chamada com N resultados
            value = self.operands.multi_value(rhs[0])
        # Alvos struct já existentes precisam de $set: caminho do temporário.
        # ... e variáveis em caixa (`x.value` não é padrão de atribuição).
        idents = all(x["node"] == "Ident" for x in lhs) and not any(
            (self.typesys.is_value(self.pkg.type_of(x)) and not (tok == ":=" and x["$obj"].get("def")))
            or self.names.boxed(x["$obj"])
            for x in lhs if not is_blank(x))
        news = [None if is_blank(x) else tok == ":=" and x["node"] == "Ident" and x["$obj"].get("def", False)
                for x in lhs]
        if idents and all(n is not False for n in news) and any(news):
            names = [self.names.declare_local(x) if n else "_" for x, n in zip(lhs, news)]
            return [f"var ({', '.join(names)}) = {value};"]
        if idents and not any(news):
            names = ["_" if is_blank(x) else self.expr(x) for x in lhs]
            return [f"({', '.join(names)}) = {value};"]
        tmp = self.names.temp()
        out = [f"final {tmp} = {value};"]
        for i, (x, new) in enumerate(zip(lhs, news)):
            if new is None:
                continue
            if new:
                out.append(self.names.local_decl(x, self.pkg.type_at(x["$obj"]["type"]), f"{tmp}.${i + 1}"))
            elif self.typesys.is_value(self.pkg.type_of(x)) and not self.operands.is_map_index(x):
                out.append(f"{self.expr(x, POSTFIX)}.$set({tmp}.${i + 1});")
            else:
                out.append(f"{self.operands.lvalue(x)} = {tmp}.${i + 1};")
        return out

    def op_assign(self, lhs, op, rhs):
        b = self.typesys.basic(self.pkg.type_of(lhs))
        # Sem operador composto Dart equivalente: lê e escreve o alvo (map
        # guarda sem `??`; `&^` é o método andNot).
        if self.operands.is_map_index(lhs) or (op == "&^" and lhs["node"] != "Ident"):
            if not self.operands.is_pure(lhs):
                raise Unsupported("opassign-impuro", f"{op}= sobre alvo com efeito (avaliado duas vezes)", lhs)
            read = self.expr(lhs, POSTFIX)
            if op == "&^":
                value = f"{read}.andNot({self.expr(rhs)})"
            elif op in ("<<", ">>"):
                value = f"{read} {op} {self.operands.shift_count(rhs)}"
            elif b and b.integer and op == "/":
                value = f"{read} ~/ {self.expr(rhs, DART_PREC['~/'] + 1)}"
            else:
                value = f"{read} {op} {self.expr(rhs, DART_PREC[op] + 1)}"
            return f"{self.operands.lvalue(lhs)} = {value};"
        if op in ("<<", ">>"):
            return f"{self.operands.lvalue(lhs)} {op}= {self.operands.shift_count(rhs)};"
        if b and b.integer and op == "/":
            return f"{self.operands.lvalue(lhs)} ~/= {self.expr(rhs)};"
        if op == "&^":
            x = self.expr(lhs)
            return f"{x} = {x}.andNot({self.expr(rhs)});"
        return f"{self.operands.lvalue(lhs)} {op}= {self.expr(rhs)};"


class IfStmt(StmtBehavior):
    kinds = ("IfStmt",)

    def emit(self, s):
        if s["init"]:
            init = self.stmt(s["init"])  # declara antes de emitir a condição
            return ["{"] + init + self.if_chain(s) + ["}"]
        return self.if_chain(s)

    def if_chain(self, s):
        out = [f"if ({self.operands.cond(s['cond'])})"] + self.block(s["body"])
        e = s["else"]
        if e is None:
            return out
        if e["node"] == "IfStmt" and not e["init"]:
            return out + ["else"] + self.if_chain(e)
        return out + ["else"] + self.stmt(e)


class ForStmt(StmtBehavior):
    kinds = ("ForStmt",)

    def emit(self, s):
        init = self.simple(s["init"])  # antes da condição: declara a variável
        cond = self.operands.cond(s["cond"]) if s["cond"] else ""
        post = self.simple(s["post"])
        body = self.control.loop_body(s["body"])
        if not s["init"] and not s["post"]:
            return [f"while ({cond or 'true'})"] + body
        return [f"for ({init}; {cond}; {post})"] + body

    def simple(self, s):
        """Statement simples numa única linha, sem `;` (cláusulas do for)."""
        if s is None:
            return ""
        lines = self.stmt(s)
        if len(lines) != 1:
            raise Unsupported("for-multi-atribuicao", "cláusula de for com múltiplas atribuições", s)
        return lines[0].rstrip(";")


class RangeStmt(StmtBehavior):
    kinds = ("RangeStmt",)

    def emit(self, s, label=""):
        x = s["x"]
        u = self.typesys.underlying(self.pkg.type_of(x))
        key, val = s["key"], s["value"]
        define = s["tok"] == ":="
        if key is not None and key["node"] == "Ident" and key["name"] == "_":
            key = None
        if val is not None and val["node"] == "Ident" and val["name"] == "_":
            val = None

        def bind(target, value):
            if define:
                return self.names.local_decl(target, self.pkg.type_at(target["$obj"]["type"]), value)
            return f"{self.operands.lvalue(target)} = {value};"

        src = self.names.temp()
        if u["kind"] == "basic" and self.typesys.basic(u).cat == "string":
            # Runas decodificadas como no Go: U+FFFD largura 1 se inválido.
            i, r, w = self.names.temp(), self.names.temp(), self.names.temp()
            s_text = self.expr(x, POSTFIX) + (".$str" if self.pkg.type_of(x)["kind"] == "named" else "")
            head = [f"final {src} = {s_text};", f"for (var {i} = 0, {w} = 0; {i} < {src}.length; {i} += {w})"]
            pre = [f"final {r} = {src}.decodeRune({i});", f"{w} = {r}.$2;"]
            pre += ([bind(key, self.operands.from_int(i, self.pkg.type_at(key["$obj"]["type"])))] if key else []) + (
                [bind(val, f"{self.types.golang('Rune')}({r}.$1)")] if val else [])
        elif u["kind"] == "basic":
            i = self.names.temp()
            head = [f"final {src} = {self.operands.to_int(x)};", f"for (var {i} = 0; {i} < {src}; {i}++)"]
            pre = [bind(key, self.operands.from_int(i, self.pkg.type_of(x)))] if key else []
        elif u["kind"] in ("slice", "array"):
            i = self.names.temp()
            rng = self.values.copy_text(self.expr(x, POSTFIX), self.pkg.type_of(x)) if val else self.expr(x)
            head = [f"final {src} = {rng};", f"for (var {i} = 0; {i} < {src}.length; {i}++)"]
            key_t = self.pkg.type_of(key) if key else None
            elem_t = self.pkg.type_at(u["elem"])
            pre = ([bind(key, self.operands.from_int(i, key_t))] if key else []) + (
                [bind(val, self.values.copy_text(f"{src}[{i}]", elem_t))] if val else [])
        elif u["kind"] == "map":
            k = self.names.temp()
            # Go permite deletar durante o range; iterar sobre cópia das chaves
            # e pular as removidas preserva a semântica.
            head = [f"final {src} = {self.expr(x)};", f"for (final {k} in {src}.keysSnapshot())"]
            pre = [f"if (!{src}.containsKey({k})) continue;"]
            elem_t = self.pkg.type_at(u["elem"])
            pre += ([bind(key, k)] if key else []) + (
                [bind(val, self.values.copy_text(f"{src}[{k}]", elem_t))] if val else [])
        elif u["kind"] == "func":
            return self.range_func(s, x, u, key, val, bind, label)
        elif u["kind"] == "chan":
            # `for v := range ch`: recebe até o canal fechar (chanRecv2);
            # sem segunda variável (Go só dá o elemento).
            self.concurrency.require_async(s, "range sobre canal")
            t = self.names.temp()
            recv2 = self.imports.qualify(None, "chanRecv2")
            head = [f"final {src} = {self.expr(x)};", "while (true)"]
            pre = [f"final {t} = await {recv2}({src});", f"if (!{t}.$2) break;"]
            pre += [bind(key, f"{t}.$1")] if key else []
        else:
            raise Unsupported(f"range:{u['kind']}", f"range sobre {u['kind']}", s)
        body = self.control.loop_body(s["body"])
        head[-1] = label + head[-1]
        return ["{"] + head + ["{"] + pre + body + ["}", "}"]


    def range_func(self, s, x, u, key, val, bind, label):
        """`for k, v := range seq`: `seq((k, v) { corpo; return true; })`.
        Saídas da closure voltam como código em `$st` e são refeitas fora."""
        yield_t = self.typesys.underlying(self.pkg.type_at(u["params"][0]))
        params = [self.pkg.type_at(p) for p in yield_t["params"]]
        frame = RangeFuncFrame(label[:-1] if label else None, self.names.temp(), self.names.temp(), self.names.temp())
        names = [self.names.temp() for _ in params]
        pre = []
        for target, name in zip((key, val), names):
            if target is not None:
                pre.append(bind(target, name))
        self.scope.rangefuncs.append(frame)
        self.scope.breaks.append(frame)
        try:
            body = [ln for st in s["body"]["list"] or [] for ln in self.stmt(st)]
        finally:
            self.scope.breaks.pop()
            self.scope.rangefuncs.pop()
        seq_t = self.pkg.type_of(x)
        seq = self.expr(x, POSTFIX) + ("!" if self.types.nilable(seq_t) else "")
        panic = self.imports.qualify(None, "rangeFuncContinued")
        head = ", ".join(f"{self.types.dart(t)} {n}" for t, n in zip(params, names))
        out = ["{", f"var {frame.state} = 0;", f"var {frame.done} = false;", f"Object? {frame.rv};",
               f"{seq}(({head}) {{", f"if ({frame.done}) {panic}();"] + pre + body + ["return true;", "});"]
        # O corpo terminou e o iterador seguiu chamando yield: pânico do Go.
        for code, node in frame.exits:
            out += [f"if ({frame.state} == {code})"] + ["{"] + self.stmt(node) + ["}"]
        return out + ["}"]


class BranchStmt(StmtBehavior):
    kinds = ("BranchStmt",)

    def emit(self, s):
        tok = s["tok"]
        if tok not in ("break", "continue"):
            raise Unsupported(f"branch:{tok}", tok, s)
        frame = self.scope.rangefuncs[-1] if self.scope.rangefuncs else None
        if s["label"]:
            name = s["label"]["name"]
            if frame is None or name in frame.inner_labels:
                return [f"{tok} {name};"]
            if name == frame.label:  # o próprio range sobre func
                return self.leave(frame, tok)
            return self.escape(frame, s)  # laço de fora da closure
        if tok == "break":
            target = self.scope.breaks[-1] if self.scope.breaks else None
        else:  # continue: o laço mais interno (switch não conta)
            target = next((b for b in reversed(self.scope.breaks) if not isinstance(b, str)), None)
        if isinstance(target, RangeFuncFrame):
            return self.leave(target, tok)
        if target:  # break sem rótulo dentro de switch: sai só do switch
            self.scope.used_labels.add(target)
            return [f"break {target};"]
        return [f"{tok};"]

    def leave(self, frame, tok):
        """break/continue do próprio range sobre func: a closure devolve."""
        if tok == "continue":
            return ["return true;"]
        return [f"{frame.done} = true;", "return false;"]

    def escape(self, frame, node):
        """Saída para fora da closure: código em `$st`, refeita depois."""
        code = frame.exit(node)
        return [f"{frame.state} = {code};", f"{frame.done} = true;", "return false;"]


class LabeledStmt(StmtBehavior):
    kinds = ("LabeledStmt",)

    def emit(self, s):
        label = s["label"]["name"] + ":"
        if self.scope.rangefuncs:  # rótulo declarado dentro do corpo: nativo
            self.scope.rangefuncs[-1].inner_labels.add(s["label"]["name"])
        if s["stmt"]["node"] == "RangeStmt":  # rótulo vai no laço, não no bloco
            return self.stmt(s["stmt"], label=label)
        return [label] + self.stmt(s["stmt"])


class SwitchStmt(StmtBehavior):
    kinds = ("SwitchStmt",)

    def emit(self, s):
        """switch → cadeia if/else (cases Go aceitam expressões arbitrárias).
        Com `fallthrough`: seleção do case + corpos em sequência. `break`
        sai do bloco rotulado do switch."""
        label = self.control.switch_label()
        out = ["{"] + (self.stmt(s["init"]) if s["init"] else [])
        tag = None
        if s["tag"]:
            tag = self.names.temp()
            out.append(f"final {tag} = {self.expr(s['tag'])};")
        clauses = s["body"]["list"]

        def cond(clause):
            return " || ".join(
                f"{tag} == {self.expr(e, DART_PREC['=='] + 1)}" if tag else self.operands.cond(e, DART_PREC["||"] + 1)
                for e in clause["list"])

        def falls(clause):
            body = clause["body"] or []
            return bool(body) and body[-1]["node"] == "BranchStmt" and body[-1]["tok"] == "fallthrough"

        if any(falls(c) for c in clauses):
            sel = self.names.temp()
            out.append(f"var {sel} = -1;")
            default = next((i for i, c in enumerate(clauses) if c["list"] is None), None)
            chain = [(i, cond(c)) for i, c in enumerate(clauses) if c["list"] is not None]
            for k, (i, cnd) in enumerate(chain):
                out += [("else " if k else "") + f"if ({cnd})", "{", f"{sel} = {i};", "}"]
            if default is not None:
                out += (["else"] if chain else []) + ["{", f"{sel} = {default};", "}"]
            for i, c in enumerate(clauses):
                body = c["body"] or []
                lines = [ln for st in (body[:-1] if falls(c) else body) for ln in self.stmt(st)]
                if falls(c):
                    lines.append(f"{sel} = {i + 1};")  # fallthrough: próximo case do fonte
                out += [f"if ({sel} == {i})", "{"] + lines + ["}"]
            return self.control.close_switch(label, out + ["}"])

        chain, default = [], None
        for clause in clauses:
            lines = ["{"] + [ln for b in clause["body"] or [] for ln in self.stmt(b)] + ["}"]
            if clause["list"] is None:
                default = lines
                continue
            chain.append((cond(clause), lines))
        for i, (cnd, lines) in enumerate(chain):
            out += [("else " if i else "") + f"if ({cnd})"] + lines
        if default:
            out += (["else"] if chain else []) + default
        return self.control.close_switch(label, out + ["}"])


class TypeSwitchStmt(StmtBehavior):
    kinds = ("TypeSwitchStmt",)

    def emit(self, s):
        """type switch → cadeia de testes `is`, com a variável do case
        ligada ao tipo do case (um tipo) ou ao da interface (vários/default)."""
        guard = s["assign"]
        if guard["node"] == "AssignStmt":
            ident, ta = guard["lhs"][0], guard["rhs"][0]
        else:
            ident, ta = None, guard["x"]
        label = self.control.switch_label()
        out = ["{"] + (self.stmt(s["init"]) if s["init"] else [])
        subject = self.names.temp()
        static_t = self.pkg.type_of(ta["x"])
        out.append(f"final {subject} = {self.expr(ta['x'])};")
        decl = pos_key(ident["namePos"]) if ident else None
        chain, default = [], None
        for clause in s["body"]["list"]:
            body = clause["body"] or []
            bind = []
            if ident is not None and uses_decl(body, decl):
                types = clause["list"] or []
                single = len(types) == 1 and not (types[0]["node"] == "Ident" and types[0]["name"] == "nil")
                if single:
                    mode, dt, t = self.asserts.assert_parts({"type": types[0]})
                    if mode == "value":
                        value, vt = f"({subject} as {dt}).$copy()", t
                    elif mode == "pointer":
                        value, vt = f"{self.imports.qualify(None, 'unNil')}<{dt.non_null()}>({subject} as {dt})", t
                    elif mode == "func":
                        # `type_test` já confirmou o tipo (case único, exato
                        # via `go.Func` ou, sem wrapper, por subtipo do Dart).
                        value, vt = f"{self.imports.qualify(None, 'unwrapFunc')}<{dt}>({subject})", t
                    else:
                        value, vt = f"{subject} as {dt}", t
                    vtype = self.types.dart(vt)
                else:
                    value, vtype = subject, self.types.dart(static_t)
                obj = {"name": ident["name"], "decl": decl}
                name = self.names.declare_local({"$obj": obj})
                bind = [f"final {vtype} {name} = {value};"]
            lines = ["{"] + bind + [ln for b in body for ln in self.stmt(b)] + ["}"]
            if clause["list"] is None:
                default = lines
                continue
            chain.append((" || ".join(self.asserts.type_test(subject, e) for e in clause["list"]), lines))
        for i, (cond, lines) in enumerate(chain):
            out += [("else " if i else "") + f"if ({cond})"] + lines
        if default:
            out += (["else"] if chain else []) + default
        return self.control.close_switch(label, out + ["}"])


class DeferStmt(StmtBehavior):
    kinds = ("DeferStmt",)

    def emit(self, s):
        """`defer f(args)`: função e argumentos avaliados agora; a chamada fica
        na pilha go.Defers da função."""
        call = s["call"]
        fun, args = call["fun"], call["args"] or []
        pre = []
        if fun.get("$builtin") and fun.get("name") == "recover":
            # `defer recover()` não recupera no Go (recover não é chamado por
            # uma função adiada); raro demais para modelar.
            raise Unsupported("defer-recover", "defer recover()", s)
        # Avalia os argumentos agora, fixando-os em temporários.
        fixed = []
        for a in args:
            if a.get("$value") is not None:
                fixed.append(a)
                continue
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.values.coerce(a, self.pkg.type_of(a))};")
            fixed.append({"node": "G2DTemp", "text": tmp, "$type": a.get("$type")})
        callee_node = fun
        if fun["node"] == "SelectorExpr" and fun.get("$sel", {}).get("kind") == "method":
            recv = fun["x"]
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(recv)};")
            callee_node = dict(fun, x={"node": "G2DTemp", "text": tmp, "$type": recv.get("$type")})
        elif fun["node"] not in ("FuncLit", "Ident", "SelectorExpr"):
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(fun)};")
            callee_node = {"node": "G2DTemp", "text": tmp, "$type": fun.get("$type")}
        d = self.scope.defers
        # Callee que suspende: a closure adiada é `async` (o `runAsync` da
        # função, que a cor também fez `async`, espera por ela).
        kw = " async" if self.concurrency.awaits(call) else ""
        if fun.get("$builtin"):  # delete, panic, print...: sem `$rd`
            text = self.expr(dict(call, args=fixed))
            return ["{"] + pre + [f"{d}.defer(() {{ {text}; }});", "}"]
        if self.calls.known_recoverer(fun):
            # Chamada direta de quem chama recover(): repassa o frame.
            text = self.expr(dict(call, fun=callee_node, args=fixed, **{"$rdArg": d}))
        elif not self.calls.declared_func(fun):
            # Valor de função: só em runtime se sabe se aceita `$rd`.
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(callee_node)};")
            sig, fn = fun.get("$type"), tmp
            while self.pkg.type_at(sig)["kind"] == "named":  # assinatura do subjacente
                sig = self.pkg.type_at(sig)["underlying"]
            if self.typesys.named_func(self.pkg.type_of(fun)):
                # Func nomeado é uma classe: o closure (talvez com `$rd`) fica em `$f`.
                fn = self.names.temp()
                pre.append(f"final {fn} = {tmp}.$f;")  # local: o `is` promove
            fnode = {"node": "G2DTemp", "text": fn, "$type": sig}
            plain = self.expr(dict(call, fun=fnode, args=fixed))
            with_rd = self.expr(dict(call, fun=fnode, args=fixed, **{"$rdArg": d}))
            defers = DartType(self.imports.qualify(None, "Defers"), nullable=True)
            ftype = self.types.func_type(self.pkg.type_at(sig)).with_named("$rd", defers)
            text = f"if ({fn} is {ftype}) {{ {with_rd}; }} else {{ {plain}; }}"
            return ["{"] + pre + [f"{d}.defer((){kw} {{ {text} }});", "}"]
        else:
            text = self.expr(dict(call, fun=callee_node, args=fixed))
        return ["{"] + pre + [f"{d}.defer((){kw} {{ {text}; }});", "}"]


class SendStmt(StmtBehavior):
    kinds = ("SendStmt",)

    def emit(self, s):
        """`ch <- v`: valor avaliado/copiado (struct) na hora, envio suspende
        (go.chanSend; canal nil bloqueia pra sempre)."""
        elem = self.pkg.type_at(self.typesys.underlying(self.pkg.type_of(s["chan"]))["elem"])
        self.concurrency.require_async(s, "envio em canal")
        ch, v = self.expr(s["chan"]), self.values.coerce(s["value"], elem)
        send = self.imports.qualify(None, "chanSend")
        return [f"await {send}({ch}, {v});"]


class GoStmt(StmtBehavior):
    kinds = ("GoStmt",)

    def emit(self, s):
        """`go f(args)`: função e argumentos avaliados na hora (mesma regra
        do `defer`); go.spawn nunca chama o corpo na hora — sempre agenda."""
        call = s["call"]
        fun, args = call["fun"], call["args"] or []
        if fun.get("$builtin"):
            raise Unsupported(f"go:builtin:{fun.get('name')}", f"go de builtin {fun.get('name')}", s)
        pre, fixed = [], []
        for a in args:
            if a.get("$value") is not None:
                fixed.append(a)
                continue
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.values.coerce(a, self.pkg.type_of(a))};")
            fixed.append({"node": "G2DTemp", "text": tmp, "$type": a.get("$type")})
        callee_node = fun
        if fun["node"] == "SelectorExpr" and fun.get("$sel", {}).get("kind") == "method":
            recv = fun["x"]
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(recv)};")
            callee_node = dict(fun, x={"node": "G2DTemp", "text": tmp, "$type": recv.get("$type")})
        elif not self.calls.declared_func(fun):
            # Valor de função (variável, campo, índice...): o Go fixa o
            # valor no início do `go`, antes de agendar.
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(fun)};")
            callee_node = {"node": "G2DTemp", "text": tmp, "$type": fun.get("$type")}
        # Sem `await`: o go.spawn aceita a goroutine de qualquer cor.
        text = self.expr(dict(call, fun=callee_node, args=fixed, **{"$awaited": True}))
        spawn = self.imports.qualify(None, "spawn")
        return ["{"] + pre + [f"{spawn}(() => {text});", "}"]


class SelectStmt(StmtBehavior):
    kinds = ("SelectStmt",)

    def emit(self, s):
        """`select`: canais e valores de envio avaliados uma vez, em ordem
        (a lista literal do Dart já garante isso). `go.selectNow` com
        `default` (nunca suspende); `await go.select` sem `default`
        (bloqueia). `break` sem rótulo sai do select (como do switch)."""
        clauses = s["body"]["list"] or []
        real = [c for c in clauses if c["comm"] is not None]
        default = next((c for c in clauses if c["comm"] is None), None)
        label = self.control.switch_label()
        recv_cls, send_cls = self.imports.qualify(None, "RecvCase"), self.imports.qualify(None, "SendCase")
        items, elems = [], []
        for c in real:
            comm = c["comm"]
            if comm["node"] == "SendStmt":
                elem = self.pkg.type_at(self.typesys.underlying(self.pkg.type_of(comm["chan"]))["elem"])
                items.append(f"{send_cls}({self.expr(comm['chan'])}, {self.values.coerce(comm['value'], elem)})")
            elif comm["node"] in ("ExprStmt", "AssignStmt"):
                unary = comm["rhs"][0] if comm["node"] == "AssignStmt" else comm["x"]
                if unary["node"] != "UnaryExpr" or unary["op"] != "<-":
                    raise Unsupported("select:comm", "case de select sem operação de canal", c)
                chan_node = unary["x"]
                elem = self.pkg.type_at(self.typesys.underlying(self.pkg.type_of(chan_node))["elem"])
                items.append(f"{recv_cls}({self.expr(chan_node)})")
            else:
                raise Unsupported("select:comm", f"case de select {comm['node']}", c)
            elems.append(elem)
        cases_t = self.imports.qualify(None, "SelectCase")
        cases = self.names.temp()
        out = ["{", f"final {cases} = <{cases_t}>[{', '.join(items)}];"]
        result = self.names.temp()
        if default is not None:
            out.append(f"final {result} = {self.imports.qualify(None, 'selectNow')}({cases});")
        else:
            self.concurrency.require_async(s, "select sem default")
            out.append(f"final {result} = await {self.imports.qualify(None, 'select')}({cases});")
        sel = self.names.temp()
        out.append(f"final {sel} = {result}.$1;")
        chain = []
        for i, (c, elem) in enumerate(zip(real, elems)):
            comm = c["comm"]
            bind = []
            if comm["node"] == "AssignStmt":
                lhs, define = comm["lhs"], comm["tok"] == ":="
                v = lhs[0]
                if not is_blank(v):
                    val = f"({result}.$2 as {self.types.dart(elem)})"
                    bind.append(self.names.local_decl(v, elem, val) if define
                                else f"{self.operands.lvalue(v)} = {val};")
                if len(lhs) > 1 and not is_blank(lhs[1]):
                    ok, okv = lhs[1], f"{result}.$3"
                    bool_t = self.pkg.type_at(ok["$obj"]["type"]) if define else None
                    bind.append(self.names.local_decl(ok, bool_t, okv) if define
                                else f"{self.operands.lvalue(ok)} = {okv};")
            body = ["{"] + bind + [ln for st in c["body"] or [] for ln in self.stmt(st)] + ["}"]
            chain.append((f"{sel} == {i}", body))
        for i, (cond, body) in enumerate(chain):
            if default is None and i == len(chain) - 1 and i:
                # Sem default o índice é sempre um dos cases: o último é o
                # `else` (o select é um statement terminal, como no Go).
                out += ["else"] + body
            else:
                out += [("else " if i else "") + f"if ({cond})"] + body
        if default is not None:
            body = ["{"] + [ln for st in default["body"] or [] for ln in self.stmt(st)] + ["}"]
            out += (["else"] if chain else []) + body
        return self.control.close_switch(label, out + ["}"])
