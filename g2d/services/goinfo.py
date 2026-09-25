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
        if k == "interface" and not t["methods"]:
            return "interface {}"
        return k

    def method_names(self, t, value):
        """Method set (nomes Go ordenados) de T (value) ou *T."""
        ms = t.get("methods") or []
        return sorted(m["name"] for m in ms if not (value and m["ptr"]))

    def implements_clause(self, tidx):
        """`implements` com as interfaces que o go/types diz que T satisfaz."""
        names = []
        for i in self.facts.implements.get(tidx, []):
            it = self.pkg.type_at(i)
            if it["pkg"] == "" and it["name"] == "error":
                names.append(self.imports.qualify(None, "GoError"))
            elif it["pkg"] == self.pkg.path:
                names.append(type_name(it["name"]))
            elif (it["pkg"], it["name"]) in SHIM_INTERFACES:
                names.append(self.imports.qualify(it["pkg"], type_name(it["name"])))
        return names
