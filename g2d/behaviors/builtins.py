"""Um comportamento por builtin Go."""

from g2d.engine.behavior import BuiltinBehavior
from g2d.engine.precedence import POSTFIX
from g2d.model import Unsupported


class Len(BuiltinBehavior):
    """`len(x)`: slice/array/map/string (string em bytes) → Golang.Int."""

    name = "len"

    def emit(self, n, args):
        return length_of(self, n)


class Cap(BuiltinBehavior):
    """`cap(x)`: slice (capacidade) / array (tamanho) → Golang.Int."""

    name = "cap"

    def emit(self, n, args):
        return length_of(self, n)


def length_of(b, n):
    """`len`/`cap` como Golang.Int; o int Dart vem de Operands.dart_length
    (que também serve índices e contagens sem o embrulho)."""
    d = b.operands.dart_length(n)
    if d is None:
        kind = b.typesys.underlying(b.pkg.type_of(n["args"][0]))["kind"]
        raise Unsupported(f"{n['fun']['name']}:{kind}", f"{n['fun']['name']} de {kind}", n)
    return f"{b.types.golang('Int')}({d})", POSTFIX


class Append(BuiltinBehavior):
    """`append(s, xs...)` → go.Slice.append (growslice do Go)."""

    name = "append"

    def emit(self, n, args):
        s = self.expr(args[0], POSTFIX)
        if n["ellipsis"] is not None:
            if self.typesys.basic(self.pkg.type_of(args[1])) is not None:
                raise Unsupported("append-string", "append([]byte, string...)", n)
            return self.types.wrap(self.pkg.type_of(n), f"{s}.appendSlice({self.expr(args[1])})"), POSTFIX
        et = self.pkg.type_at(self.typesys.underlying(self.pkg.type_of(n))["elem"])
        items = ", ".join(self.values.coerce(a, et) for a in args[1:])
        return self.types.wrap(self.pkg.type_of(n), f"{s}.append([{items}])"), POSTFIX


class Copy(BuiltinBehavior):
    name = "copy"

    def emit(self, n, args):
        if self.typesys.basic(self.pkg.type_of(args[1])) is not None:
            raise Unsupported("copy-string", "copy([]byte, string)", n)
        dst, src = self.expr(args[0], POSTFIX), self.expr(args[1])
        return f"{self.types.golang('Int')}({dst}.copyFrom({src}))", POSTFIX


class Delete(BuiltinBehavior):
    name = "delete"

    def emit(self, n, args):
        return f"{self.expr(args[0], POSTFIX)}.delete({self.expr(args[1])})", POSTFIX


class Min(BuiltinBehavior):
    """`min(x, y, ...)` (Go 1.21) → go.minOf / go.minFloat (NaN e ±0 do Go).
    Só chega aqui com operando não constante (constantes vêm dobradas)."""

    name = "min"
    helper = "min"

    def emit(self, n, args):
        t = self.pkg.type_of(n)
        b = self.typesys.basic(t)
        if b is None or b.cat not in ("wint", "float", "string"):
            cat = b.cat if b else self.typesys.underlying(t)["kind"]
            raise Unsupported(f"{self.name}:{cat}", f"{self.name} de {cat}", n)
        items = ", ".join(self.values.coerce(a, t) for a in args)
        dt = self.types.dart(t)
        if b.cat == "float":
            fn = self.imports.qualify(None, self.helper + "Float")
            return f"{fn}<{dt}>([{items}], (v) => v.toDouble())", POSTFIX
        fn = self.imports.qualify(None, self.helper + "Of")
        return f"{fn}<{dt}>([{items}], (a, b) => a < b)", POSTFIX


class Max(Min):
    name = "max"
    helper = "max"


class Clear(BuiltinBehavior):
    """`clear(m)` esvazia o map; `clear(s)` zera os elementos do slice."""

    name = "clear"

    def emit(self, n, args):
        kind = self.typesys.underlying(self.pkg.type_of(args[0]))["kind"]
        if kind not in ("map", "slice"):
            raise Unsupported(f"clear:{kind}", f"clear de {kind}", n)
        return f"{self.expr(args[0], POSTFIX)}.clear()", POSTFIX


class Make(BuiltinBehavior):
    """`make([]T, n, c)` / `make(map[K]V)`."""

    name = "make"

    def emit(self, n, args):
        t = self.pkg.type_at(args[0]["$type"])
        u = self.typesys.underlying(t)
        if u["kind"] == "slice":
            ln = self.operands.to_int(args[1])
            cp = self.operands.to_int(args[2]) if len(args) > 2 else ln
            return self.types.wrap(t, f"{self.types.dart(u)}.make({ln}, {cp}, {self.descriptors.elem(u['elem'])})"), POSTFIX
        if u["kind"] == "map":
            return self.types.wrap(t, f"{self.types.dart(u)}({self.descriptors.elem(u['elem'])}{self.typesys.map_args(t)})"), POSTFIX
        raise Unsupported(f"make:{u['kind']}", f"make de {u['kind']}", n)


class New(BuiltinBehavior):
    """`new(T)`: struct/array é o próprio objeto; o resto mora numa go.Box."""

    name = "new"

    def emit(self, n, args):
        t = self.pkg.type_at(args[0]["$type"])
        if self.typesys.is_value(t):
            return self.types.zero(t), POSTFIX
        return self.types.box(t, self.types.zero(t))[1], POSTFIX


class PanicBuiltin(BuiltinBehavior):
    name = "panic"

    def emit(self, n, args):
        any_t = {"kind": "interface", "methods": [], "embeddeds": []}
        return f"throw {self.imports.qualify(None, 'Panic')}({self.values.coerce(args[0], any_t)})", 0


class Recover(BuiltinBehavior):
    """`recover()` → go.recover($rd): só a chamada direta pelo defer recupera."""

    name = "recover"

    def emit(self, n, args):
        rd = (self.scope.rd if self.scope else None) or ""
        return f"{self.imports.qualify(None, 'recover')}({rd})", POSTFIX
