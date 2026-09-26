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
        if self.retypes(src, target):
            text, prec = self.retype(n, src, target)
        elif (src is not None and src["kind"] == "basic" and src["name"] == "untyped nil"
              and target is not None and not self.types.nilable(target)):
            text, prec = self.types.zero(target), POSTFIX  # nil de slice/map/func nomeada
        elif self.typesys.is_value(src) and to_iface:
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
            elif self.typesys.ptr_class(elem) and not elem.get("args"):
                nil = f"{self.types.dart(src).non_null()}.$nil"
            elif self.typesys.ptr_class(elem):  # genérico: sem estático, instância nova
                nil = f"{self.types.ptr_view(elem)}(const {self.imports.qualify(None, 'NilPtr')}<{self.types.dart(elem)}>())"
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

    def retypes(self, src, target):
        """src flui para target com o mesmo subjacente e um deles é classe
        nomeada sobre slice/map/func (Go permite atribuir se um não é nomeado)."""
        return (src is not None and target is not None and src != target
                and (self.typesys.named_composite(src) or self.typesys.named_composite(target))
                and self.typesys.underlying(src) == self.typesys.underlying(target))

    def retype(self, n, src, target):
        """Mesmo valor visto como outro tipo com o mesmo subjacente: slice/map
        compartilham o armazenamento; função nomeada desembrulha `$f`."""
        if self.typesys.named_func(src):
            text, prec = self.expr(n, POSTFIX) + ".$f", POSTFIX
        else:
            text, prec = self.expr_prec(n)
        if self.typesys.named_composite(target):
            return self.types.wrap(target, text), POSTFIX
        if self.typesys.underlying(target)["kind"] == "array":
            # `[4]byte(h)`: o tipo dinâmico deixa de ser Hash (interface, %T).
            return f"{self.types.dart(target)}.alias({text})", POSTFIX
        return text, prec

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
