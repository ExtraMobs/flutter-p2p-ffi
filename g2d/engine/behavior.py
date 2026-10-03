"""Classes pais do motor.

- `Component`: tudo que roda dentro do motor (acesso ao pacote, fatos,
  escopo da função corrente e atalhos para os serviços e o dispatch).
- `Service`: responsabilidade compartilhada, registrada por nome e
  substituível (`engine.services.replace(...)`).
- `Behavior` e subclasses: o que o motor despacha (expressões, statements,
  declarações de tipo, builtins, conversões).
- `Analysis`: pré-passo sobre as declarações do pacote (preenche `facts`).
- `Plugin`: instala comportamentos, serviços e análises num motor.
"""

from abc import ABC, abstractmethod


class NotHandled:
    """Devolvido por um comportamento que não trata o caso: o registro tenta
    o comportamento registrado antes dele (cadeia de responsabilidade)."""

    def __repr__(self):
        return "NotHandled"


NOT_HANDLED = NotHandled()


class Component:
    """Base de serviços, comportamentos e análises."""

    def __init__(self, engine):
        self.engine = engine

    # --- contexto
    @property
    def pkg(self):
        return self.engine.pkg

    @property
    def facts(self):
        return self.engine.facts

    @property
    def scope(self):
        """Estado da função Go sendo emitida (FunctionScope) ou None."""
        return self.engine.scope

    @scope.setter
    def scope(self, value):
        self.engine.scope = value

    # --- serviços (resolvidos na hora: podem ser substituídos por plugins)
    def service(self, name):
        return self.engine.services[name]

    imports = property(lambda self: self.service("imports"))
    names = property(lambda self: self.service("names"))
    typesys = property(lambda self: self.service("typesys"))
    types = property(lambda self: self.service("types"))
    descriptors = property(lambda self: self.service("descriptors"))
    values = property(lambda self: self.service("values"))
    literals = property(lambda self: self.service("literals"))
    goinfo = property(lambda self: self.service("goinfo"))
    operands = property(lambda self: self.service("operands"))
    calls = property(lambda self: self.service("calls"))
    asserts = property(lambda self: self.service("asserts"))
    control = property(lambda self: self.service("control"))
    functions = property(lambda self: self.service("functions"))
    vars = property(lambda self: self.service("vars"))
    promoter = property(lambda self: self.service("promoter"))
    concurrency = property(lambda self: self.service("concurrency"))
    evalorder = property(lambda self: self.service("evalorder"))
    dualio = property(lambda self: self.service("dualio"))

    # --- despacho
    def expr(self, n, min_prec=0):
        return self.engine.expr(n, min_prec)

    def expr_prec(self, n):
        return self.engine.expr_prec(n)

    def stmt(self, s, **kw):
        return self.engine.stmt(s, **kw)

    def block(self, b):
        return self.engine.block(b)


class Service(Component):
    """Responsabilidade compartilhada. `name` é a chave no ServiceRegistry."""

    name = None


class Behavior(Component, ABC):
    """Comportamento despachado pelo motor."""


class ExprBehavior(Behavior):
    """Expressão Go → (texto Dart, precedência). `kinds` = nós da AST Go."""

    kinds = ()

    @abstractmethod
    def emit(self, n):
        ...


class StmtBehavior(Behavior):
    """Statement Go → linhas Dart. `kinds` = nós da AST Go."""

    kinds = ()

    @abstractmethod
    def emit(self, s, **kw):
        ...


class TypeDeclBehavior(Behavior):
    """Declaração de tipo nomeado; escolhida pelo primeiro `accepts` (do
    último registrado para o primeiro)."""

    @abstractmethod
    def accepts(self, t, u):
        ...

    @abstractmethod
    def emit(self, spec, name, t, u, tidx):
        ...


class BuiltinBehavior(Behavior):
    """Builtin Go (`len`, `append`...) → (texto Dart, precedência)."""

    name = None

    @abstractmethod
    def emit(self, n, args):
        ...


class ConversionBehavior(Behavior):
    """Conversão `T(x)` em tempo de execução; escolhida pelo primeiro
    `accepts` (do último registrado para o primeiro)."""

    @abstractmethod
    def accepts(self, c):
        ...

    @abstractmethod
    def emit(self, c):
        ...


class Analysis(Component, ABC):
    """Pré-passo sobre as declarações do pacote; grava em `engine.facts`."""

    @abstractmethod
    def run(self, decls):
        ...


class Plugin(ABC):
    """Conjunto coeso de comportamentos/serviços/análises instalável."""

    @abstractmethod
    def install(self, engine):
        ...
