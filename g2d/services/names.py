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
            raise Unsupported("temp-pacote", "temporário em inicializador de nível de pacote")
        self.scope.temps += 1
        return f"$t{self.scope.temps}"

    def top_name(self, go_name, kind):
        if kind == "func" and go_name == "main" and self.pkg.name == "main":
            return "main"
        return member_name(go_name)

    def boxed(self, obj):
        """Variável que mora num go.Box: endereço tomado no pacote, ou var
        exportada de pacote importável e tipo não-valor (outro pacote pode
        tomar `&a.X`; o dono não tem como saber)."""
        if obj.get("kind") != "var":
            return False
        if obj.get("pkg") == self.pkg.path and obj.get("decl") in self.facts.boxed:
            return True
        return (bool(obj.get("top")) and self.typesys.exported(obj["pkg"], obj["name"])
                and not self.typesys.is_value(self.pkg.type_at(obj["type"])))

    def box_suffix(self, obj):
        """Variável em go.Box: acesso via .value."""
        return ".value" if self.boxed(obj) else ""

    def box_name(self, obj):
        """Nome Dart da caixa (go.Box) de uma variável com `&x`."""
        if obj.get("top"):
            return self.top_name(obj["name"], obj["kind"])
        return self.scope.locals[obj["decl"]]

    def local_decl(self, ident, t, init):
        """Declaração de uma variável local Go nova (com caixa se `&x`)."""
        name = self.declare_local(ident)
        dt = self.types.dart(t)
        if ident["$obj"]["decl"] in self.facts.boxed:
            box_t, box = self.types.box(t, init)
            return f"final {box_t} {name} = {box};"
        return f"{dt} {name} = {init};"
