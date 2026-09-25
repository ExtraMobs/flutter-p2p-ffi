"""Semântica de valor: cópia de structs/arrays, conversão para interface, atribuição in-place."""

from g2d.engine.behavior import Service
from g2d.engine.precedence import DART_PREC, POSTFIX


class ValueSemantics(Service):
    """Semântica de valor: cópia de structs/arrays, conversão para interface, atribuição in-place."""

    name = "values"

    @staticmethod
    def fresh(n):
        """Expressão que já produz um valor novo (não precisa de cópia)."""
        while n["node"] == "ParenExpr":
            n = n["x"]
        if n["node"] == "CompositeLit":
            return True
        return n["node"] == "CallExpr" and not n["fun"].get("$isType")

    def coerce(self, n, target, min_prec=0):
        """Valor de n fluindo para um lugar do tipo target (atribuição,
        argumento, retorno, elemento...): copia structs, embrulha ponteiros
        que entram em interface."""
        src = self.pkg.type_of(n)
        to_iface = target is not None and self.typesys.underlying(target)["kind"] == "interface"
        if self.typesys.is_value(src) and to_iface:
            # Struct por valor numa interface: cópia marcada ($isValue); um
            # ponteiro entra como o próprio objeto (métodos chamáveis).
            text, prec = f"{self.expr(n, POSTFIX)}.$ifaceCopy()", POSTFIX
        elif self.typesys.is_value(src) and not self.fresh(n):
            text, prec = f"{self.expr(n, POSTFIX)}.$copy()", POSTFIX
        elif to_iface and src is not None and src["kind"] == "pointer":
            # `(*T)(nil)` numa interface não é nil: sentinela do tipo.
            elem = self.pkg.type_at(src["elem"])
            if self.typesys.is_struct(elem) and not elem.get("args"):
                nil = f"{self.types.dart(elem)}.$nil"
            elif not self.typesys.is_value(elem):
                nil = f"const {self.imports.qualify(None, 'NilPtr')}<{self.types.dart(elem)}>()"
            else:
                nil = None
            text, prec = self.expr_prec(n)
            if nil:
                inner = f"({text})" if prec < DART_PREC["||"] else text
                text, prec = f"{inner} ?? {nil}", DART_PREC["||"] - 1
        else:
            text, prec = self.expr_prec(n)
        return f"({text})" if prec < min_prec else text

    def copy_text(self, text, t):
        """Cópia de um valor já emitido (ex. elemento em range)."""
        return f"{text}.$copy()" if self.typesys.is_value(t) else text

    def assign(self, lhs, rhs):
        """`lhs = rhs` com semântica Go: struct existente é sobrescrita
        in-place (ponteiros para ela continuam válidos)."""
        t = self.pkg.type_of(lhs)
        if self.typesys.is_value(t) and not self.operands.is_map_index(lhs):
            return f"{self.expr(lhs, POSTFIX)}.$set({self.expr(rhs)});"
        return f"{self.operands.lvalue(lhs)} = {self.coerce(rhs, t)};"
