"""O motor: registra serviços, análises e comportamentos (via plugins) e
despacha a AST Go tipada de um pacote para eles."""

from g2d.engine.behavior import NOT_HANDLED
from g2d.engine.precedence import POSTFIX, UNARY
from g2d.engine.registry import ChainRegistry, HandlerRegistry, ServiceRegistry
from g2d.engine.scope import Facts
from g2d.model import Unsupported


class Engine:
    """Transpila um pacote Go (goast) para uma library Dart.

    Tudo o que o motor sabe fazer vem de plugins (`DEFAULT_PLUGINS`): cada um
    registra serviços, análises e comportamentos. Para injetar um
    comportamento novo, passe um plugin extra:

        Engine(pkg, plugins=[*DEFAULT_PLUGINS, MeuPlugin()]).emit_package()
    """

    def __init__(self, pkg, plugins=None):
        from g2d.behaviors.plugins import DEFAULT_PLUGINS

        self.pkg = pkg
        self.facts = Facts()
        self.scope = None
        self.services = ServiceRegistry()
        self.analyses = []
        self.exprs = HandlerRegistry()
        self.stmts = HandlerRegistry()
        self.builtins = HandlerRegistry()
        self.conversions = ChainRegistry()
        self.type_decls = ChainRegistry()
        self.package_behavior = None
        # Modo coleta (auditoria): lista em vez de None; cada declaração que
        # falha é registrada e a emissão segue para a próxima.
        self.errors = None
        for plugin in DEFAULT_PLUGINS if plugins is None else plugins:
            plugin.install(self)

    # ------------------------------------------------------------ registro
    def register_service(self, service_cls):
        return self.services.register(service_cls(self))

    def register_expr(self, behavior_cls):
        behavior = behavior_cls(self)
        for kind in behavior.kinds:
            self.exprs.register(kind, behavior)
        return behavior

    def register_stmt(self, behavior_cls):
        behavior = behavior_cls(self)
        for kind in behavior.kinds:
            self.stmts.register(kind, behavior)
        return behavior

    def register_builtin(self, behavior_cls):
        behavior = behavior_cls(self)
        self.builtins.register(behavior.name, behavior)
        return behavior

    def register_conversion(self, behavior_cls):
        return self.conversions.register(behavior_cls(self))

    def register_type_decl(self, behavior_cls):
        return self.type_decls.register(behavior_cls(self))

    def register_analysis(self, analysis_cls):
        analysis = analysis_cls(self)
        self.analyses.append(analysis)
        return analysis

    # ------------------------------------------------------------ despacho
    def expr(self, n, min_prec=0):
        """Expressão Dart; entre parênteses se ligar mais fraco que min_prec."""
        text, prec = self.expr_prec(n)
        return f"({text})" if prec < min_prec else text

    def expr_prec(self, n):
        """(texto, precedência). Constantes (`$value`) viram o literal exato
        do go/types antes do despacho, salvo constante nomeada do pacote."""
        literals = self.services["literals"]
        v = n.get("$value")
        if v is not None and not literals.named_const(n):
            text = literals.literal(v, self.pkg.type_of(n))
            return text, (UNARY if text.startswith("-") else POSTFIX + 1)
        result = self.exprs.dispatch(n["node"], n)
        if result is NOT_HANDLED:
            raise Unsupported(f"expr:{n['node']}", f"expressão {n['node']}", n)
        return result

    def stmt(self, s, **kw):
        result = self.stmts.dispatch(s["node"], s, **kw)
        if result is NOT_HANDLED:
            raise Unsupported(f"stmt:{s['node']}", f"statement {s['node']}", s)
        return result

    def block(self, b):
        return ["{"] + [ln for s in b["list"] or [] for ln in self.stmt(s)] + ["}"]

    def builtin(self, n, fun, args):
        if fun["node"] == "SelectorExpr":  # unsafe.Slice, unsafe.String, unsafe.Add...
            name = fun["sel"]["name"]
            raise Unsupported(f"unsafe:{name}", f"unsafe.{name} (sem memória crua fora do dart:ffi)", n)
        name = fun["name"]
        result = self.builtins.dispatch(name, n, args)
        if result is NOT_HANDLED:
            raise Unsupported(f"builtin:{name}", f"builtin {name}", n)
        return result

    def convert(self, n, fun, arg):
        """T(x) em tempo de execução (constantes já vêm dobradas em $value)."""
        from g2d.behaviors.conversions import Conversion

        c = Conversion.of(self, n, fun, arg)
        behavior = self.conversions.find(c)
        if behavior is None:
            raise c.unsupported()
        return behavior.emit(c)

    def guard(self, fn, node, *args):
        """`fn(node, *args)` de uma declaração: um Unsupported sem posição
        ganha a de `node`. Em modo coleta, o erro (ou uma exceção interna,
        como `erro-interno:<Tipo>`) é registrado e a declaração vira []."""
        scope = self.scope
        try:
            return fn(node, *args)
        except Unsupported as e:
            e.locate(node)
            if self.errors is None:
                raise
            self.errors.append(e)
        except Exception as e:  # noqa: BLE001 — só em modo coleta: bug do g2d
            if self.errors is None:
                raise
            self.errors.append(Unsupported.internal(e, node))
        self.scope = scope
        return []

    def emit_package(self):
        """Library Dart (não formatada) do pacote."""
        return self.package_behavior.emit()
