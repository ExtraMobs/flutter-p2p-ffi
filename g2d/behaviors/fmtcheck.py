"""Recusa na transpilação o que o shim `fmt` não formata.

O `Printf` do golib_dart lança em runtime nos verbos não portados; aqui, com
o formato constante e o tipo estático de cada operando, o g2d recusa antes
(`fmt-verbo:<caso>`), para o audit não contar como verde um pacote que
quebra ao rodar. Operando interface, `args...` e formato não constante só
se descobrem em runtime (lá continua o erro explícito).
"""

from g2d.engine.behavior import NOT_HANDLED, ExprBehavior
from g2d.model import Unsupported

PRINTF = {"Printf", "Sprintf", "Errorf"}
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
        fun = n["fun"]
        if not (fun["node"] == "SelectorExpr" and fun["sel"]["name"] in PRINTF
                and (fun["x"].get("$obj") or {}).get("kind") == "package"
                and fun["x"]["$obj"].get("pkg") == "fmt"):
            return NOT_HANDLED
        args = n["args"] or []
        fmt_node = args[0] if args else None
        value = (fmt_node or {}).get("$value") or {}
        if value.get("kind") != "string" or "bytes" in value:
            return NOT_HANDLED  # formato dinâmico: só o runtime sabe
        operands = None if n["ellipsis"] is not None else args[1:]
        found, reordered, used = directives(value["value"])
        for flags, verb, k in found:
            t = operands[k] if operands is not None and k is not None and k < len(operands) else None
            case = self.unsupported(flags, verb, self.static_kind(t))
            if case:
                raise Unsupported(f"fmt-verbo:{case}", f"fmt: {case} não portado no shim", fmt_node)
        if operands is not None and not reordered:
            for extra in operands[used:]:
                kind = self.static_kind(extra)
                if kind in ("composto", "func", "chan", "ponteiro"):
                    raise Unsupported(f"fmt-verbo:extra-{kind}", "fmt: %!(EXTRA ...) de tipo sem nome em runtime",
                                      fmt_node)
        return NOT_HANDLED

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
            return "composto"
        if k in ("func", "chan", "struct"):
            return k
        return None  # interface, typeparam

    @staticmethod
    def unsupported(flags, verb, kind):
        """Caso não portado (texto do código) ou None."""
        if verb == "v" and "#" in flags:
            return "%#v"
        if kind == "float" and verb in "bxX":
            return f"%{verb}-float"
        if kind == "float" and "#" in flags:
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
