"""Classificação de chamadas: função declarada, instanciação genérica, recover, receptor ponteiro."""

from g2d.engine.behavior import Service
from g2d.model import has_recover


class Calls(Service):
    """Classificação de chamadas: função declarada, instanciação genérica, recover, receptor ponteiro."""

    name = "calls"

    @staticmethod
    def instantiation(fun):
        """Chamada de função genérica: (identificador, argumentos de tipo)."""
        f = fun
        if f["node"] in ("IndexExpr", "IndexListExpr"):
            f = f["x"]
        if f["node"] == "Ident" and f.get("$inst") and f.get("$obj", {}).get("kind") == "func":
            return f, f["$inst"]
        # `pkg.F[T]`: o `$inst` fica no identificador selecionado.
        if (f["node"] == "SelectorExpr" and (f["x"].get("$obj") or {}).get("kind") == "package"
                and f["sel"].get("$inst") and f["sel"].get("$obj", {}).get("kind") == "func"):
            return f, f["sel"]["$inst"]
        return None

    @staticmethod
    def declared_func(fun):
        """Callee é função/método declarado (nunca nil) ou literal?"""
        while fun["node"] == "ParenExpr":
            fun = fun["x"]
        if fun["node"] == "FuncLit":
            return True
        if fun["node"] == "Ident":
            return fun["$obj"]["kind"] == "func"
        if fun["node"] == "SelectorExpr":
            sel = fun.get("$sel")
            return sel["kind"] == "method" if sel else fun["sel"]["$obj"]["kind"] == "func"
        return False

    def known_recoverer(self, fun):
        """O callee é uma função/método/literal do pacote que chama recover()?"""
        if fun["node"] == "FuncLit":
            return has_recover(fun["body"])
        if fun["node"] == "Ident":
            return fun.get("$obj", {}).get("decl") in self.facts.recoverers
        if fun["node"] == "SelectorExpr":
            return fun["sel"].get("$obj", {}).get("decl") in self.facts.recoverers
        return False

    def value_method(self, t, name):
        """`name` é método de receptor valor declarado no tipo de valor t
        (ou *t)? Então um method value liga uma cópia do receptor."""
        if t["kind"] == "pointer":
            t = self.pkg.type_at(t["elem"])
        return self.typesys.is_value(t) and any(m["name"] == name and not m["ptr"] for m in t.get("methods") or [])

    def ptr_method_of(self, t, name):
        """`name` é método de receptor ponteiro de N (não-struct, valor
        endereçável t = N)? A chamada `x.M()` usa `&x` (N$Ptr)."""
        return self.typesys.ptr_class(t) and any(m["name"] == name and m["ptr"] for m in t["methods"])

    def ptr_method(self, t, name):
        """O método `name` de *T (t ponteiro) tem receptor ponteiro?"""
        elem = self.pkg.type_at(t["elem"])
        return any(m["name"] == name and m["ptr"] for m in elem.get("methods") or [])
