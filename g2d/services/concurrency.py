"""Suspensão direta (M4): canais, `select`, `range` sobre chan. A cor
completa (chamada a função/método colorido, símbolo suspensivo de shim) é a
análise de `g2d/analysis/color.py`; este serviço só sabe reconhecer, num
corpo de função isolado (sem olhar quem ele chama), se ELE MESMO suspende."""

from g2d.engine.behavior import Service
from g2d.model import walk


class Concurrency(Service):
    """Suspensão direta (canais, select, range sobre chan) e utilidades de tipo chan."""

    name = "concurrency"

    def direct_suspend(self, node):
        """A função/método/func literal (sem contar func literals aninhadas)
        suspende diretamente: operação de canal (`ch <- v`, `<-ch`), `select`
        sem `default`, ou `range` sobre chan."""
        for n in walk(node, funclits=False):
            k = n.get("node")
            if k == "SendStmt":
                return True
            if k == "UnaryExpr" and n["op"] == "<-":
                return True
            if k == "SelectStmt" and not self.has_default(n):
                return True
            if k == "RangeStmt" and self.is_chan_range(n):
                return True
        return False

    @staticmethod
    def has_default(select_stmt):
        return any(c["comm"] is None for c in select_stmt["body"]["list"] or [])

    def is_chan_range(self, range_stmt):
        return self.typesys.underlying(self.pkg.type_of(range_stmt["x"]))["kind"] == "chan"
