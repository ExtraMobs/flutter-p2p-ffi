"""Conversões `T(x)` em tempo de execução (constantes já vêm dobradas em
`$value`): uma regra por par de categorias, escolhida em cadeia."""

from dataclasses import dataclass

from g2d.engine.behavior import ConversionBehavior
from g2d.engine.precedence import POSTFIX
from g2d.model import Unsupported
from g2d.services.naming import member_name, param_name


@dataclass
class Conversion:
    """Contexto de uma conversão: nó, tipos e categorias básicas."""

    n: dict
    arg: dict
    to_t: dict
    frm_t: dict
    to: object  # Basic ou None
    frm: object  # Basic ou None
    to_cat: str = ""  # categoria para o código do Unsupported
    frm_cat: str = ""

    @classmethod
    def of(cls, engine, n, fun, arg):
        typesys = engine.services["typesys"]
        to_t, frm_t = engine.pkg.type_at(fun["$type"]), engine.pkg.type_of(arg)
        to, frm = typesys.basic(to_t), typesys.basic(frm_t)
        return cls(n, arg, to_t, frm_t, to, frm, cls.category(typesys, to_t, to), cls.category(typesys, frm_t, frm))

    @staticmethod
    def category(typesys, t, basic):
        """`int`, `string`... para básicos; senão o kind do subjacente
        (`pointer`, `func`, `struct`...), com `named-` quando T é nomeado."""
        if basic is not None:
            return basic.cat
        kind = typesys.underlying(t)["kind"]
        return f"named-{kind}" if t["kind"] == "named" else kind

    @property
    def named_to(self):
        return self.to_t["kind"] == "named"

    @property
    def basics(self):
        return self.to is not None and self.frm is not None

    def unsupported(self):
        if not self.basics:
            return Unsupported(f"conversao:{self.frm_cat}-{self.to_cat}",
                               f"conversão {self.frm_cat} → {self.to_cat}", self.n)
        return Unsupported(f"conversao:{self.frm.cat}-{self.to.cat}", f"conversão {self.frm.cat} → {self.to.cat}", self.n)


class Identity(ConversionBehavior):
    """Mesmo tipo: nada a fazer."""

    def accepts(self, c):
        # `Flag(i < 2)`: o go/types tipa a comparação como Flag, mas ela é
        # `bool` nativo; a regra BoolToBool embrulha.
        return c.to_t == c.frm_t and not (self.typesys.named_bool(c.to_t) and not self.operands.flag_object(c.arg))

    def emit(self, c):
        return self.expr_prec(c.arg)


class SameUnderlying(ConversionBehavior):
    """Tipos não-básicos com o mesmo subjacente e sem nomes (ex. []T ↔ []T)."""

    def accepts(self, c):
        return (not c.basics and self.typesys.underlying(c.to_t) == self.typesys.underlying(c.frm_t)
                and not (c.to_t["kind"] == "named" or c.frm_t["kind"] == "named"))

    def emit(self, c):
        return self.expr_prec(c.arg)


class ToTypeParam(ConversionBehavior):
    """`T(n)` com T parâmetro de tipo: dicionário `$T.ofInt`."""

    def accepts(self, c):
        return c.to_t["kind"] == "typeparam" and c.frm is not None and c.frm.integer

    def emit(self, c):
        return f"{self.descriptors.elem(c.to_t)}.ofInt!({self.expr(c.arg)})", POSTFIX


class FloatToTypeParam(ConversionBehavior):
    """`T(f)` com T parâmetro de tipo e f float: dicionário `$T.ofFloat`."""

    def accepts(self, c):
        return c.to_t["kind"] == "typeparam" and c.frm is not None and c.frm.cat == "float"

    def emit(self, c):
        return f"{self.descriptors.elem(c.to_t)}.ofFloat!({self.expr(c.arg)})", POSTFIX


class FromTypeParam(ConversionBehavior):
    """`int64(x)`, `float64(x)` com x de parâmetro de tipo numérico: o valor
    em runtime é inteiro ou float (`go.realToInt` / `go.realToFloat`)."""

    def accepts(self, c):
        return (c.frm_t["kind"] == "typeparam" and c.to is not None
                and (c.to.integer or c.to.cat == "float"))

    def emit(self, c):
        go = lambda f: self.imports.qualify(None, f)  # noqa: E731
        x = self.expr(c.arg)
        cls = self.types.cls(c.to_t)
        if c.to.integer:
            signed = "true" if c.to.signed else "false"
            return f"{cls}.from({go('realToInt')}({x}, {c.to.width}, {signed}))", POSTFIX
        f = self.types.golang(c.to.cls)
        v = f"{go('realToFloat')}({x}, {f}.fromInt64, {f}.fromUint64, {f}.new)"
        return (f"{cls}({v}.toDouble())" if c.named_to else v), POSTFIX


class IntToInt(ConversionBehavior):
    def accepts(self, c):
        return c.basics and c.to.integer and c.frm.integer

    def emit(self, c):
        return f"{self.types.cls(c.to_t)}.from({self.expr(c.arg)})", POSTFIX


class IntToFloat(ConversionBehavior):
    """Arredondamento único, como o Go (via Int64/Uint64 exatos)."""

    def accepts(self, c):
        return c.basics and c.to.cat == "float" and c.frm.integer

    def emit(self, c):
        g = self.types.golang
        to_cls = self.types.cls(c.to_t)
        x = self.expr(c.arg, POSTFIX)
        src = "Int64" if c.frm.signed else "Uint64"
        v = f"{g(c.to.cls)}.from{src}({g(src)}.from({x}))"
        return (f"{to_cls}({v}.toDouble())" if c.named_to else v), POSTFIX


class FloatToInt(ConversionBehavior):
    """Regras do gc/amd64 (`toInteger`)."""

    def accepts(self, c):
        return c.basics and c.to.integer and c.frm.cat == "float"

    def emit(self, c):
        x = self.expr(c.arg, POSTFIX)
        bits = f"{x}.toInteger({c.to.width}, signed: {'true' if c.to.signed else 'false'})"
        return f"{self.types.cls(c.to_t)}.from({bits})", POSTFIX


class FloatToFloat(ConversionBehavior):
    def accepts(self, c):
        return c.basics and c.to.cat == c.frm.cat == "float"

    def emit(self, c):
        return f"{self.types.cls(c.to_t)}({self.expr(c.arg, POSTFIX)}.toDouble())", POSTFIX


class ComplexToComplex(ConversionBehavior):
    """Entre complex64/complex128 e tipos nomeados sobre eles (`$c` guarda o
    valor do subjacente)."""

    def accepts(self, c):
        return c.basics and c.to.cat == c.frm.cat == "complex"

    def emit(self, c):
        x = self.expr(c.arg, POSTFIX)
        if c.frm_t["kind"] == "named":
            x += ".$c"
        if c.frm.cls != c.to.cls:
            x = f"{self.types.golang(c.to.cls)}.from{c.frm.cls}({x})"
        return (f"{self.types.cls(c.to_t)}({x})" if c.named_to else x), POSTFIX


class StringToString(ConversionBehavior):
    """string ↔ tipo nomeado sobre string."""

    def accepts(self, c):
        return c.basics and c.to.cat == c.frm.cat == "string"

    def emit(self, c):
        to_cls = self.types.cls(c.to_t)
        x = self.expr(c.arg, POSTFIX)
        return (f"{to_cls}({x}.$str)" if c.named_to else f"{x}.$str"), POSTFIX


class IntToString(ConversionBehavior):
    """`string(r)`: ponto de código (U+FFFD se inválido)."""

    def accepts(self, c):
        return c.basics and c.to.cat == "string" and c.frm.integer

    def emit(self, c):
        to_cls = self.types.cls(c.to_t)
        x = self.expr(c.arg, POSTFIX)
        v = f"{self.types.golang('String')}.fromCodePoint({x}.toInt())"
        return (f"{to_cls}({v})" if c.named_to else v), POSTFIX


class Retype(ConversionBehavior):
    """`IDs(s)`, `[]string(ids)`, `Op(fn)`: mesmo subjacente, classe nomeada
    sobre slice/map/func de um dos lados."""

    def accepts(self, c):
        return self.values.retypes(c.frm_t, c.to_t)

    def emit(self, c):
        return self.values.retype(c.arg, c.frm_t, c.to_t)


class StructToStruct(ConversionBehavior):
    """`B(a)` entre structs com os mesmos campos (nomes e tipos; tags não
    contam): um B novo com os campos de uma cópia de a, numa expressão
    (`switch (a) { final $t => B(x: $t._x) }`, a avaliada uma vez)."""

    def fields(self, t):
        u = self.typesys.underlying(t)
        if u["kind"] != "struct":
            return None
        return [(f["name"], self.pkg.type_at(f["type"])) for f in u["fields"]]

    def accepts(self, c):
        a, b = self.fields(c.frm_t), self.fields(c.to_t)
        return a is not None and a == b

    def emit(self, c):
        tmp = self.names.temp()
        args = [self.descriptors.elem(a) for a in self.typesys.type_args(c.to_t)]
        args += [f"{param_name(name)}: {tmp}.{member_name(name)}"
                 for name, _ in self.fields(c.to_t) if name != "_"]
        src = self.values.coerce(c.arg, c.frm_t)
        return f"switch ({src}) {{ final {tmp} => {self.types.dart(c.to_t).non_null()}({', '.join(args)}) }}", POSTFIX


class BoolToBool(ConversionBehavior):
    """`Flag(b)`, `bool(f)`, `Flag(g)`: via o `bool` Dart (`$b` do nomeado)."""

    def accepts(self, c):
        return c.basics and c.to.cat == c.frm.cat == "bool"

    def emit(self, c):
        v = self.operands.cond(c.arg)
        if self.typesys.named_bool(c.to_t):
            return f"{self.types.dart(c.to_t)}({v})", POSTFIX
        return v, (POSTFIX if self.typesys.named_bool(c.frm_t) else 0)


class SliceToArray(ConversionBehavior):
    """`[N]T(s)` (Go 1.20): cópia dos N primeiros (`go.sliceToArray`, com o
    pânico do Go se o slice for curto)."""

    def accepts(self, c):
        return (self.typesys.underlying(c.to_t)["kind"] == "array"
                and self.typesys.underlying(c.frm_t)["kind"] == "slice")

    def emit(self, c):
        n = self.typesys.underlying(c.to_t)["len"]
        arr = f"{self.imports.qualify(None, 'sliceToArray')}({self.expr(c.arg)}, {n})"
        return self.types.wrap(c.to_t, arr), POSTFIX


class SliceToArrayPtr(ConversionBehavior):
    """`(*[N]T)(s)` (Go 1.17): um GoArray sobre o armazenamento do slice
    (`go.sliceToArrayPtr`: escritas por um aparecem no outro; slice curto dá
    o pânico do Go; slice nil dá ponteiro nil)."""

    def accepts(self, c):
        if c.to_t["kind"] != "pointer" or self.typesys.underlying(c.frm_t)["kind"] != "slice":
            return False
        return self.typesys.underlying(self.pkg.type_at(c.to_t["elem"]))["kind"] == "array"

    def emit(self, c):
        at = self.pkg.type_at(c.to_t["elem"])
        if at["kind"] == "named":
            raise Unsupported("conversao:slice-named-array-pointer", "conversão slice → ponteiro para array nomeado", c.n)
        n = at["len"]
        return f"{self.imports.qualify(None, 'sliceToArrayPtr')}({self.expr(c.arg)}, {n})", POSTFIX


class PointerToPointer(ConversionBehavior):
    """`(*U)(p)` com `*T` e `*U` de mesmo subjacente básico: a mesma variável
    vista com outro tipo (`go.ConvPtr`, converte na leitura e na escrita;
    nil continua nil). Structs e arrays são o próprio endereço, de classes
    diferentes: sem aliasing possível, `Unsupported`."""

    def accepts(self, c):
        if c.to_t["kind"] != "pointer" or c.frm_t["kind"] != "pointer":
            return False
        return all(self.typesys.basic(self.pkg.type_at(t["elem"])) is not None for t in (c.to_t, c.frm_t))

    def emit(self, c):
        u, t = c.to_t["elem"], c.frm_t["elem"]

        def conv(frm, to):  # o valor `v` de frm como to, pelas regras de conversão
            fun, arg = {"$type": to, "$isType": True}, {"node": "G2DTemp", "text": "v", "$type": frm}
            return self.engine.convert(c.n, fun, arg)[0]

        ud, td = self.types.dart(u).non_null(), self.types.dart(t).non_null()
        view = (f"{self.imports.qualify(None, 'convPtr')}<{ud}, {td}>({self.expr(c.arg)}, "
                f"(v) => {conv(t, u)}, (v) => {conv(u, t)})")
        ut = self.pkg.type_at(u)
        if self.typesys.ptr_class(ut):  # *U com métodos: a vista U$Ptr
            view = f"(switch ({view}) {{ final $cp? => {self.types.ptr_view(ut)}($cp), _ => null }})"
        return view, POSTFIX


class ToInterface(ConversionBehavior):
    """`any(x)`, `I(x)`: o mesmo que atribuir x a uma interface (`coerce`:
    struct/array por valor vai copiada, ponteiro nil tipado vira sentinela)."""

    def accepts(self, c):
        return self.typesys.underlying(c.to_t)["kind"] == "interface" and (c.frm is None or c.frm.cat != "nil")

    def emit(self, c):
        return self.values.coerce(c.arg, c.to_t), POSTFIX


class FromNil(ConversionBehavior):
    """`T(nil)` (slice, map, ponteiro, func, interface): o zero value de T."""

    def accepts(self, c):
        return c.frm is not None and c.frm.cat == "nil"

    def emit(self, c):
        return self.types.zero(c.to_t), POSTFIX


class StringSlice(ConversionBehavior):
    """`[]byte(s)`, `[]rune(s)`, `string(b)`, `string(rs)`: UTF-8 do Go
    (decodificação inválida vira U+FFFD) nos helpers do runtime."""

    FUNCS = {"Uint8": ("bytesOf", "stringOfByteSlice"), "Int32": ("runesOf", "stringOfRunes")}

    def elem_cls(self, t):
        """Classe do elemento de um slice de byte/rune (não nomeado), ou None."""
        u = self.typesys.underlying(t)
        if u["kind"] != "slice":
            return None
        e = self.pkg.type_at(u["elem"])
        b = self.typesys.basic(e) if e["kind"] == "basic" else None
        return b.cls if b is not None and b.cls in self.FUNCS else None

    def accepts(self, c):
        if c.to is not None and c.to.cat == "string":
            return self.elem_cls(c.frm_t) is not None
        return c.frm is not None and c.frm.cat == "string" and self.elem_cls(c.to_t) is not None

    def emit(self, c):
        go = lambda f: self.imports.qualify(None, f)  # noqa: E731
        x = self.expr(c.arg, POSTFIX)
        if c.to is not None:  # para string
            v = f"{go(self.FUNCS[self.elem_cls(c.frm_t)][1])}({x})"
            return (f"{self.types.cls(c.to_t)}({v})" if c.named_to else v), POSTFIX
        if c.frm_t["kind"] == "named":
            x += ".$str"
        u = self.typesys.underlying(c.to_t)
        v = f"{go(self.FUNCS[self.elem_cls(c.to_t)][0])}({x}, {self.descriptors.elem(u['elem'])})"
        return self.types.wrap(c.to_t, v), POSTFIX  # `buf("x")`: slice nomeado


# Ordem de registro = prioridade crescente (a cadeia tenta do último ao
# primeiro): a identidade vence tudo, como no emissor original.
CONVERSIONS = [FromNil, BoolToBool, SliceToArray, SliceToArrayPtr, PointerToPointer, ToInterface, StringSlice, StructToStruct, Retype, IntToString, StringToString, ComplexToComplex, FloatToFloat, FloatToInt,
               IntToFloat, IntToInt, SameUnderlying, FromTypeParam, FloatToTypeParam, ToTypeParam, Identity]
