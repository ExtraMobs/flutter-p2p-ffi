"""Registros do motor: comportamentos por chave (cadeia de responsabilidade),
cadeias ordenadas e serviços por nome."""

from g2d.engine.behavior import NOT_HANDLED


class HandlerRegistry:
    """Pilha de comportamentos por chave (tipo de nó, nome de builtin).

    `dispatch` tenta do último registrado para o primeiro; um comportamento
    que devolve NOT_HANDLED passa a vez ao anterior. Assim um plugin
    *substitui* um comportamento (sempre trata) ou o *especializa* (trata só
    o seu caso).
    """

    def __init__(self):
        self._stacks = {}

    def register(self, key, handler):
        self._stacks.setdefault(key, []).append(handler)
        return handler

    def handlers(self, key):
        return list(self._stacks.get(key, ()))

    def __contains__(self, key):
        return bool(self._stacks.get(key))

    def dispatch(self, key, *args, **kw):
        """Resultado do primeiro comportamento que trata; NOT_HANDLED se
        nenhum trata (ou a chave não tem comportamentos)."""
        for handler in reversed(self._stacks.get(key, ())):
            result = handler.emit(*args, **kw)
            if result is not NOT_HANDLED:
                return result
        return NOT_HANDLED


class ChainRegistry:
    """Lista ordenada de comportamentos com `accepts`: vale o último
    registrado que aceita (plugins posteriores têm prioridade)."""

    def __init__(self):
        self._items = []

    def register(self, handler):
        self._items.append(handler)
        return handler

    def find(self, *args):
        for handler in reversed(self._items):
            if handler.accepts(*args):
                return handler
        return None


class ServiceRegistry:
    """Serviços por nome; `replace` injeta outra implementação."""

    def __init__(self):
        self._services = {}

    def register(self, service):
        if service.name in self._services:
            raise KeyError(f"serviço já registrado: {service.name}")
        self._services[service.name] = service
        return service

    def replace(self, service):
        self._services[service.name] = service
        return service

    def __getitem__(self, name):
        return self._services[name]

    def __contains__(self, name):
        return name in self._services
