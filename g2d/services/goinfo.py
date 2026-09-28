"""Identidade Go em runtime: nomes de tipo, method sets, `implements`."""

from g2d.config import SHIM_INTERFACES
from g2d.engine.behavior import Service
from g2d.services.naming import type_name


class GoTypeInfo(Service):
    """Identidade Go em runtime: nomes de tipo, method sets, `implements`."""

    name = "goinfo"

    def go_type_name(self, t):
        """Nome Go de um tipo (como `%T`): `main.Point`, `*main.Point`, `[]int`."""
        t = self.pkg.type_at(t)
        k = t["kind"]
        if k == "basic":
            # `byte`/`rune` são só apelidos de `uint8`/`int32` no go/types (o
            # nome da fonte sobrevive em `Basic.Name()`); em runtime (reflect,
            # que o fmt usa) sempre aparecem como uint8/int32 — só o slice
            # `[]byte` exato tem a exceção (hardcoded no `fmt.fmtBytes` do
            # Go), tratada em `go.Slice.goType`.
            name = t["name"].replace("untyped ", "")
            return {"byte": "uint8", "rune": "int32"}.get(name, name)
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

    def go_type_expr(self, t):
        """Expressão Dart do nome Go de t, para `go.Elem.goType`/`GoMap.keyElem`:
        string literal quando t não depende de parâmetro de tipo (o caso comum);
        senão, concatena com o `.goType` do dicionário (`$T`) em runtime — o
        mesmo `Elem<T>` real que `descriptors.elem` já passa nesse caso."""
        t = self.pkg.type_at(t)
        if t["kind"] == "typeparam":
            return f"${t['name']}.goType"
        if not self.descriptors.has_tparam(t):
            return f"'{self.go_type_name(t)}'"
        if t["kind"] == "pointer":
            return f"'*' + {self.go_type_expr(t['elem'])}"
        if t["kind"] == "slice":
            return f"'[]' + {self.go_type_expr(t['elem'])}"
        if t["kind"] == "array":
            return f"'[{t['len']}]' + {self.go_type_expr(t['elem'])}"
        if t["kind"] == "map":
            return f"'map[' + {self.go_type_expr(t['key'])} + ']' + {self.go_type_expr(t['elem'])}"
        return "'?'"  # struct/interface/func anônimos com parâmetro de tipo: raro, sem nome em runtime

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
            if self.typesys.is_universe(it, "error"):
                names.append(self.imports.qualify(None, "GoError"))
            elif self.imports.transpiled(it["pkg"]) or (it["pkg"], it["name"]) in SHIM_INTERFACES:
                names.append(self.types.dart(it).non_null())  # com argumentos: `Key<k8>`
        t = self.pkg.type_at(tidx)
        for m in t.get("methods") or []:
            if methods is not None and m["name"] not in methods:
                continue
            iface = self.error_iface(m)
            if iface is not None:
                names.append(self.imports.qualify(None, iface))
        return names

    def error_iface(self, m):
        """Interface do runtime que o pacote `errors` usa para percorrer a
        cadeia, se o método tem a assinatura exata: `Unwrap() error`,
        `Unwrap() []error`, `Is(error) bool`, `As(any) bool`."""
        sig = self.pkg.type_at(m["type"])
        params = [self.pkg.type_at(p) for p in sig["params"]]
        results = [self.pkg.type_at(r) for r in sig["results"]]

        def is_error(x):
            return self.typesys.is_universe(x, "error")

        def is_bool(x):
            return x["kind"] == "basic" and x["name"] == "bool"

        if m["name"] == "Unwrap" and not params and len(results) == 1:
            r = results[0]
            if is_error(r):
                return "Unwrapper"
            if r["kind"] == "slice" and is_error(self.pkg.type_at(r["elem"])):
                return "MultiUnwrapper"
        if len(params) == 1 and len(results) == 1 and is_bool(results[0]):
            p = params[0]
            if m["name"] == "Is" and is_error(p):
                return "ErrorIs"
            if m["name"] == "As" and p["kind"] == "interface" and not p["methods"]:
                return "ErrorAs"
        return None
