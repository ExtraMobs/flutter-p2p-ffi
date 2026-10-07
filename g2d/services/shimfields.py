"""Campos func de struct do shim com cor própria (D4, no estilo do D7).

O shim fixa o formato Dart de alguns campos de função: `net.Resolver.Dial`
é chamado pelo cliente DNS do shim, que espera o resultado, e quem o
preenche costuma discar (`Dialer.DialContext` suspende); então o campo é
sempre `Future<R> Function(...)`. A classe do campo é
`("field", pacote, "Tipo.Campo")`, sempre `async`, sem prender a
assinatura comum (`func(context.Context, string, string) (net.Conn,
error)` segue a cor dela no grafo). Uma função síncrona que entra no campo
é embrulhada (`go.async3`, `ConcurrencyService.reclass`); uma chamada
`r.Dial(...)` no código gerado espera.

Como no `field_classes` (`g2d/analysis/color.py`), o tipo do campo na
struct do shim e nos seletores vira uma cópia do tipo func com `$class`.
"""

from g2d.engine.behavior import Service
from g2d.model import walk

# (pacote, tipo, campo) → o campo suspende (True). Só entra aqui campo cujo
# tipo Dart o shim declara com essa cor.
SHIM_FUNC_FIELDS = {("net", "Resolver", "Dial"): True}


def field_class(pkg, tname, field):
    return ("field", pkg, f"{tname}.{field}")


class ShimFieldColors(Service):
    """Aplica as classes de `SHIM_FUNC_FIELDS` ao pacote e devolve as
    classes `async` (idempotente por pacote)."""

    name = "shimfields"

    def apply(self, decls):
        pkg = self.pkg
        cached = pkg.__dict__.get("_shim_field_classes")
        if cached is not None:
            return cached
        typesys = self.typesys
        patched = {}  # id do struct subjacente → {campo: classe}
        out = set()
        for t in pkg.type_table:
            if t.get("kind") != "named":
                continue
            fields = {f: a for (p, n, f), a in SHIM_FUNC_FIELDS.items() if (p, n) == (t.get("pkg"), t.get("name"))}
            if not fields:
                continue
            st = typesys.underlying(t)
            if st.get("kind") != "struct":
                continue
            for f in st["fields"]:
                if f["name"] in fields:
                    cls = field_class(t["pkg"], t["name"], f["name"])
                    f["type"] = dict(pkg.type_at(f["type"]), **{"$class": cls})
                    patched.setdefault(id(st), {})[f["name"]] = f["type"]
                    if fields[f["name"]]:
                        out.add(cls)
        if patched:
            for n in walk(decls):
                if n.get("node") != "SelectorExpr" or (n.get("$sel") or {}).get("kind") != "field":
                    continue
                st = typesys.underlying(self.recv_struct(n))
                ft = patched.get(id(st), {}).get(n["sel"]["name"]) if st is not None else None
                if ft is not None:
                    n["$type"] = ft
        pkg._shim_field_classes = out
        return out

    def recv_struct(self, sel):
        t = self.pkg.type_of(sel["x"])
        if t is not None and t["kind"] == "pointer":
            t = self.pkg.type_at(t["elem"])
        return t
