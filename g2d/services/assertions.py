"""Type assertion, comma-ok e testes de type switch."""

from g2d.engine.behavior import Service
from g2d.services.dart_type import DartType


class Assertions(Service):
    """Type assertion, comma-ok e testes de type switch."""

    name = "asserts"

    def assert_parts(self, n):
        """(tipo Dart, kwargs) de `x.(T)`: struct por valor/ponteiro, interface
        ou tipo concreto."""
        t = self.pkg.type_at(n["type"]["$type"])
        u = self.typesys.underlying(t)
        if u["kind"] == "interface":
            return "iface", self.types.dart(t).non_null() if t["kind"] == "named" or u["methods"] else DartType("Object"), t
        if self.typesys.is_value(t):
            return "value", self.types.dart(t), t
        if self.typesys.is_struct_pointer(t):
            return "pointer", self.types.dart(t), t  # T? (o zero do comma-ok é null)
        if t["kind"] == "pointer":
            return "plain", self.types.dart(t), t  # go.Ptr<E>? (nil tipado → null)
        return "plain", self.types.dart(t).non_null(), t

    def comma_ok_assert(self, n):
        """`v, ok := x.(T)` → record (valor, ok)."""
        mode, dt, t = self.assert_parts(n)
        x = self.expr(n["x"])
        if mode == "iface":
            return f"{self.imports.qualify(None, 'tryIface')}<{dt}>({x})"
        struct = {"value": ", struct: true", "pointer": ", struct: false"}.get(mode, "")
        return f"{self.imports.qualify(None, 'tryType')}<{dt}>({x}, {self.types.zero(t)}{struct})"

    def type_test(self, subject, texpr):
        """Teste de um case de type switch sobre a variável `subject`."""
        if texpr["node"] == "Ident" and texpr["name"] == "nil":
            return f"{subject} == null"
        mode, dt, _ = self.assert_parts({"type": texpr})
        if mode == "iface":
            return f"{subject} is {dt}"
        struct = {"value": ", struct: true", "pointer": ", struct: false"}.get(mode, "")
        return f"{self.imports.qualify(None, 'isType')}<{dt}>({subject}{struct})"
