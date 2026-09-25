"""Alvos de `break`: laços (break nativo) e switches (bloco rotulado)."""

from g2d.engine.behavior import Service


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
