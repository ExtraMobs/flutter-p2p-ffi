"""Type assertion, comma-ok e testes de type switch."""

from g2d.engine.behavior import Service
from g2d.services.dart_type import DartType


class Assertions(Service):
    """Type assertion, comma-ok e testes de type switch."""

    name = "asserts"

    def assert_parts(self, n):
        """(tipo Dart, kwargs) de `x.(T)`: struct por valor/ponteiro, interface,
        tipo func sem nome (exato, via `go.Func`) ou tipo concreto."""
        t = self.pkg.type_at(n["type"]["$type"])
        u = self.typesys.underlying(t)
        if u["kind"] == "interface":
            return "iface", self.types.dart(t).non_null() if t["kind"] == "named" or u["methods"] else DartType("Object"), t
        if self.typesys.is_value(t):
            return "value", self.types.dart(t), t
        if self.typesys.is_struct_pointer(t):
            return "pointer", self.types.dart(t), t  # T? (o zero do comma-ok é null)
        if u["kind"] == "func" and t["kind"] != "named":
            # F? (o zero do comma-ok é null); comparação exata pelo nome Go do
            # tipo (`go.Func`), não `is` (o Dart testa subtipo entre funcs).
            return "func", self.types.dart(t), t
        if t["kind"] == "pointer":
            return "plain", self.types.dart(t), t  # go.Ptr<E>? (o zero do comma-ok é null)
        return "plain", self.types.dart(t).non_null(), t

    @staticmethod
    def struct_flag(mode):
        """Argumento `struct:` dos helpers do runtime (`tryType`, `isType`...):
        struct por valor ou ponteiro para struct."""
        return {"value": ", struct: true", "pointer": ", struct: false"}.get(mode, "")

    def comma_ok_assert(self, n):
        """`v, ok := x.(T)` → record (valor, ok)."""
        mode, dt, t = self.assert_parts(n)
        x = self.expr(n["x"])
        if mode == "iface":
            return f"{self.imports.qualify(None, 'tryIface')}<{dt}>({x})"
        if mode == "func":
            sig = self.goinfo.go_type_name(t)
            return f"{self.imports.qualify(None, 'tryFunc')}<{dt}>({x}, {self.types.zero(t)}, '{sig}')"
        struct = self.struct_flag(mode)
        return f"{self.imports.qualify(None, 'tryType')}<{dt}>({x}, {self.types.zero(t)}{struct})"

    def type_test(self, subject, texpr):
        """Teste de um case de type switch sobre a variável `subject`."""
        if texpr["node"] == "Ident" and texpr["name"] == "nil":
            return f"{subject} == null"
        mode, dt, t = self.assert_parts({"type": texpr})
        if mode == "iface":
            return f"{subject} is {dt}"
        if mode == "func":
            sig = self.goinfo.go_type_name(t)
            return f"{self.imports.qualify(None, 'isFuncType')}<{dt}>({subject}, '{sig}')"
        struct = self.struct_flag(mode)
        return f"{self.imports.qualify(None, 'isType')}<{dt}>({subject}{struct})"
