"""Constantes Go (valor exato do go/types) como literais Dart."""

from g2d.engine.behavior import Service
from g2d.model import Unsupported
from g2d.services.literals import dart_string, double_literal


class Literals(Service):
    """Constantes Go (valor exato do go/types) como literais Dart."""

    name = "literals"

    def literal(self, v, t):
        """Constante Go (valor exato do go/types) no tipo Dart de t."""
        k = v["kind"]
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
            return f"{cls}({text})" if named else text
        if k == "bool":
            return "true" if v["value"] else "false"
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
        if b.cat == "complex" and not named:
            return f"{g(b.cls)}.fromDoubles({double_literal(re)}, {double_literal(im)})"
        raise Unsupported(f"constante:{k}-{b.cat}", f"constante {k} como {b.cat}")

    def named_const(self, n):
        """Constante do próprio pacote referenciada por nome (mantém o nome)."""
        obj = n.get("$obj") if n["node"] == "Ident" else None
        return obj is not None and obj["kind"] == "const" and obj.get("pkg") == self.pkg.path
