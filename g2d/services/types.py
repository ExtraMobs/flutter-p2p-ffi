"""Mapeamento de tipos Go → tipos Dart (e zero values)."""

from g2d.config import GOLANG, SHIM_TYPES
from g2d.engine.behavior import Service
from g2d.model import Unsupported
from g2d.services.dart_type import DartType
from g2d.services.naming import type_name


class TypeMapper(Service):
    """Converte descritores da typeTable em tipos Dart.

    Nomes de outros pacotes passam pela ImportTable (que registra o import);
    descritores `go.Elem` vêm do DescriptorRegistry.
    """

    name = "types"

    def __init__(self, engine):
        super().__init__(engine)
        self.synthetics = {}  # índice da typeTable → nome Go da classe anônima

    def dart(self, index_or_desc):
        t = self.pkg.type_at(index_or_desc)
        k = t["kind"]
        if k == "basic":
            b = self.typesys.basic(t)
            if b.cat == "bool":
                return DartType("bool")
            if b.cat == "nil":
                return DartType("Null")
            return DartType(self.golang(b.cls))
        if k == "named":
            if self.typesys.is_universe(t, "error"):
                return DartType(self.imports.qualify(None, "GoError"), nullable=True)
            go_name = self.facts.local_types.get(id(t), t["name"])
            shim = SHIM_TYPES.get((t["pkg"], t["name"]))
            name = self.imports.qualify(t["pkg"], shim or type_name(go_name))
            args = tuple(self.dart(a) for a in self.typesys.type_args(t))
            return DartType(name, args, nullable=self.nilable(t))
        if k == "pointer":
            elem = self.pkg.type_at(t["elem"])
            if self.typesys.is_value(elem):
                return self.dart(elem).as_nullable()  # struct/array é o próprio endereço
            if self.typesys.ptr_class(elem):
                return self.ptr_view(elem).as_nullable()
            return DartType(self.imports.qualify(None, "Ptr"), (self.dart(elem),), nullable=True)
        if k == "slice":
            return DartType(self.imports.qualify(None, "Slice"), (self.dart(t["elem"]),))
        if k == "array":
            return DartType(self.imports.qualify(None, "GoArray"), (self.dart(t["elem"]),))
        if k == "map":
            return DartType(self.imports.qualify(None, "GoMap"), (self.dart(t["key"]), self.dart(t["elem"])))
        if k == "chan":
            return DartType(self.imports.qualify(None, "Chan"), (self.dart(t["elem"]),), nullable=True)
        if k == "interface":
            if not t["methods"] and not t["embeddeds"]:
                return DartType("Object", nullable=True)
            return DartType(self.synthetic(t, "anonIface"), nullable=True)
        if k == "struct":
            if not t["fields"]:
                # struct{}: o mesmo tipo em qualquer pacote (e nos shims, ex.
                # `context.Context.Done()`), uma classe só no runtime.
                return DartType(self.imports.qualify(None, "EmptyStruct"))
            return DartType(self.synthetic(t, "anon"))
        if k == "func":
            return self.func_type(t).as_nullable()
        if k == "tuple":
            return self.results(t["elems"])
        if k == "typeparam":
            return DartType(t["name"])
        raise Unsupported(f"tipo:{k}", f"tipo {k}")

    def cls(self, t):
        """Classe Dart de um tipo básico ou nomeado sobre básico (construtores
        `C(v)`, `C.fromBigInt`, `C.new`)."""
        t = self.pkg.type_at(t)
        if t["kind"] == "named":
            return self.dart(t)
        return self.golang(self.typesys.basic(t).cls)

    def synthetic(self, t, prefix):
        """Classe sintética de struct/interface anônima: uma por tipo (a
        typeTable já deduplica por identidade), emitida no fim da library."""
        idx = self.typesys.index_of(t)
        return type_name(self.synthetics.setdefault(idx, f"{prefix}${idx}"))

    def wrap(self, t, text):
        """Valor do subjacente (go.Slice, go.GoMap, função) visto como o tipo
        nomeado t, se t for classe gerada sobre ele (mesmo armazenamento)."""
        if t["kind"] == "typeparam" and self.typesys.underlying(t)["kind"] != "typeparam":
            return f"{self.descriptors.elem(t)}.rewrapOf({text})"  # S ~[]E
        if not self.typesys.named_composite(t):
            return text
        # Genérico (`Set[string]`): os dicionários vêm antes, como nas structs.
        dicts = "".join(f"{self.descriptors.elem(a)}, " for a in self.typesys.type_args(t))
        return f"{self.dart(t)}({dicts}{text})"

    def box(self, t, init):
        """(tipo Dart, expressão) da caixa de uma variável com `&x`; `*N` com
        métodos é `N$Ptr` sobre a go.Box."""
        box = self.imports.qualify(None, "Box")
        dt = self.dart(t)
        text = f"{box}<{dt}>({init})"
        if self.typesys.ptr_class(t):
            pv = self.ptr_view(t)
            return pv, f"{pv}({text})"
        return f"{box}<{dt}>", text

    def ptr_view(self, t):
        """`N$Ptr` (com os argumentos de tipo de N, se genérico)."""
        dt = self.dart(t)
        return DartType(dt.name + "$Ptr", dt.args)

    def golang(self, cls):
        """Nome qualificado de uma classe de fixed_types (registra o import)."""
        return self.imports.qualify(GOLANG, cls)

    def results(self, elems):
        if not elems:
            return DartType("void")
        if len(elems) == 1:
            return self.dart(elems[0])
        return DartType.of_record([self.dart(e) for e in elems])

    def func_type(self, t):
        # Variádico ...T já vem como []T na assinatura → Slice<T>.
        return DartType.function(self.results(t["results"]), [self.dart(p) for p in t["params"]])

    def nilable(self, t):
        """Tipos Go cujo zero value é nil e que mapeiam para tipo Dart anulável."""
        # Tipo nomeado sobre func é uma classe (nil = `$f` nulo), não anulável.
        return (self.typesys.underlying(t)["kind"] in ("interface", "pointer", "func", "chan")
                and not self.typesys.named_func(t))

    def future(self, t):
        """`Future<T>` (funções coloridas `async` pela análise de concorrência)."""
        return DartType("Future", (t,))

    def zero(self, index_or_desc):
        """Expressão Dart do zero value do tipo."""
        t = self.pkg.type_at(index_or_desc)
        if t["kind"] == "typeparam":
            return f"${t['name']}.zero()"  # dicionário do parâmetro de tipo
        u = self.typesys.underlying(t)
        k = u["kind"]
        if k == "basic":
            b = self.typesys.basic(u)
            if b.cat == "bool":
                return f"{self.dart(t)}()" if self.typesys.named_bool(t) else "false"
            if b.cls:
                return self.cls(t) + "()"
        if self.typesys.named_composite(t):
            return self.wrap(t, "null" if k == "func" else self.zero(u))
        if k in ("interface", "pointer", "func", "chan"):
            return "null"
        if k == "struct":
            # Struct genérica: o construtor recebe os dicionários dos argumentos.
            dicts = ", ".join(self.descriptors.elem(a) for a in self.typesys.type_args(t))
            return f"{self.dart(t)}({dicts})"
        if k == "typeparam":
            return f"${t['name']}.zero()"  # dicionário do parâmetro de tipo
        if k == "array":
            return f"{self.dart(u)}.zero({u['len']}, {self.descriptors.elem(u['elem'])})"
        if k in ("slice", "map"):  # nil
            return f"{self.dart(u)}.nil({self.descriptors.elem(u['elem'])})"
        raise Unsupported(f"zero-value:{k}", f"zero value de {k}")
