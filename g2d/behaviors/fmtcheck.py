"""Recusa na transpilação o que o shim `fmt` não formata.

O `Printf` do golib_dart lança em runtime nos verbos não portados; aqui, com
o formato constante e o tipo estático de cada operando, o g2d recusa antes
(`fmt-verbo:<caso>`), para o audit não contar como verde um pacote que
quebra ao rodar. Operando interface, `args...` e formato não constante só
se descobrem em runtime (lá continua o erro explícito).

`%#v` (sintaxe Go): básicos, structs, slices, arrays e maps. O tipo Go de um
slice/map/array não está no valor Dart: o operando estático desses tipos entra
no `Printf` embrulhado em `go.TypeTag(valor, 'nome Go', 'subjacente')`, e os
campos de struct trazem `$fieldTypes` (ver `StructClass.field_types`).
"""

from g2d.engine.behavior import NOT_HANDLED, ExprBehavior
from g2d.model import Unsupported

PRINTF = {"Printf", "Sprintf", "Errorf", "Fprintf"}  # Fprintf: formato no 2º argumento
FLAGS = "#0+- "


def directives(f):
    """[(flags, verbo, operando | None)] como o `doPrintf` do Go: `*` consome
    operando, `[n]` reposiciona; índice inválido → operando None. Devolve
    também se houve reordenação e quantos operandos foram consumidos."""
    out, arg, i, n, reordered = [], 0, 0, len(f), False

    def arg_number(i, arg):
        nonlocal reordered
        if i >= n or f[i] != "[":
            return arg, i, True, False
        reordered = True
        close = f.find("]", i)
        if close < 0:
            return arg, i + 1, False, False
        digits = f[i + 1:close]
        ok = digits.isdigit() and int(digits) >= 1
        return (int(digits) - 1 if ok else arg), close + 1, ok, True

    while True:
        j = f.find("%", i)
        if j < 0 or j + 1 >= n:
            return out, reordered, arg
        i = j + 1
        flags = ""
        while i < n and f[i] in FLAGS:
            flags += f[i]
            i += 1
        good = True
        arg, i, ok, after = arg_number(i, arg)
        good &= ok
        if i < n and f[i] == "*":
            i, arg, after = i + 1, arg + 1, False
        else:
            k = i
            while i < n and f[i].isdigit():
                i += 1
            good &= not (after and i > k)
        if i + 1 < n and f[i] == ".":
            i += 1
            good &= not after
            arg, i, ok, after = arg_number(i, arg)
            good &= ok
            if i < n and f[i] == "*":
                i, arg, after = i + 1, arg + 1, False
            else:
                while i < n and f[i].isdigit():
                    i += 1
        if not after:
            arg, i, ok, after = arg_number(i, arg)
            good &= ok
        if i >= n:
            return out, reordered, arg
        verb = f[i]
        i += 1
        if verb == "%":
            continue
        out.append((flags, verb, arg if good else None))
        if good:
            arg += 1


class FmtVerbCheck(ExprBehavior):
    """Especializa `CallExpr` de `fmt.Printf/Sprintf/Errorf`: valida o
    formato constante e devolve NOT_HANDLED (o CallExpr normal emite)."""

    kinds = ("CallExpr",)

    def emit(self, n):
        if n.get("$fmtTagged"):
            return NOT_HANDLED
        fun = n["fun"]
        if not (fun["node"] == "SelectorExpr" and fun["sel"]["name"] in PRINTF
                and (fun["x"].get("$obj") or {}).get("kind") == "package"
                and fun["x"]["$obj"].get("pkg") == "fmt"):
            return NOT_HANDLED
        args = n["args"] or []
        if fun["sel"]["name"] == "Fprintf":
            args = args[1:]  # o io.Writer vem antes do formato
        fmt_node = args[0] if args else None
        value = (fmt_node or {}).get("$value") or {}
        if value.get("kind") != "string" or "bytes" in value:
            return NOT_HANDLED  # formato dinâmico: só o runtime sabe
        operands = None if n["ellipsis"] is not None else args[1:]
        found, reordered, used = directives(value["value"])
        tagged = {}  # índice do operando → nó a embrulhar em go.TypeTag
        for flags, verb, k in found:
            t = operands[k] if operands is not None and k is not None and k < len(operands) else None
            kind = self.static_kind(t)
            case = self.unsupported(flags, verb, kind) or self.sharp_unsupported(flags, verb, kind, t)
            if case:
                raise Unsupported(f"fmt-verbo:{case}", f"fmt: {case} não portado no shim", fmt_node)
            if verb == "v" and "#" in flags and kind in ("composto", "nomeado") and k not in tagged:
                tagged[k] = t
        if operands is not None and not reordered:
            for extra in operands[used:]:
                kind = self.static_kind(extra)
                if kind in ("composto", "func", "chan", "ponteiro"):
                    raise Unsupported(f"fmt-verbo:extra-{kind}", "fmt: %!(EXTRA ...) de tipo sem nome em runtime",
                                      fmt_node)
        if tagged:
            return self.expr_prec(self.tag_operands(n, operands, tagged))
        return NOT_HANDLED

    def tag_operands(self, n, operands, tagged):
        """`n` com os operandos de `%#v` embrulhados em `go.TypeTag`."""
        args = list(n["args"])
        offset = len(args) - len(operands)
        sig = self.typesys.underlying(self.pkg.type_of(n["fun"]))
        iface_idx = self.pkg.type_at(sig["params"][-1])["elem"]  # `...any`
        iface = self.pkg.type_at(iface_idx)
        for k, node in tagged.items():
            t = self.pkg.type_of(node)
            under = (f"'{self.goinfo.sharp_type_name(self.typesys.underlying(t))}'"
                     if t["kind"] == "named" else "null")
            text = self.values.coerce(node, iface)
            tag = f"{self.imports.qualify(None, 'TypeTag')}({text}, '{self.goinfo.sharp_type_name(t)}', {under})"
            args[offset + k] = {"node": "G2DTemp", "text": tag, "$type": iface_idx}
        return dict(n, args=args, **{"$fmtTagged": True})

    def static_kind(self, node):
        """Categoria do tipo estático do operando (None: interface/desconhecido)."""
        t = self.pkg.type_of(node) if node is not None else None
        if t is None:
            return None
        u = self.typesys.underlying(t)
        k = u["kind"]
        if k == "basic":
            b = self.typesys.basic(t)
            return {"float": "float", "complex": "complex", "wint": "int"}.get(b.cat, b.cat) if b else None
        if k == "pointer":
            return "struct*" if self.typesys.is_struct(self.pkg.type_at(u["elem"])) else "ponteiro"
        if k in ("slice", "array", "map"):
            # Classe nomeada gerada tem `$goType` (%T, %!(EXTRA ...) funcionam).
            return "nomeado" if self.typesys.named_composite(t) else "composto"
        if k in ("func", "chan", "struct"):
            return k
        return None  # interface, typeparam

    def sharp_unsupported(self, flags, verb, kind, node):
        """`%#v` não portado: func, chan e ponteiro para não-struct (endereço);
        tipos compostos/structs que os contêm (aninhados). Ponteiro aninhado
        para struct passa: nil sai `(*T)(nil)`; não nil lança em runtime (o Go
        imprime o endereço)."""
        if verb != "v" or "#" not in flags:
            return None
        if kind in ("func", "chan", "ponteiro"):
            return f"%#v-{kind}"
        if kind in ("composto", "nomeado", "struct", "struct*"):
            t = self.pkg.type_of(node)
            if t["kind"] == "pointer":
                t = self.pkg.type_at(t["elem"])
            inner = self.sharp_inner(t, set())
            return f"%#v-{inner}" if inner else None
        return None

    def sharp_inner(self, t, seen):
        """Primeiro func/chan/ponteiro-para-não-struct dentro do tipo, ou None."""
        t = self.pkg.type_at(t)
        u = self.typesys.underlying(t)
        k = u["kind"]
        if k in ("func", "chan"):
            return k
        if k == "pointer":
            return None if self.typesys.is_struct(self.pkg.type_at(u["elem"])) else "ponteiro"
        if k == "typeparam":
            return "generico"
        key = self.goinfo.go_type_name(t)
        if key in seen:
            return None
        seen.add(key)
        if k in ("slice", "array"):
            return self.sharp_inner(u["elem"], seen)
        if k == "map":
            return self.sharp_inner(u["key"], seen) or self.sharp_inner(u["elem"], seen)
        if k == "struct":
            for f in u["fields"]:
                inner = self.sharp_inner(f["type"], seen)
                if inner:
                    return inner
        return None

    @staticmethod
    def unsupported(flags, verb, kind):
        """Caso não portado (texto do código) ou None."""
        if kind == "float" and verb in "bxX":
            return f"%{verb}-float"
        if kind == "float" and "#" in flags and verb != "v":  # %#v não usa o flag sharp
            return "#-float"
        if kind == "complex" and verb not in "vT":
            return f"%{verb}-complex"
        if kind == "int" and verb == "q" and "#" in flags:
            return "%#q-runa"
        if verb == "T" and kind in ("composto", "func", "chan", "ponteiro"):
            return f"%T-{kind}"
        if verb not in "vTp" and kind in ("func", "chan", "ponteiro"):
            return f"%{verb}-{kind}"
        return None
