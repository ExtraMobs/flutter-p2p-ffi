"""Conversões `T(x)` em tempo de execução (constantes já vêm dobradas em
`$value`): uma regra por par de categorias, escolhida em cadeia."""

from dataclasses import dataclass

from g2d.engine.behavior import ConversionBehavior
from g2d.engine.precedence import POSTFIX
from g2d.model import Unsupported


@dataclass
class Conversion:
    """Contexto de uma conversão: nó, tipos e categorias básicas."""

    n: dict
    arg: dict
    to_t: dict
    frm_t: dict
    to: object  # Basic ou None
    frm: object  # Basic ou None

    @classmethod
    def of(cls, engine, n, fun, arg):
        typesys = engine.services["typesys"]
        to_t, frm_t = engine.pkg.type_at(fun["$type"]), engine.pkg.type_of(arg)
        return cls(n, arg, to_t, frm_t, typesys.basic(to_t), typesys.basic(frm_t))

    @property
    def named_to(self):
        return self.to_t["kind"] == "named"

    @property
    def basics(self):
        return self.to is not None and self.frm is not None

    def unsupported(self):
        if not self.basics:
            return Unsupported("conversao:nao-basico", "conversão de tipo não-básico", self.n)
        return Unsupported(f"conversao:{self.frm.cat}-{self.to.cat}", f"conversão {self.frm.cat} → {self.to.cat}", self.n)


class Identity(ConversionBehavior):
    """Mesmo tipo: nada a fazer."""

    def accepts(self, c):
        return c.to_t == c.frm_t

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
    def accepts(self, c):
        return c.basics and c.to.cat == c.frm.cat == "complex" and not c.named_to

    def emit(self, c):
        return f"{self.types.cls(c.to_t)}.from{c.frm.cls}({self.expr(c.arg, POSTFIX)})", POSTFIX


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
        return f"{go(self.FUNCS[self.elem_cls(c.to_t)][0])}({x}, {self.descriptors.elem(u['elem'])})", POSTFIX


# Ordem de registro = prioridade crescente (a cadeia tenta do último ao
# primeiro): a identidade vence tudo, como no emissor original.
CONVERSIONS = [FromNil, StringSlice, Retype, IntToString, StringToString, ComplexToComplex, FloatToFloat, FloatToInt,
               IntToFloat, IntToInt, SameUnderlying, ToTypeParam, Identity]
