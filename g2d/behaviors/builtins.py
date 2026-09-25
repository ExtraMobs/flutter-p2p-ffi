"""Um comportamento por builtin Go."""

from g2d.engine.behavior import BuiltinBehavior
from g2d.engine.precedence import POSTFIX
from g2d.model import Unsupported


class Len(BuiltinBehavior):
    """`len(x)`: slice/array/map/string (string em bytes) → Golang.Int."""

    name = "len"

    def emit(self, n, args):
        u = self.typesys.underlying(self.pkg.type_of(args[0]))
        if u["kind"] in ("slice", "array", "map", "basic"):
            return f"{self.types.golang('Int')}({self.expr(args[0], POSTFIX)}.length)", POSTFIX
        raise Unsupported(f"len de {u['kind']}", n)


class Cap(BuiltinBehavior):
    name = "cap"

    def emit(self, n, args):
        u = self.typesys.underlying(self.pkg.type_of(args[0]))
        attr = "length" if u["kind"] == "array" else "capacity"
        return f"{self.types.golang('Int')}({self.expr(args[0], POSTFIX)}.{attr})", POSTFIX


class Append(BuiltinBehavior):
    """`append(s, xs...)` → go.Slice.append (growslice do Go)."""

    name = "append"

    def emit(self, n, args):
        s = self.expr(args[0], POSTFIX)
        if n["ellipsis"] is not None:
            if self.typesys.basic(self.pkg.type_of(args[1])) is not None:
                raise Unsupported("append([]byte, string...)", n)
            return self.types.wrap(self.pkg.type_of(n), f"{s}.appendSlice({self.expr(args[1])})"), POSTFIX
        et = self.pkg.type_at(self.typesys.underlying(self.pkg.type_of(n))["elem"])
        items = ", ".join(self.values.coerce(a, et) for a in args[1:])
        return self.types.wrap(self.pkg.type_of(n), f"{s}.append([{items}])"), POSTFIX


class Copy(BuiltinBehavior):
    name = "copy"

    def emit(self, n, args):
        if self.typesys.basic(self.pkg.type_of(args[1])) is not None:
            raise Unsupported("copy([]byte, string)", n)
        dst, src = self.expr(args[0], POSTFIX), self.expr(args[1])
        return f"{self.types.golang('Int')}({dst}.copyFrom({src}))", POSTFIX


class Delete(BuiltinBehavior):
    name = "delete"

    def emit(self, n, args):
        return f"{self.expr(args[0], POSTFIX)}.delete({self.expr(args[1])})", POSTFIX


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
        raise Unsupported(f"make de {u['kind']}", n)


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
