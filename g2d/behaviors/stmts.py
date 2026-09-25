"""Um comportamento por statement Go."""

from g2d.analysis.helpers import is_blank, tuple_expr, uses_decl
from g2d.engine.behavior import StmtBehavior
from g2d.engine.precedence import DART_PREC, POSTFIX
from g2d.model import Unsupported


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
        if d["tok"] not in ("var", "const"):
            raise Unsupported(f"declaração local {d['tok']}", s)
        return [ln for spec in d["specs"] for ln in self.vars.value_spec(spec, d["tok"])]


class ReturnStmt(StmtBehavior):
    kinds = ("ReturnStmt",)

    def emit(self, s):
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
        elif rhs[0]["node"] == "TypeAssertExpr":  # v, ok := x.(T)
            value = self.asserts.comma_ok_assert(rhs[0])
        elif self.operands.is_map_index(rhs[0]):  # v, ok := m[k]
            r = rhs[0]
            value = f"{self.expr(r['x'], POSTFIX)}.lookup({self.expr(r['index'])})"
        else:
            value = self.expr(rhs[0])  # 1 chamada com N resultados
        # Alvos struct já existentes precisam de $set: caminho do temporário.
        # ... e variáveis em caixa (`x.value` não é padrão de atribuição).
        idents = all(x["node"] == "Ident" for x in lhs) and not any(
            (self.typesys.is_value(self.pkg.type_of(x)) and not (tok == ":=" and x["$obj"].get("def")))
            or x["$obj"].get("decl") in self.facts.boxed
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
        if self.operands.is_map_index(lhs):
            if op in ("/", "%", "&^", "<<", ">>"):
                raise Unsupported(f"{op}= sobre índice de map", lhs)
            p = DART_PREC[op]
            return f"{self.operands.lvalue(lhs)} = ({self.expr(lhs)}) {op} {self.expr(rhs, p + 1)};"
        if op in ("<<", ">>"):
            return f"{self.operands.lvalue(lhs)} {op}= {self.operands.shift_count(rhs)};"
        if b and b.integer and op == "/":
            return f"{self.operands.lvalue(lhs)} ~/= {self.expr(rhs)};"
        if op == "&^":
            if lhs["node"] != "Ident":
                raise Unsupported("&^= sobre expressão não-identificador", lhs)
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
        out = [f"if ({self.expr(s['cond'])})"] + self.block(s["body"])
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
        cond = self.expr(s["cond"]) if s["cond"] else ""
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
            raise Unsupported("cláusula de for com múltiplas atribuições", s)
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
        if u["kind"] == "basic":
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
        else:
            raise Unsupported(f"range sobre {u['kind']}", s)
        body = self.control.loop_body(s["body"])
        head[-1] = label + head[-1]
        return ["{"] + head + ["{"] + pre + body + ["}", "}"]


class BranchStmt(StmtBehavior):
    kinds = ("BranchStmt",)

    def emit(self, s):
        tok = s["tok"]
        if tok not in ("break", "continue"):
            raise Unsupported(tok, s)
        if s["label"]:
            return [f"{tok} {s['label']['name']};"]
        target = self.scope.breaks[-1] if tok == "break" and self.scope.breaks else None
        if target:  # break sem rótulo dentro de switch: sai só do switch
            self.scope.used_labels.add(target)
            return [f"break {target};"]
        return [f"{tok};"]


class LabeledStmt(StmtBehavior):
    kinds = ("LabeledStmt",)

    def emit(self, s):
        label = s["label"]["name"] + ":"
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
                f"{tag} == {self.expr(e, DART_PREC['=='] + 1)}" if tag else self.expr(e, DART_PREC["||"] + 1)
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
        decl = f"{ident['namePos']['file']}:{ident['namePos']['offset']}" if ident else None
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
                        value, vt = f"{self.imports.qualify(None, 'unNil')}<{dt.rstrip('?')}>({subject} as {dt})", t
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
        if fun.get("$builtin"):
            raise Unsupported("defer de builtin", s)
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
        if self.calls.known_recoverer(fun):
            # Chamada direta de quem chama recover(): repassa o frame.
            text = self.expr(dict(call, fun=callee_node, args=fixed, **{"$rdArg": d}))
        elif not self.calls.declared_func(fun):
            # Valor de função: só em runtime se sabe se aceita `$rd`.
            tmp = self.names.temp()
            pre.append(f"final {tmp} = {self.expr(callee_node)};")
            fnode = {"node": "G2DTemp", "text": tmp, "$type": fun.get("$type")}
            plain = self.expr(dict(call, fun=fnode, args=fixed))
            with_rd = self.expr(dict(call, fun=fnode, args=fixed, **{"$rdArg": d}))
            ftype = self.types.func_type(self.pkg.type_of(fun))
            ftype = ftype[:-1] + (", " if not ftype.endswith("()") else "") + self.functions.rd_param() + ")"
            text = f"if ({tmp} is {ftype}) {{ {with_rd}; }} else {{ {plain}; }}"
            return ["{"] + pre + [f"{d}.defer(() {{ {text} }});", "}"]
        else:
            text = self.expr(dict(call, fun=callee_node, args=fixed))
        return ["{"] + pre + [f"{d}.defer(() {{ {text}; }});", "}"]
