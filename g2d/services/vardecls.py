"""Declarações var/const (pacote e locais)."""

from g2d.analysis.helpers import doc_comment
from g2d.engine.behavior import Service
from g2d.services.naming import member_name


class VarDecls(Service):
    """Declarações var/const (pacote e locais)."""

    name = "vars"

    def top_values(self, gen):
        out = doc_comment(gen["doc"])
        for spec in gen["specs"]:
            out += self.value_spec(spec, gen["tok"], top=True)
        return out

    def value_spec(self, spec, tok, top=False):
        """ValueSpec de var/const → declarações Dart."""
        names = spec["names"]
        values = spec["values"] or []
        out = []
        if tok == "const":
            for ident in names:
                if ident["name"] == "_":
                    continue
                obj = ident["$obj"]
                t = self.pkg.type_at(obj["type"])
                name = member_name(ident["name"]) if top else self.names.declare_local(ident)
                # Construtores dos wrappers não são const.
                kw = "const" if self.typesys.basic(t).cat == "bool" else "final"
                out.append(f"{kw} {self.types.dart(t)} {name} = {self.literals.literal(obj['value'], t)};")
            return out
        if top:
            values = []
        elif values and len(values) != len(names):
            tmp = self.names.temp()
            out.append(f"final {tmp} = {self.operands.multi_value(values[0])};")
            values = [f"{tmp}.${i + 1}" for i in range(len(names))]
        else:
            values = [self.values.coerce(v, self.pkg.type_at(ident["$obj"]["type"]) if "$obj" in ident else None)
                      for v, ident in zip(values, names)]
        for i, ident in enumerate(names):
            obj = ident["$obj"] if ident["name"] != "_" else None
            if obj is None:
                if values:
                    out.append(f"{values[i]};")
                continue
            # Nível de pacote: declara com o zero; o inicializador roda em $goInit.
            init = values[i] if values and not top else self.types.zero(obj["type"])
            t = self.pkg.type_at(obj["type"])
            if not top:
                out.append(self.names.local_decl(ident, t, init))
            elif self.names.boxed(obj):
                box_t, box = self.types.box(t, init)
                out.append(f"final {box_t} {member_name(ident['name'])} = {box};")
            else:
                out.append(f"{self.types.dart(t)} {member_name(ident['name'])} = {init};")
        return out
