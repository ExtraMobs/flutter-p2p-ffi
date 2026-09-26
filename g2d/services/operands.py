"""Operandos com regras Go: índices/contagens como int Dart, lvalues, shifts."""

from g2d.engine.behavior import Service
from g2d.engine.precedence import POSTFIX


class Operands(Service):
    """Operandos com regras Go: índices/contagens como int Dart, lvalues, shifts."""

    name = "operands"

    def to_int(self, n):
        """Expressão inteira Go como int Dart (índices, contagens). `toIndex`:
        fora de ±2^53 dá um sentinela fora do intervalo que guarda o valor
        exato para a mensagem do panic."""
        v = n.get("$value")
        if v is not None:
            return v["value"]
        return self.dart_length(n) or f"{self.expr(n, POSTFIX)}.toIndex()"

    def dart_length(self, n):
        """`len(x)`/`cap(x)` como int Dart (sem passar por Golang.Int), ou
        None se n não for um deles sobre slice/array/map/string."""
        fun = n.get("fun") if n["node"] == "CallExpr" else None
        if not (fun and fun.get("$builtin") and fun.get("name") in ("len", "cap")):
            return None
        x = n["args"][0]
        kind = self.typesys.underlying(self.pkg.type_of(x))["kind"]
        if kind not in ("slice", "array", "map", "basic"):
            return None
        attr = "capacity" if fun["name"] == "cap" and kind != "array" else "length"
        return f"{self.expr(x, POSTFIX)}.{attr}"

    def from_int(self, dart_int, t):
        """int Dart → valor do tipo inteiro Go t."""
        return f"{self.types.cls(t)}({dart_int})"

    def shift_count(self, y):
        """Contagem de shift como int Dart. Constante: literal; senão
        go.shiftCount (negativa → panic; >= 64 satura)."""
        v = y.get("$value")
        if v is not None:
            return v["value"]
        return f"{self.imports.qualify(None, 'shiftCount')}({self.expr(y)})"

    def lvalue(self, n):
        """Alvo de atribuição: `m[k]` sem o `?? zero` da leitura."""
        if self.is_map_index(n):
            return f"{self.expr(n['x'], POSTFIX)}[{self.expr(n['index'])}]"
        return self.expr(n, POSTFIX)

    def flag_object(self, n):
        """n é um objeto de bool nomeado (`Flag`) no Dart? O go/types dá o
        tipo do contexto a uma comparação (`return a < b` num `Flag`), mas o
        Dart produz `bool` nativo; `!`, `&&`, `||` e constantes nomeados já
        saem embrulhados."""
        if not self.typesys.named_bool(self.pkg.type_of(n)):
            return False
        while n["node"] == "ParenExpr":
            n = n["x"]
        return not (n["node"] == "BinaryExpr" and n["op"] in ("==", "!=", "<", "<=", ">", ">="))

    def cond(self, n, min_prec=0):
        """Expressão Go booleana como `bool` Dart: bool nomeado desembrulha `$b`."""
        if self.flag_object(n):
            return f"{self.expr(n, POSTFIX)}.$b"
        return self.expr(n, min_prec)

    def multi_value(self, n):
        """Expressão única com vários valores como record Dart: `x.(T)` e
        `m[k]` em comma-ok, ou chamada com N resultados."""
        if n["node"] == "TypeAssertExpr":
            return self.asserts.comma_ok_assert(n)
        if self.is_map_index(n):
            return f"{self.expr(n['x'], POSTFIX)}.lookup({self.expr(n['index'])})"
        return self.expr(n)

    def is_pure(self, n):
        """Avaliar n duas vezes dá o mesmo valor e nenhum efeito: constantes,
        identificadores, campos, índices, parênteses e `*p` sobre puros
        (leitura-escrita de `x op= y` sem operador Dart)."""
        if n.get("$value") is not None:
            return True
        k = n["node"]
        if k == "Ident":
            return True
        if k in ("ParenExpr", "SelectorExpr", "StarExpr"):
            return self.is_pure(n["x"])
        if k == "IndexExpr":
            return self.is_pure(n["x"]) and self.is_pure(n["index"])
        if k == "CallExpr" and n["fun"].get("$isType"):  # conversão
            return self.is_pure(n["args"][0])
        return False

    def is_map_index(self, n):
        return n["node"] == "IndexExpr" and self.typesys.underlying(self.pkg.type_of(n["x"]))["kind"] == "map"
