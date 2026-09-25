"""Nomes Dart de variáveis locais e de pacote (escopo, temporários, caixas)."""

from g2d.engine.behavior import Service
from g2d.model import Unsupported
from g2d.services.naming import local_name, member_name


class Naming(Service):
    """Nomes Dart de variáveis locais e de pacote (escopo, temporários, caixas)."""

    name = "names"

    def declare_local(self, ident):
        """Registra uma variável local nova; renomeia se o nome já foi usado
        na função (Dart proíbe referenciar o nome externo no inicializador,
        ex. `x := x`) ou colide com um nome de nível de library."""
        obj = ident["$obj"]
        base = local_name(obj["name"])
        name, n = base, 0
        while name in self.scope.used or name in self.facts.top_names:
            n += 1
            name = f"{base}${n}"
        self.scope.used.add(name)
        self.scope.locals[obj["decl"]] = name
        return name

    def temp(self):
        if self.scope is None:
            raise Unsupported("temporário em inicializador de nível de pacote")
        self.scope.temps += 1
        return f"$t{self.scope.temps}"

    def top_name(self, go_name, kind):
        if kind == "func" and go_name == "main" and self.pkg.name == "main":
            return "main"
        return member_name(go_name)

    def box_suffix(self, obj):
        """Variável que mora num go.Box (endereço tomado): acesso via .value."""
        return ".value" if obj.get("decl") in self.facts.boxed and obj.get("pkg") == self.pkg.path else ""

    def local_decl(self, ident, t, init):
        """Declaração de uma variável local Go nova (com caixa se `&x`)."""
        name = self.declare_local(ident)
        dt = self.types.dart(t)
        if ident["$obj"]["decl"] in self.facts.boxed:
            box = self.imports.qualify(None, "Box")
            return f"final {box}<{dt}> {name} = {box}<{dt}>({init});"
        return f"{dt} {name} = {init};"
