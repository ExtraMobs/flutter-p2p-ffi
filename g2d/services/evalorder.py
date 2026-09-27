"""Ordem de avaliação do gc: numa lista de operandos (argumentos de chamada,
elementos de literal composto, lado direito de atribuição múltipla,
operandos de binário), a spec só fixa a ordem das chamadas (esquerda →
direita); o gc lê os operandos "simples" (variável, campo, índice, deref)
**depois** de todas as chamadas da lista, não na posição em que aparecem
(TODO/P1-construcao-ordem-avaliacao.md; regra observada em
docs/mapping-spec.md)."""

from g2d.engine.behavior import Service


class EvalOrder(Service):
    """Reescreve uma lista de nós Go extraindo as chamadas reais em
    temporários (na ordem em que aparecem, esquerda → direita) quando a
    lista tem pelo menos uma chamada e um operando que uma delas poderia
    alterar; senão devolve a lista intacta (sem custo, sem golden novo)."""

    name = "evalorder"

    def gather(self, nodes):
        """`nodes` na ordem de avaliação (argumentos, elementos, resultados,
        os dois operandos de um binário...). Devolve `(calls, rewritten,
        risky)`: `calls` é `[(temp, nó da chamada), ...]` na ordem
        esquerda → direita das chamadas encontradas; `rewritten` tem o
        mesmo tamanho de `nodes`, com cada chamada substituída por um
        `G2DTemp` que referencia o temporário; `risky` diz se sobrou, em
        algum item, um operando simples (variável, campo, índice ou deref)
        que uma dessas chamadas poderia ter alterado — só nesse caso vale a
        pena usar `rewritten` (ver `wrap`/`pre`)."""
        if self.scope is None:  # inicializador de pacote: sem temporário
            return [], list(nodes), False
        calls, risky = [], False
        rewritten = []
        for n in nodes:
            r, has_risk = self._walk(n, calls)
            rewritten.append(r)
            risky = risky or has_risk
        return calls, rewritten, risky

    def wrap(self, calls, text):
        """`text` (já montado com os temporários de `calls`) embrulhado num
        switch expression que os liga, na ordem — mesmo truque do `f(g())`
        (CallExpr): funciona em qualquer lugar de expressão, sem precisar
        de um statement por fora. `calls` vazio devolve `text` intacto."""
        if not calls:
            return text
        if len(calls) == 1:
            tmp, node = calls[0]
            return f"(switch ({self.expr(node)}) {{ final {tmp} => {text} }})"
        scrutinee = ", ".join(self.expr(node) for _, node in calls)
        pattern = ", ".join(f"final {tmp}" for tmp, _ in calls)
        return f"(switch (({scrutinee})) {{ ({pattern}) => {text} }})"

    def pre(self, calls):
        """`calls` como declarações de statement (`final t = chamada;`),
        para quem já está montando uma lista de linhas (atribuição,
        return) e pode simplesmente declarar os temporários antes."""
        return [f"final {tmp} = {self.expr(node)};" for tmp, node in calls]

    # ------------------------------------------------------------ percurso
    def _walk(self, n, calls):
        """(nó reescrito, achou operando arriscado?). Desce por combinadores
        puros — parênteses, unário (exceto `&`, que tem lógica própria),
        binário (não pelo lado direito de `&&`/`||`: curto-circuito),
        deref, índice, slicing, seletor de campo — e pára em: chamada real
        (vira temporário; conversão/builtin só repassa para os próprios
        argumentos, que continuam podendo ter chamadas dentro, ex.
        `int64(bump())`), literal composto e literal de função (cada um
        cuida da própria ordem quando emitido)."""
        if n.get("$value") is not None:  # constante: nunca tem chamada nem risco
            return n, False
        k = n["node"]
        if k == "ParenExpr":
            x, r = self._walk(n["x"], calls)
            return dict(n, x=x), r
        if k == "UnaryExpr":
            if n["op"] == "&":  # endereço: lógica própria (address_of), não mexe
                return n, False
            x, r = self._walk(n["x"], calls)
            return dict(n, x=x), r
        if k == "StarExpr":
            x, _ = self._walk(n["x"], calls)
            return dict(n, x=x), True
        if k == "BinaryExpr":
            x, rx = self._walk(n["x"], calls)
            if n["op"] in ("&&", "||"):
                return dict(n, x=x), rx  # y só roda se preciso: fica intacto
            y, ry = self._walk(n["y"], calls)
            return dict(n, x=x, y=y), rx or ry
        if k == "IndexExpr":
            x, _ = self._walk(n["x"], calls)
            i, _ = self._walk(n["index"], calls)
            return dict(n, x=x, index=i), True
        if k == "SliceExpr":
            x, r = self._walk(n["x"], calls)
            out = dict(n, x=x)
            for key in ("low", "high", "max"):
                if n.get(key) is not None:
                    out[key], _ = self._walk(n[key], calls)
            return out, True
        if k == "SelectorExpr":
            xobj = n["x"].get("$obj") if n["x"]["node"] == "Ident" else None
            if xobj and xobj.get("kind") == "package":
                sel_obj = n["sel"].get("$obj") or {}
                return n, sel_obj.get("kind") == "var"  # pkg.Var: global, arriscado
            x, rx = self._walk(n["x"], calls)
            info = n.get("$sel")
            risky = rx or (info is not None and info["kind"] == "field")
            return dict(n, x=x), risky
        if k == "CallExpr":
            fun = n["fun"]
            if fun.get("$isType") or fun.get("$builtin"):
                risky, args = False, []
                for a in n["args"] or []:
                    a2, r2 = self._walk(a, calls)
                    args.append(a2)
                    risky = risky or r2
                return dict(n, args=args), risky
            tmp = self.names.temp()
            calls.append((tmp, n))
            return {"node": "G2DTemp", "text": tmp, "$type": n.get("$type")}, False
        if k == "Ident":
            obj = n.get("$obj")
            return n, bool(obj and obj.get("kind") == "var")
        return n, False  # folha neutra: CompositeLit, FuncLit, TypeAssertExpr...
