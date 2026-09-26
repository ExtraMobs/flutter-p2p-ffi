"""Identidade Go em runtime: nomes de tipo, method sets, `implements`."""

from g2d.config import SHIM_INTERFACES
from g2d.engine.behavior import Service
from g2d.services.naming import type_name


class GoTypeInfo(Service):
    """Identidade Go em runtime: nomes de tipo, method sets, `implements`."""

    name = "goinfo"

    def go_type_name(self, t):
        """Nome Go de um tipo (como `%T`): `main.Point`, `*main.Point`, `[]int`."""
        t = self.pkg.type_at(t) if isinstance(t, int) else t
        k = t["kind"]
        if k == "basic":
            return t["name"].replace("untyped ", "")
        if k == "named":
            if not t["pkg"]:
                return t["name"]
            pkg = self.pkg.name if t["pkg"] == self.pkg.path else t["pkg"].rsplit("/", 1)[-1]
            return f"{pkg}.{t['name']}"
        if k == "pointer":
            return "*" + self.go_type_name(t["elem"])
        if k == "slice":
            return "[]" + self.go_type_name(t["elem"])
        if k == "map":
            return f"map[{self.go_type_name(t['key'])}]{self.go_type_name(t['elem'])}"
        if k == "interface":
            if not t["methods"]:
                return "interface {}"
            ms = "; ".join(m["name"] + self.go_type_name(m["type"])[4:] for m in t["methods"])
            return f"interface {{ {ms} }}"
        if k == "struct":
            if not t["fields"]:
                return "struct {}"
            fs = "; ".join((f"{f['name']} " if not f["embedded"] else "") + self.go_type_name(f["type"])
                           for f in t["fields"])
            return f"struct {{ {fs} }}"
        if k == "array":
            return f"[{t['len']}]{self.go_type_name(t['elem'])}"
        if k == "func":
            params = [self.go_type_name(p) for p in t["params"]]
            if t["variadic"]:
                params[-1] = "..." + params[-1][2:]
            res = [self.go_type_name(r) for r in t["results"]]
            out = res[0] if len(res) == 1 else f"({', '.join(res)})" if res else ""
            return f"func({', '.join(params)})" + (f" {out}" if out else "")
        return k

    def method_names(self, t, value):
        """Method set (nomes Go ordenados) de T (value) ou *T."""
        ms = t.get("methods") or []
        return sorted(m["name"] for m in ms if not (value and m["ptr"]))

    def implements_clause(self, tidx, methods=None):
        """`implements` com as interfaces que o go/types diz que T ou *T
        satisfaz; com [methods], só as cobertas por esse method set (N não-struct
        e seu N$Ptr são classes distintas)."""
        names = []
        for i in self.facts.implements.get(tidx, []):
            it = self.pkg.type_at(i)
            if methods is not None and not {m["name"] for m in self.typesys.underlying(it)["methods"]} <= set(methods):
                continue
            if it["kind"] == "interface":  # interface anônima: classe sintética
                names.append(self.types.dart(it).non_null())
                continue
            if it["pkg"] == "" and it["name"] == "error":
                names.append(self.imports.qualify(None, "GoError"))
            elif self.imports.transpiled(it["pkg"]) or (it["pkg"], it["name"]) in SHIM_INTERFACES:
                names.append(self.imports.qualify(it["pkg"], type_name(it["name"])))
        return names
