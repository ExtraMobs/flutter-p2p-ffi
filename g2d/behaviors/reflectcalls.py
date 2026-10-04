"""Chamadas do `reflect` cujo tipo o g2d já sabe (M5, decisão D1).

`reflect.TypeOf(x)`/`reflect.ValueOf(x)` com `x` de tipo estático concreto
(não interface, não parâmetro de tipo) têm o tipo do resultado fixo na
compilação: o g2d passa o descritor (`reflect.typeOf$static(x, <RType>)`).
Isso cobre o que o valor Dart não diz sozinho, como o idiom
`reflect.TypeOf((*error)(nil)).Elem()` (ponteiro nil para interface) e
`reflect.ValueOf(&n)`. `reflect.TypeFor[T]()` vira `reflect.typeFor(<RType
de T>)`, inclusive com T parâmetro de tipo (`go.rtOfElem($T)`). Os outros
casos seguem a chamada comum (tipo dinâmico em runtime).
"""

from g2d.engine.behavior import NOT_HANDLED, ExprBehavior
from g2d.engine.precedence import POSTFIX, UNARY


def reflect_func(fun):
    """Nome da função do pacote `reflect` chamada (`reflect.TypeOf`), ou None."""
    if fun["node"] in ("IndexExpr", "IndexListExpr"):
        fun = fun["x"]
    if (fun["node"] == "SelectorExpr" and (fun["x"].get("$obj") or {}).get("kind") == "package"
            and fun["x"]["$obj"].get("pkg") == "reflect"):
        return fun["sel"]["name"]
    return None


class ReflectStaticCall(ExprBehavior):
    """Especializa `CallExpr` de `reflect.TypeOf`/`ValueOf`/`TypeFor`."""

    kinds = ("CallExpr",)

    def emit(self, n):
        name = reflect_func(n["fun"])
        args = n["args"] or []
        if name == "TypeFor":
            inst = self.calls.instantiation(n["fun"])
            if inst is None:
                return NOT_HANDLED
            return f"{self.imports.qualify('reflect', 'typeFor')}({self.reflection.rtype(inst[1][0])})", POSTFIX
        if name not in ("TypeOf", "ValueOf") or len(args) != 1 or n.get("ellipsis") is not None:
            return NOT_HANDLED
        t = self.pkg.type_of(args[0])
        if t is None or t["kind"] in ("tuple", "typeparam") or self.descriptors.has_tparam(t):
            return NOT_HANDLED
        u = self.typesys.underlying(t)
        if u["kind"] == "interface" or (u["kind"] == "basic" and u["name"] == "untyped nil"):
            return NOT_HANDLED
        param = self.pkg.type_at(self.pkg.type_of(n["fun"])["params"][0])
        value = self.values.coerce(args[0], param)
        fn = "typeOf$static" if name == "TypeOf" else "valueOf$static"
        return f"{self.imports.qualify('reflect', fn)}({value}, {self.reflection.rtype(t)})", POSTFIX


class ReflectAsyncCall(ExprBehavior):
    """`v.Call(in)`/`v.CallSlice(in)` de `reflect.Value` num contexto
    `async` (D2): `await v.call$async(in)`, que espera a função chamada se
    ela suspende. Num contexto síncrono fica `call$`, e a função que
    suspende dá panic explícito no runtime."""

    kinds = ("CallExpr",)

    def emit(self, n):
        fun = n["fun"]
        if (fun["node"] != "SelectorExpr" or fun["sel"]["name"] not in ("Call", "CallSlice")
                or self.scope is None or not self.scope.async_ctx or len(n["args"] or []) != 1):
            return NOT_HANDLED
        recv = self.pkg.type_of(fun["x"])
        if recv is None or recv["kind"] != "named" or recv.get("pkg") != "reflect" or recv.get("name") != "Value":
            return NOT_HANDLED
        param = self.pkg.type_at(self.pkg.type_of(fun)["params"][0])
        name = "call$async" if fun["sel"]["name"] == "Call" else "callSlice$async"
        return f"await {self.expr(fun['x'], POSTFIX)}.{name}({self.values.coerce(n['args'][0], param)})", UNARY
