"""Sistema de tipos Go sobre a typeTable do goast: categorias básicas,
tipo subjacente, valores com armazenamento próprio e layout (amd64).
"""

from g2d.engine.behavior import Service
from g2d.model import Unsupported


class Basic:
    """Representação Dart de um tipo básico Go.

    cat: bool | wint (inteiro) | float | complex | string | nil. cls: classe
    em fixed_types. Regra: o Dart gerado roda em todas as plataformas (VM, AOT,
    Wasm, JS), então só `bool` é nativo (idêntico em todas); todo o resto passa
    pelas classes intermediárias de fixed_types.
    """

    def __init__(self, cat, cls=None, width=64, signed=True):
        self.cat, self.cls, self.width, self.signed = cat, cls, width, signed

    @property
    def integer(self):
        return self.cat == "wint"


_BASICS = {
    "bool": Basic("bool"), "untyped bool": Basic("bool"),
    "int": Basic("wint", "Int"), "int64": Basic("wint", "Int64"), "untyped int": Basic("wint", "Int"),
    "int8": Basic("wint", "Int8", 8), "int16": Basic("wint", "Int16", 16),
    "int32": Basic("wint", "Int32", 32), "rune": Basic("wint", "Int32", 32),
    "untyped rune": Basic("wint", "Int32", 32),
    "uint": Basic("wint", "Uint", 64, False), "uintptr": Basic("wint", "Uintptr", 64, False),
    "uint8": Basic("wint", "Uint8", 8, False), "byte": Basic("wint", "Uint8", 8, False),
    "uint16": Basic("wint", "Uint16", 16, False), "uint32": Basic("wint", "Uint32", 32, False),
    "uint64": Basic("wint", "Uint64", 64, False),
    "float32": Basic("float", "Float32", 32), "float64": Basic("float", "Float64"),
    "untyped float": Basic("float", "Float64"),
    "complex64": Basic("complex", "Complex64", 32), "complex128": Basic("complex", "Complex128"),
    "untyped complex": Basic("complex", "Complex128"),
    "string": Basic("string", "String"), "untyped string": Basic("string", "String"),
    "untyped nil": Basic("nil"),
}


# (tamanho, alinhamento, contém ponteiros) de tipos básicos em amd64.
_BASIC_LAYOUT = {
    "bool": (1, 1, False), "int8": (1, 1, False), "uint8": (1, 1, False), "byte": (1, 1, False),
    "int16": (2, 2, False), "uint16": (2, 2, False),
    "int32": (4, 4, False), "uint32": (4, 4, False), "rune": (4, 4, False), "float32": (4, 4, False),
    "int": (8, 8, False), "uint": (8, 8, False), "int64": (8, 8, False), "uint64": (8, 8, False),
    "uintptr": (8, 8, False), "float64": (8, 8, False),
    "complex64": (8, 4, False), "complex128": (16, 8, False),
    "string": (16, 8, True), "Pointer": (8, 8, True),
}


class TypeSystem(Service):
    """Consultas de tipo (sem estado além do pacote)."""

    name = "typesys"

    def __init__(self, engine):
        super().__init__(engine)
        self._array_cores = {}  # constraint → core sintético de `[3]int | [4]int`

    def basic(self, t):
        """Basic do tipo subjacente, ou None se não for tipo básico."""
        if t is None:
            return None
        u = self.underlying(t)
        if u["kind"] != "basic":
            return None
        if u["name"] == "Pointer":
            raise Unsupported("unsafe:Pointer", "unsafe.Pointer (sem memória crua fora do dart:ffi)")
        if u["name"] not in _BASICS:
            raise Unsupported(f"tipo-basico:{u['name']}", f"tipo básico {u['name']}")
        return _BASICS[u["name"]]

    def underlying(self, t):
        while t["kind"] == "named":
            t = self.pkg.type_at(t["underlying"])
        if t["kind"] == "typeparam":  # `S ~[]E`: o core type composto
            core = self.core(t)
            if core is not None and core["kind"] in ("slice", "map", "array"):
                return core
        return t

    def constraint_terms(self, iface):
        """Termos de tipo de uma constraint, expandindo interfaces embutidas
        (`constraints.Integer` = `Signed | Unsigned`) e ignorando `comparable`
        e as só de métodos."""
        out = []
        for e in iface["embeddeds"]:
            et = self.pkg.type_at(e)
            if self.is_universe(et, "comparable"):
                continue
            if et["kind"] == "union":
                for x in et["terms"]:
                    xt = self.pkg.type_at(x["type"])
                    xu = xt
                    while xu["kind"] == "named":
                        xu = self.pkg.type_at(xu["underlying"])
                    out += self.constraint_terms(xu) if xu["kind"] == "interface" else [xt]
                continue
            eu = et
            while eu["kind"] == "named":
                eu = self.pkg.type_at(eu["underlying"])
            if eu["kind"] == "interface":
                out += self.constraint_terms(eu)
            else:
                out.append(et)
        return out

    def core(self, tp):
        """Core type de um parâmetro de tipo (todos os termos da constraint
        com o mesmo subjacente), ou None."""
        c = self.pkg.type_at(tp["constraint"])
        while c["kind"] == "named":
            c = self.pkg.type_at(c["underlying"])
        if c["kind"] != "interface":
            return None
        terms = self.constraint_terms(c)
        us = [self.underlying(x) if x["kind"] != "typeparam" else x for x in terms]
        if not us:
            return None
        if all(u["kind"] == "array" and u["elem"] == us[0]["elem"] for u in us) and len(us) > 1:
            # `[3]int | [4]int`: sem core type no Go, mas o mesmo go.GoArray<E>
            # no Dart (índice, len e range valem para todos os termos).
            return self._array_cores.setdefault(tp["constraint"], {"kind": "array", "elem": us[0]["elem"], "len": None})
        if any(u != us[0] for u in us):
            return None
        return us[0]

    @staticmethod
    def is_universe(t, name):
        """Tipo nomeado predeclarado do universo (`error`, `comparable`)."""
        return t["kind"] == "named" and t["pkg"] == "" and t["name"] == name

    def is_struct(self, t):
        """Struct por valor (nomeada ou anônima)."""
        return t is not None and t["kind"] in ("named", "struct") and self.underlying(t)["kind"] == "struct"

    def index_of(self, t):
        """Índice de um descritor na typeTable."""
        if not hasattr(self, "_index"):
            self._index = {id(d): i for i, d in enumerate(self.pkg.type_table)}
        return self._index[id(t)]

    def is_value(self, t):
        """Valor com armazenamento próprio (struct nomeada ou array): o objeto Dart
        é o endereço; atribuir copia; `x = y` é in-place (go.GoValue)."""
        return t is not None and (self.is_struct(t) or self.underlying(t)["kind"] == "array")

    def may_hold_value(self, t):
        """Parâmetro de tipo que pode ser instanciado com struct/array (a
        constraint não restringe a termos sem valor: `any`, só métodos,
        `comparable`, ou algum termo struct/array)."""
        if t is None or t["kind"] != "typeparam" or self.is_value(t):
            return False
        c = self.pkg.type_at(t["constraint"])
        while c["kind"] == "named":
            c = self.pkg.type_at(c["underlying"])
        if c["kind"] != "interface":
            return False
        terms = self.constraint_terms(c)
        return not terms or any(self.may_hold_value(x) if x["kind"] == "typeparam" else self.is_value(x)
                                for x in terms)

    def named_composite(self, t):
        """Tipo nomeado (de pacote transpilado) sobre slice/map/func/array:
        classe gerada — subclasse de go.Slice/go.GoMap/go.GoArray, ou função
        chamável (`$f`)."""
        return (t is not None and t["kind"] == "named" and self.imports.transpiled(t["pkg"])
                and self.underlying(t)["kind"] in ("slice", "map", "func", "array"))

    def type_args(self, t):
        """Argumentos de tipo de uma instância; tipo local de função genérica
        usa os parâmetros da função."""
        return t.get("args") or self.facts.local_targs.get(id(t)) or []

    def named_bool(self, t):
        """Tipo nomeado (de pacote transpilado) sobre bool: classe go.GoBool,
        desembrulhada com `.$b` onde o Dart exige bool."""
        if t is None or t["kind"] != "named" or not self.imports.transpiled(t["pkg"]):
            return False
        u = self.underlying(t)
        return u["kind"] == "basic" and (self.basic(u) is not None and self.basic(u).cat == "bool")

    def named_func(self, t):
        return self.named_composite(t) and self.underlying(t)["kind"] == "func"

    def ptr_class(self, t):
        """N nomeado (de pacote transpilado) não-struct com métodos, com `*N`
        usado no pacote ou exportado: `*N` é a classe gerada `N$Ptr`
        (go.PtrView com os métodos e interfaces de *N). Exportado sempre tem
        `N$Ptr`, porque o pacote dono não sabe se outro usa `*N`."""
        return (t is not None and t["kind"] == "named" and self.imports.transpiled(t["pkg"])
                and bool(t.get("methods"))
                and self.underlying(t)["kind"] not in ("struct", "interface", "array")
                and ((t["pkg"], t["name"]) in self.pointed_named or self.exported(t["pkg"], t["name"])))

    def exported(self, pkg_path, name):
        """Nome visível de outro pacote: exportado e de pacote importável
        (o `main` não é importado por ninguém)."""
        return name[:1].isupper() and (pkg_path != self.pkg.path or self.pkg.name != "main")

    @property
    def pointed_named(self):
        """(pacote, nome) dos N para os quais `*N` está na typeTable (por nome:
        as instâncias de um genérico são descritores distintos)."""
        if not hasattr(self, "_pointed"):
            self._pointed = {(e.get("pkg"), e.get("name")) for e in
                             (self.pkg.type_at(t["elem"]) for t in self.pkg.type_table if t["kind"] == "pointer")
                             if e["kind"] == "named"}
        return self._pointed

    def identity_keys(self, t):
        """Map cuja chave é `*T` (T struct): a chave é o próprio objeto da
        struct, então o go.GoMap compara por identidade."""
        u = self.underlying(t)
        return u["kind"] == "map" and self.is_struct_pointer(self.pkg.type_at(u["key"]))

    def map_args(self, t):
        """Argumentos extras dos construtores de go.GoMap para o tipo t."""
        return (", identity: true" if self.identity_keys(t) else "") + self.reflection.map_key(t)

    def is_struct_pointer(self, t):
        """`*T` com T struct/array: representado pelo próprio objeto (`T?`)."""
        return t is not None and t["kind"] == "pointer" and self.is_value(self.pkg.type_at(t["elem"]))

    def layout(self, t):
        """(unsafe.Sizeof, unsafe.Alignof, contém ponteiros) em amd64 — decide o
        cap do append (growslice) no runtime."""
        t = self.pkg.type_at(t)
        u = self.underlying(t)
        k = u["kind"]
        if k == "basic":
            name = u["name"].replace("untyped ", "")
            name = {"int": "int", "float": "float64", "rune": "rune", "string": "string",
                    "bool": "bool", "complex": "complex128"}.get(name, name) if u["name"].startswith("untyped") else name
            if name not in _BASIC_LAYOUT:
                raise Unsupported(f"layout:{u['name']}", f"layout de {u['name']}")
            return _BASIC_LAYOUT[name]
        if k in ("pointer", "map", "chan", "func"):
            return 8, 8, True
        if k == "slice":
            return 24, 8, True
        if k == "interface":
            return 16, 8, True
        if k == "array":
            size, align, ptrs = self.layout(u["elem"])
            return size * u["len"], align, ptrs and u["len"] > 0
        if k == "struct":
            off, maxalign, ptrs, last = 0, 1, False, 1
            for f in u["fields"]:
                size, align, fp = self.layout(f["type"])
                off = (off + align - 1) // align * align + size
                maxalign, ptrs, last = max(maxalign, align), ptrs or fp, size
            if u["fields"] and last == 0 and off > 0:
                off += 1  # campo final de tamanho zero ganha padding (cmd/compile)
            return (off + maxalign - 1) // maxalign * maxalign, maxalign, ptrs
        raise Unsupported(f"layout:{k}", f"layout de {k}")
