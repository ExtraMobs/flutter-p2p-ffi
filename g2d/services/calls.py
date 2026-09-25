"""Classificação de chamadas: função declarada, instanciação genérica, recover, receptor ponteiro."""

from g2d.analysis.helpers import has_recover
from g2d.engine.behavior import Service


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

    def ptr_method(self, t, name):
        """O método `name` de *T (t ponteiro) tem receptor ponteiro?"""
        elem = self.pkg.type_at(t["elem"])
        return any(m["name"] == name and m["ptr"] for m in elem.get("methods") or [])
