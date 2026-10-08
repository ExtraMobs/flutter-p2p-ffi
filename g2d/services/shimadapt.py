"""Valor de classe de shim numa interface gerada (D8).

As classes dos shims são escritas à mão e não declaram as interfaces dos
pacotes do grafo: `return new(bytes.Buffer)` num `(LW, error)`, ou o
`return net.ListenUDP(...)` do `stdnet` do pion num `transport.UDPConn`.
No ponto da conversão (`ValueSemantics.coerce`) o valor entra num
adaptador gerado na library que converte: uma subclasse de `go.ShimIface`
que implementa a interface e repassa cada método ao valor do shim. O
runtime vê através dele (assertion, type switch, `==`, `%T`/`%v`,
`reflect`).

Cor: o método da interface segue o grupo dele; o adaptador liga as formas.
Um método do shim que sempre suspende (`net.UDPConn.ReadFromUDP`, o `Read`
das conexões) torna `async` o método da interface
(`color.summarize` → `suspending`).
"""

from g2d.config import STDLIB_SHIMS
from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.services.concurrency import SUSPENDING_FUNCS
from g2d.services.dualio import ASYNC_SHIM_METHODS, dual_capable
from g2d.services.naming import member_name


def shim_type(pkg, t):
    """O tipo nomeado de pacote com shim (não interface) de t ou de `*t`, ou None."""
    t = pkg.type_at(t)
    if t["kind"] == "pointer":
        t = pkg.type_at(t["elem"])
    if t["kind"] != "named" or t["pkg"] not in STDLIB_SHIMS or t.get("args"):
        return None
    return None if pkg.type_at(t["underlying"])["kind"] == "interface" else t


def target_ref(engine, t):
    """A interface t é gerada e tem métodos: nomeada não genérica de pacote
    do grafo (ou do próprio pacote, como o `main`) ou anônima que não é uma
    do runtime. O shim não a declara."""
    pkg, t = engine.pkg, engine.pkg.type_at(t)
    u = engine.services["typesys"].underlying(t)
    if u["kind"] != "interface" or not u["methods"]:
        return False
    if t["kind"] == "named":
        return bool(t["pkg"]) and not t.get("args") and (t["pkg"] == pkg.path or not is_std(t["pkg"]))
    return engine.services["goinfo"].runtime_iface(u) is None


def suspending(engine, src, target):
    """Chaves de cor dos métodos de `target` que suspendem quando o valor
    é do tipo do shim `src` (o shim só tem a forma `Future`)."""
    s = shim_type(engine.pkg, src)
    if s is None or not target_ref(engine, target):
        return set()
    conc = engine.services["concurrency"]
    out = set()
    for m in conc.typesys.underlying(engine.pkg.type_at(target))["methods"]:
        k = ("m", s["pkg"], s["name"], m["name"])
        if k in SUSPENDING_FUNCS or k in ASYNC_SHIM_METHODS:
            out.add(conc.iface_key(target, m["name"]))
    return out


class ShimAdapters(Service):
    """Adaptadores `go.ShimIface` da library: um por (interface, tipo do shim)."""

    name = "shimadapt"

    def __init__(self, engine):
        super().__init__(engine)
        self.decls = []
        self.declared = {}  # (tipo Dart da interface, tipo Dart do shim) → classe

    def needs(self, src, target):
        return (src is not None and target is not None and shim_type(self.pkg, src) is not None
                and target_ref(self.engine, target))

    def shim_case(self, t):
        """`case T:` de type switch que um valor de shim satisfaz sem ser o
        adaptador: tipo do shim, interface do shim ou `error`."""
        t = self.pkg.type_at(t)
        if shim_type(self.pkg, t) is not None or self.typesys.is_universe(t, "error"):
            return True
        return t["kind"] == "named" and t["pkg"] in STDLIB_SHIMS

    def wrap(self, text, src, target):
        """`text` (valor do shim, já com a sentinela do nil) visto como a
        interface gerada `target`."""
        return f"{self.adapter(src, target)}({text})"

    def adapter(self, src, target):
        s = shim_type(self.pkg, src)
        iface = self.types.dart(target).non_null()
        shim = self.types.dart(src).non_null()
        key = (str(iface), str(shim))
        if key in self.declared:
            return self.declared[key]
        cls = "_$Shim$" + "$".join(x.split(".")[-1] for x in key)
        self.declared[key] = cls
        go_shim = self.goinfo.go_type_name(self.pkg.type_at(src))
        lines = ["", f"/// `{go_shim}` do shim visto como `{self.goinfo.go_type_name(self.pkg.type_at(target))}`.",
                 f"final class {cls} extends {self.imports.qualify(None, 'ShimIface')}<{shim}> implements {iface} {{",
                 f"{cls}(super.$v);"]
        for m in self.typesys.underlying(self.pkg.type_at(target))["methods"]:
            sig = self.pkg.type_at(m["type"])
            params = ", ".join(f"{self.types.dart(p)} p{i}" for i, p in enumerate(sig["params"]))
            args = ", ".join(f"p{i}" for i in range(len(sig["params"])))
            ikey = self.concurrency.iface_key(target, m["name"])
            skey = ("m", s["pkg"], s["name"], m["name"])
            name = member_name(m["name"])
            if skey in SUSPENDING_FUNCS:  # o shim só tem a forma `Future`
                sync_body, async_body = f"{self.imports.qualify(None, 'syncOfAsync')}('{s['name']}.{m['name']}')", f"$v.{name}({args})"
            elif skey in ASYNC_SHIM_METHODS or dual_capable(skey):  # `m` e `m$async`
                sync_body, async_body = f"$v.{name}({args})", f"$v.{member_name(m['name'] + '$async')}({args})"
            else:
                sync_body, async_body = f"$v.{name}({args})", None
            members = self.dualio.members(ikey, m["name"], sig)
            for i, (dn, ret) in enumerate(members):
                is_async = i == 1 or (len(members) == 1 and self.concurrency.is_async(ikey))
                if not is_async:
                    body = f"=> {sync_body};"
                elif async_body is not None:
                    body = f"=> {async_body};"
                else:
                    body = f"async => {sync_body};"
                lines += ["@override", f"{ret} {dn}({params}) {body}"]
        self.decls += lines + ["}"]
        return cls
