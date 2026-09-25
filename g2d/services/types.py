"""Mapeamento de tipos Go → tipos Dart (e zero values)."""

from g2d.config import GOLANG
from g2d.engine.behavior import Service
from g2d.model import Unsupported
from g2d.services.naming import type_name


class TypeMapper(Service):
    """Converte descritores da typeTable em tipos Dart.

    Nomes de outros pacotes passam pela ImportTable (que registra o import);
    descritores `go.Elem` vêm do DescriptorRegistry.
    """

    name = "types"

    def dart(self, index_or_desc):
        t = self.pkg.type_at(index_or_desc) if isinstance(index_or_desc, int) else index_or_desc
        k = t["kind"]
        if k == "basic":
            b = self.typesys.basic(t)
            if b.cat == "bool":
                return b.cat
            if b.cat == "nil":
                return "Null"
            return self.golang(b.cls)
        if k == "named":
            if t["pkg"] == "" and t["name"] == "error":
                return self.imports.qualify(None, "GoError") + "?"
            name = self.imports.qualify(t["pkg"], type_name(t["name"]))
            if t.get("args"):
                name += "<" + ", ".join(self.dart(a) for a in t["args"]) + ">"
            return name + "?" if self.nilable(t) else name
        if k == "pointer":
            elem = self.pkg.type_at(t["elem"])
            if self.typesys.is_value(elem):
                return self.dart(elem) + "?"  # struct/array é o próprio endereço
            return f"{self.imports.qualify(None, 'Ptr')}<{self.dart(elem)}>?"
        if k == "slice":
            return f"{self.imports.qualify(None, 'Slice')}<{self.dart(t['elem'])}>"
        if k == "array":
            return f"{self.imports.qualify(None, 'GoArray')}<{self.dart(t['elem'])}>"
        if k == "map":
            key = self.pkg.type_at(t["key"])
            if key["kind"] == "pointer" and self.typesys.is_struct_pointer(key):
                raise Unsupported("map com chave ponteiro-para-struct")
            return f"{self.imports.qualify(None, 'GoMap')}<{self.dart(key)}, {self.dart(t['elem'])}>"
        if k == "interface":
            if not t["methods"] and not t["embeddeds"]:
                return "Object?"
            raise Unsupported("interface anônima")
        if k == "func":
            return self.func_type(t) + "?"
        if k == "tuple":
            return self.results(t["elems"])
        if k == "typeparam":
            return t["name"]
        raise Unsupported(f"tipo {k}")

    def cls(self, t):
        """Classe Dart de um tipo básico ou nomeado sobre básico (construtores
        `C(v)`, `C.fromBigInt`, `C.new`)."""
        t = self.pkg.type_at(t) if isinstance(t, int) else t
        if t["kind"] == "named":
            return self.dart(t)
        return self.golang(self.typesys.basic(t).cls)

    def golang(self, cls):
        """Nome qualificado de uma classe de fixed_types (registra o import)."""
        return self.imports.qualify(GOLANG, cls)

    def results(self, elems):
        if not elems:
            return "void"
        if len(elems) == 1:
            return self.dart(elems[0])
        return "(" + ", ".join(self.dart(e) for e in elems) + ")"

    def func_type(self, t):
        # Variádico ...T já vem como []T na assinatura → Slice<T>.
        params = [self.dart(p) for p in t["params"]]
        return f"{self.results(t['results'])} Function({', '.join(params)})"

    def nilable(self, t):
        """Tipos Go cujo zero value é nil e que mapeiam para tipo Dart anulável."""
        return self.typesys.underlying(t)["kind"] in ("interface", "pointer", "func")

    def zero(self, index_or_desc):
        """Expressão Dart do zero value do tipo."""
        t = self.pkg.type_at(index_or_desc) if isinstance(index_or_desc, int) else index_or_desc
        u = self.typesys.underlying(t)
        k = u["kind"]
        if k == "basic":
            b = self.typesys.basic(u)
            if b.cat == "bool":
                return "false"
            if b.cls:
                return self.cls(t) + "()"
        if k in ("interface", "pointer", "func"):
            return "null"
        if k == "struct" and t["kind"] == "named":
            # Struct genérica: o construtor recebe os dicionários dos argumentos.
            dicts = ", ".join(self.descriptors.elem(a) for a in t.get("args") or [])
            return f"{self.dart(t)}({dicts})"
        if k == "typeparam":
            return f"${t['name']}.zero()"  # dicionário do parâmetro de tipo
        if k == "array":
            return f"{self.dart(u)}.zero({u['len']}, {self.descriptors.elem(u['elem'])})"
        if k in ("slice", "map"):  # nil
            return f"{self.dart(t)}.nil({self.descriptors.elem(u['elem'])})"
        raise Unsupported(f"zero value de {k}")
