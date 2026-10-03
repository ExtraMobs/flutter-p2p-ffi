"""Texto Dart a partir de valores Go: literais (string, double, record), doc
comments (funções puras) e o serviço `Literals` (constantes do go/types)."""

from g2d.engine.behavior import Service
from g2d.model import Unsupported


def double_literal(s):
    """Literal double Dart a partir do %g do Go (1 → 1.0; 1e+06 é válido)."""
    s = str(s)
    return s if any(c in s for c in ".eE") else s + ".0"


def dart_string(s):
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "'":
            out.append("\\'")
        elif ch == "$":
            out.append("\\$")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F:
            out.append(f"\\x{ord(ch):02x}")
        else:
            out.append(ch)
    return "'" + "".join(out) + "'"


def tuple_expr(items):
    """Um valor ou um record Dart `(a, b)` (múltiplos resultados)."""
    return items[0] if len(items) == 1 else "(" + ", ".join(items) + ")"


def doc_comment(group):
    """CommentGroup Go → linhas `///`."""
    if not group:
        return []
    lines = []
    for c in group["list"]:
        text = c["text"]
        if text.startswith("//"):
            lines.append("///" + (text[2:] if text[2:3] in ("", " ") else " " + text[2:]))
        else:
            for ln in text[2:-2].strip("\n").split("\n"):
                lines.append(("/// " + ln.strip()).rstrip())
    return lines


class Literals(Service):
    """Constantes Go (valor exato do go/types) como literais Dart."""

    name = "literals"

    def literal(self, v, t):
        """Constante Go (valor exato do go/types) no tipo Dart de t."""
        k = v["kind"]
        if t is not None and t["kind"] == "typeparam" and k in ("int", "float"):
            # `val - 1` com val do tipo T: a constante vira T pelo dicionário.
            if k == "int":
                return f"{self.descriptors.elem(t)}.ofInt!({self.literal(v, None)})"
            return f"{self.descriptors.elem(t)}.ofFloat!({self.literal(v, None)})"
        b = self.typesys.basic(t) if t else None
        if b is None or b.cat == "nil":  # sem tipo útil: tipo padrão do valor
            b = self.typesys.basic({"kind": "basic", "name": "untyped " + k})
        g = self.types.golang
        named = t is not None and t["kind"] == "named"
        cls = self.types.cls(t) if named else (g(b.cls) if b.cls else None)
        if k == "string":
            if "bytes" in v:  # não é UTF-8 válido: bytes exatos
                text = f"{self.imports.qualify(None, 'stringOfBytes')}(const {v['bytes']})"
            else:
                text = f"{g('String')}.fromDart({dart_string(v['value'])})"
            if t is not None and t["kind"] == "typeparam":
                # `a + "!"` com a de `T ~string` (bound StringBase): o valor
                # do tipo T pelo zero do dicionário.
                return f"{self.descriptors.elem(t)}.zero().$wrapStr({text})"
            return f"{cls}({text})" if named else text
        if k == "bool":
            text = "true" if v["value"] else "false"
            return f"{cls}({text})" if named and self.typesys.named_bool(t) else text
        if k == "complex":
            re, im = v["real"], v["imag"]
        else:
            re, im = v["value"], "0"
        if b.cat == "wint":
            n = int(float(re)) if k == "float" else int(re)
            if -(1 << 53) <= n <= (1 << 53):  # exato também no int do JS
                return f"{cls}({n})"
            return f"{cls}.fromBigInt(BigInt.parse('{n}'))"
        if b.cat == "float":
            return f"{cls}({double_literal(re)})"
        if b.cat == "complex":
            text = f"{g(b.cls)}.fromDoubles({double_literal(re)}, {double_literal(im)})"
            return f"{cls}({text})" if named else text
        raise Unsupported(f"constante:{k}-{b.cat}", f"constante {k} como {b.cat}")

    def named_const(self, n):
        """Constante de nível de pacote do próprio pacote referenciada por nome
        (mantém o nome). Constante local vira o literal exato em cada uso, e
        também a sem tipo usada noutro tipo (`[]uint32{IV0}`: declarada no
        tipo padrão, o Go a converte no uso)."""
        obj = n.get("$obj") if n["node"] == "Ident" else None
        if not (obj is not None and obj["kind"] == "const" and obj.get("pkg") == self.pkg.path
                and obj.get("top")):
            return False
        use, decl = self.pkg.type_of(n), self.pkg.type_at(obj["type"])
        return use is None or self.types.dart(use) == self.types.dart(decl)
