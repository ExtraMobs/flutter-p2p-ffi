"""Alvos de `break`: laços (break nativo), switches (bloco rotulado) e o
corpo de `range` sobre func (closure passada ao iterador)."""

from dataclasses import dataclass, field

from g2d.engine.behavior import Service


@dataclass
class RangeFuncFrame:
    """Corpo de um `range` sobre func: vira a closure `yield`. `break` e
    `continue` do próprio laço viram `return false/true`; o que sai da
    closure (`return`, laço de fora) grava um código em `state` e é refeito
    depois da chamada (`exits`)."""

    label: str  # rótulo Go do laço (ou None)
    state: str  # variável Dart com o código de saída
    done: str  # a closure já devolveu false (yield depois disso → pânico)
    rv: str  # valores do `return` de dentro
    exits: list = field(default_factory=list)  # [(código, nó Go a refazer fora)]
    inner_labels: set = field(default_factory=set)  # rótulos declarados no corpo

    def exit(self, node):
        self.exits.append((len(self.exits) + 1, node))
        return len(self.exits)


class ControlFlow(Service):
    """Alvos de `break`: laços (break nativo) e switches (bloco rotulado)."""

    name = "control"

    def loop_body(self, body):
        """Corpo de laço: `break` sem rótulo aqui é o break nativo do Dart."""
        self.scope.breaks.append(None)
        try:
            return self.block(body)
        finally:
            self.scope.breaks.pop()

    def switch_label(self):
        """Rótulo do switch corrente para os `break` que o têm como alvo."""
        label = self.names.temp()
        self.scope.breaks.append(label)
        return label

    def close_switch(self, label, lines):
        """Desempilha o rótulo; só rotula o bloco se algum break o usou."""
        self.scope.breaks.pop()
        return ([f"{label}:"] if label in self.scope.used_labels else []) + lines
