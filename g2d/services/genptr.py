"""`*T` de genérico instanciado com struct ou array (go.ValPtr na fronteira)."""

from g2d.engine.behavior import Service
from g2d.model import Unsupported


class GenericPointers(Service):
    """Dentro do genérico, `*T` é `go.Ptr<T>`; fora, `*P` com P struct ou
    array é o próprio objeto (e `*N` com métodos é `N$Ptr`). Na chamada de
    função genérica, o argumento `*T` vira a vista `go.valPtr<P>(x)` e o
    resultado `*T` volta ao objeto com `go.ptrTarget<P>(r)`. Em posição
    aninhada (`[]*T`, `func(*T)`, `map[K]*T`...) o Dart não converte:
    `Unsupported` `generico:ptr-valor`. ponytail: métodos e campos de tipo
    genérico instanciado não são cobertos (o dump não liga a instância à
    origem)."""

    name = "genptr"

    def origin_sig(self, generic):
        """Assinatura genérica (com os parâmetros de tipo) do callee de uma
        instanciação (`calls.instantiation`)."""
        obj = (generic["sel"] if generic["node"] == "SelectorExpr" else generic).get("$obj") or {}
        return self.pkg.type_at(obj["type"]) if obj.get("type") is not None else None

    def direct(self, origin, inst):
        """`*T` (T parâmetro de tipo) instanciado com `*P` de outra
        representação: o tipo do objeto P, senão None."""
        o, i = self.pkg.type_at(origin), self.pkg.type_at(inst)
        if o["kind"] != "pointer" or i["kind"] != "pointer":
            return None
        oe, ie = self.pkg.type_at(o["elem"]), self.pkg.type_at(i["elem"])
        if oe["kind"] != "typeparam" or ie["kind"] == "typeparam":
            return None
        if self.typesys.is_value(ie) or self.typesys.ptr_class(ie):
            return ie
        return None

    def check_nested(self, origin, inst, node):
        """Recusa `*T` → objeto em posição que o Dart não converte."""
        o, i = self.pkg.type_at(origin), self.pkg.type_at(inst)
        if self.direct(o, i) is not None:
            raise Unsupported("generico:ptr-valor",
                              "*T de genérico instanciado com struct/array (ou *N com métodos) "
                              "dentro de tipo composto", node)
        k = o["kind"]
        if k != i["kind"] or k == "typeparam":
            return
        pairs = []
        if k in ("pointer", "slice", "array", "chan"):
            pairs = [(o["elem"], i["elem"])]
        elif k == "map":
            pairs = [(o["key"], i["key"]), (o["elem"], i["elem"])]
        elif k == "func":
            pairs = list(zip(o["params"], i["params"])) + list(zip(o["results"], i["results"]))
        elif k == "tuple":
            pairs = list(zip(o["elems"], i["elems"]))
        elif k == "struct":
            pairs = [(a["type"], b["type"]) for a, b in zip(o["fields"], i["fields"])]
        elif k == "named":
            pairs = list(zip(o.get("args") or [], i.get("args") or []))
        for a, b in pairs:
            self.check_nested(a, b, node)

    def arg(self, text, origin, inst, node):
        """Argumento de chamada genérica: `go.valPtr<P>(x)` se `*T` ← `*P`."""
        elem = self.direct(origin, inst)
        if elem is None:
            self.check_nested(origin, inst, node)
            return text
        if not self.typesys.is_value(elem):
            return text  # N$Ptr já é um go.Ptr<N>
        return f"{self.imports.qualify(None, 'valPtr')}<{self.types.dart(elem).non_null()}>({text})"

    def result(self, text, origin_sig, inst_sig, node):
        """Resultado de chamada genérica: `go.ptrTarget<P>(r)` se `*T` → `*P`."""
        ors, irs = origin_sig["results"], inst_sig["results"]
        if len(ors) != 1:
            for a, b in zip(ors, irs):
                self.check_nested(a, b, node)
            return text
        elem = self.direct(ors[0], irs[0])
        if elem is None:
            self.check_nested(ors[0], irs[0], node)
            return text
        if not self.typesys.is_value(elem):
            raise Unsupported("generico:ptr-valor", "*T de genérico devolvido como *N com métodos", node)
        if node.get("$awaited"):
            raise Unsupported("generico:ptr-valor", "*T de genérico async devolvido como struct/array", node)
        return f"{self.imports.qualify(None, 'ptrTarget')}<{self.types.dart(elem).non_null()}>({text})"
