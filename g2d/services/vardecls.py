"""Declarações var/const (pacote e locais)."""

from g2d.engine.behavior import Service
from g2d.services.literals import doc_comment


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
                name = self.names.top_name(ident["name"], "const", obj.get("fold")) if top else self.names.declare_local(ident)
                # Construtores dos wrappers não são const.
                kw = "const" if self.typesys.basic(t).cat == "bool" else "final"
                out.append(f"{kw} {self.types.dart(t)} {name} = {self.literals.literal(obj['value'], t)};")
            return out
        if top:
            values = []
        elif values and len(values) != len(names):
            tmp = self.names.temp()
            targets = [ident["$obj"]["type"] if "$obj" in ident else None for ident in names]
            out.append(f"final {tmp} = {self.values.coerce_multi(values[0], targets)};")
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
                out.append(f"final {box_t} {self.names.top_name(ident['name'], 'var', obj.get('fold'))} = {box};")
            else:
                out.append(f"{self.types.dart(t)} {self.names.top_name(ident['name'], 'var', obj.get('fold'))} = {init};")
        return out
