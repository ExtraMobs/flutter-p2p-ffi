"""Semântica de valor: cópia de structs/arrays, conversão para interface, atribuição in-place."""

from g2d.engine.behavior import Service
from g2d.engine.precedence import DART_PREC, POSTFIX
from g2d.model import Unsupported, unparen


class ValueSemantics(Service):
    """Semântica de valor: cópia de structs/arrays, conversão para interface, atribuição in-place."""

    name = "values"

    @staticmethod
    def fresh(n):
        """Expressão que já produz um valor novo (não precisa de cópia)."""
        n = unparen(n)
        if n["node"] == "CompositeLit":
            return True
        return n["node"] == "CallExpr" and not n["fun"].get("$isType")

    def coerce(self, n, target, min_prec=0):
        """Valor de n fluindo para um lugar do tipo target (atribuição,
        argumento, retorno, elemento...): copia structs, embrulha ponteiros
        que entram em interface."""
        src = self.pkg.type_of(n)
        reclass = self.concurrency.reclass(n, src, self.pkg.type_at(target) if target is not None else None)
        if reclass in ("bare", "wrap-bare"):
            n = dict(n)  # cópia: id novo, sai do embrulho da classe de origem
        to_iface = target is not None and self.typesys.underlying(target)["kind"] == "interface"
        if self.typesys.named_bool(target) and not self.operands.flag_object(n) and n.get("$value") is None:
            # bool sem nome (comparação, &&...) num lugar do tipo `Flag`.
            text, prec = f"{self.types.dart(target)}({self.operands.cond(n)})", POSTFIX
        elif self.retypes(src, target):
            text, prec = self.retype(n, src, target)
        elif (src is not None and src["kind"] == "basic" and src["name"] == "untyped nil"
              and target is not None and not self.types.nilable(target)):
            text, prec = self.types.zero(target), POSTFIX  # nil de slice/map/func nomeada
        elif self.typesys.is_value(src) and to_iface:
            # Struct por valor numa interface: cópia marcada ($isValue); um
            # ponteiro entra como o próprio objeto (métodos chamáveis).
            text, prec = f"{self.expr(n, POSTFIX)}.$ifaceCopy()", POSTFIX
        elif self.typesys.is_value(src) and not self.fresh(n):
            text, prec = self.copy_text(self.expr(n, POSTFIX), src), POSTFIX
        elif to_iface and src is not None and src["kind"] == "pointer":
            # `(*T)(nil)` numa interface não é nil: sentinela do tipo.
            elem = self.pkg.type_at(src["elem"])
            if self.typesys.is_struct(elem) and not self.typesys.type_args(elem):
                nil = f"{self.types.dart(elem)}.$nil"
            elif self.typesys.ptr_class(elem) and not self.typesys.type_args(elem):
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
        elif to_iface and src is not None and src["kind"] == "func":
            # Tipo func sem nome numa interface: o Dart só testa subtipo entre
            # tipos de função, então o valor viaja com o nome Go do tipo
            # (comparado bit a bit na assertion/type switch; `go.Func`).
            # ponytail: parâmetro de tipo com union de funcs (`~func() |
            # ~func() error`, go.uber.org/fx.Callable) ainda usa o teste de
            # subtipo do Dart dentro do corpo genérico: o nome Go concreto só
            # existe em cada instanciação, não no `T` (TODO/P2 se pesar).
            func = self.imports.qualify(None, "Func")
            sig = self.goinfo.go_type_name(src)
            text, prec = f"{func}({self.expr(n, POSTFIX)}, '{sig}')", POSTFIX
        else:
            text, prec = self.expr_prec(n)
        if reclass in ("wrap", "wrap-bare"):
            text, prec = self.async_wrap(text, src, nilable=reclass == "wrap"), POSTFIX
        return f"({text})" if prec < min_prec else text

    def coerce_multi(self, n, targets):
        """`operands.multi_value(n)` com os valores fluindo para os tipos
        targets (None: não converte). Só a troca de classe de func pede
        conversão aqui (`ctx, cancel = context.WithCancel(ctx)` com `cancel
        func()` numa classe `async`): o record é desestruturado num switch
        expression e refeito."""
        text = self.operands.multi_value(n)
        t = self.pkg.type_of(n)
        if unparen(n)["node"] != "CallExpr" or t is None or t["kind"] != "tuple":
            return text
        elems = [self.pkg.type_at(e) for e in t["elems"]]
        targets = [None if tg is None else self.pkg.type_at(tg) for tg in targets]
        probe = [{"node": "G2DTemp", "text": "", "$type": e} for e in t["elems"]]
        if not any(tg is not None and self.concurrency.reclass(x, e, tg)
                   for x, e, tg in zip(probe, elems, targets)):
            return text
        temps = [dict(x, text=self.names.temp()) for x in probe]
        items = [x["text"] if tg is None else self.coerce(x, tg) for x, tg in zip(temps, targets)]
        pattern = ", ".join(f"final {x['text']}" for x in temps)
        return f"(switch ({text}) {{ ({pattern}) => ({', '.join(items)}) }})"

    def async_wrap(self, text, t, nilable=False):
        """Valor func síncrono visto como `Future<R> Function(...)` (nil
        continua nil se o valor pode ser nil: `go.asyncOrNil0`)."""
        from g2d.behaviors.exprs import MAX_ASYNC_ARITY

        arity = len(self.typesys.underlying(t)["params"])
        if arity > MAX_ASYNC_ARITY:
            raise Unsupported("async:valor-func-aridade", f"valor func síncrono com {arity} parâmetros numa classe async")
        name = f"asyncOrNil{arity}" if nilable else f"async{arity}"
        return f"{self.imports.qualify(None, name)}({text})"

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
        """Cópia de um valor já emitido (ex. elemento em range). Parâmetro de
        tipo com core de array (`[3]int | [4]int`) copia pelo dicionário
        (`$copy()` devolveria o GoArray, não o T)."""
        if not self.typesys.is_value(t):
            return text
        if t["kind"] == "typeparam":
            return f"{self.descriptors.elem(t)}.copyOf({text})"
        return f"{text}.$copy()"

    def assign(self, lhs, rhs):
        """`lhs = rhs` com semântica Go: struct existente é sobrescrita
        in-place (ponteiros para ela continuam válidos)."""
        t = self.pkg.type_of(lhs)
        if self.typesys.is_value(t) and not self.operands.is_map_index(lhs):
            return f"{self.expr(lhs, POSTFIX)}.$set({self.expr(rhs)});"
        return f"{self.operands.lvalue(lhs)} = {self.coerce(rhs, t)};"
