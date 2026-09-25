"""Tipos Dart estruturados.

`DartType` é um `str` imutável com estrutura: renderiza o texto Dart (então
f-strings, `join` e chaves de dict continuam funcionando), mas as operações
sobre tipos são estruturais (`nullable`, `non_null`, `as_nullable`,
`with_named`) em vez de manipulação de texto, que quebraria com argumentos
com vírgula, funções aninhadas ou nomes qualificados.
"""


class DartType(str):
    """Um tipo Dart: nominal (`name<args>?`), função (`R Function(A, {N n})?`)
    ou record (`(A, B)`)."""

    def __new__(cls, name=None, args=(), nullable=False, *, returns=None, params=None,
                named=(), record=None):
        if record is not None:
            text = "(" + ", ".join(record) + ")"
        elif params is not None:
            parts = list(params)
            if named:
                parts.append("{" + ", ".join(f"{t} {n}" for n, t in named) + "}")
            text = f"{returns} Function({', '.join(parts)})"
        else:
            text = name + ("<" + ", ".join(args) + ">" if args else "")
        obj = super().__new__(cls, text + ("?" if nullable else ""))
        obj.name, obj.args, obj.nullable = name, tuple(args), nullable
        obj.returns, obj.params, obj.named = returns, (None if params is None else tuple(params)), tuple(named)
        obj.record = None if record is None else tuple(record)
        return obj

    @classmethod
    def function(cls, returns, params, named=(), nullable=False):
        return cls(returns=returns, params=params, named=named, nullable=nullable)

    @classmethod
    def of_record(cls, elems):
        return cls(record=elems)

    @property
    def is_function(self):
        return self.params is not None

    def _copy(self, **changes):
        fields = dict(name=self.name, args=self.args, nullable=self.nullable, returns=self.returns,
                      params=self.params, named=self.named, record=self.record)
        fields.update(changes)
        return DartType(fields.pop("name"), fields.pop("args"), fields.pop("nullable"), **fields)

    def non_null(self):
        return self._copy(nullable=False) if self.nullable else self

    def as_nullable(self):
        return self if self.nullable else self._copy(nullable=True)

    def with_named(self, name, type_):
        """Tipo de função com um parâmetro nomeado a mais (ex. `$rd`)."""
        if not self.is_function:
            raise TypeError(f"{self!s} não é tipo de função")
        return self._copy(named=self.named + ((name, type_),))
