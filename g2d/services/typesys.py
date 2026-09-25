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

    def basic(self, t):
        """Basic do tipo subjacente, ou None se não for tipo básico."""
        if t is None:
            return None
        u = self.underlying(t)
        if u["kind"] != "basic":
            return None
        if u["name"] not in _BASICS:
            raise Unsupported(f"tipo básico {u['name']}")
        return _BASICS[u["name"]]

    def underlying(self, t):
        while t["kind"] == "named":
            t = self.pkg.type_at(t["underlying"])
        return t

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

    def named_composite(self, t):
        """Tipo nomeado (deste pacote) sobre slice/map/func: classe gerada —
        subclasse de go.Slice/go.GoMap, ou função chamável (`$f`)."""
        return (t is not None and t["kind"] == "named" and t["pkg"] == self.pkg.path and not t.get("args")
                and self.underlying(t)["kind"] in ("slice", "map", "func"))

    def named_func(self, t):
        return self.named_composite(t) and self.underlying(t)["kind"] == "func"

    def ptr_class(self, t):
        """N nomeado (deste pacote) não-struct com métodos e `*N` usado no
        pacote: `*N` é a classe gerada `N$Ptr` (go.PtrView com os métodos e
        interfaces de *N)."""
        return (t is not None and t["kind"] == "named" and t["pkg"] == self.pkg.path and bool(t.get("methods"))
                and self.underlying(t)["kind"] not in ("struct", "interface", "array")
                and id(t) in self.pointed_named)

    @property
    def pointed_named(self):
        """ids dos descritores nomeados N para os quais `*N` está na typeTable."""
        if not hasattr(self, "_pointed"):
            self._pointed = {id(self.pkg.type_at(t["elem"])) for t in self.pkg.type_table
                             if t["kind"] == "pointer"}
        return self._pointed

    def identity_keys(self, t):
        """Map cuja chave é `*T` (T struct): a chave é o próprio objeto da
        struct, então o go.GoMap compara por identidade."""
        u = self.underlying(t)
        return u["kind"] == "map" and self.is_struct_pointer(self.pkg.type_at(u["key"]))

    def map_args(self, t):
        """Argumentos extras dos construtores de go.GoMap para o tipo t."""
        return ", identity: true" if self.identity_keys(t) else ""

    def is_struct_pointer(self, t):
        """`*T` com T struct/array: representado pelo próprio objeto (`T?`)."""
        return t is not None and t["kind"] == "pointer" and self.is_value(self.pkg.type_at(t["elem"]))

    def layout(self, t):
        """(unsafe.Sizeof, unsafe.Alignof, contém ponteiros) em amd64 — decide o
        cap do append (growslice) no runtime."""
        t = self.pkg.type_at(t) if isinstance(t, int) else t
        u = self.underlying(t)
        k = u["kind"]
        if k == "basic":
            name = u["name"].replace("untyped ", "")
            name = {"int": "int", "float": "float64", "rune": "rune", "string": "string",
                    "bool": "bool", "complex": "complex128"}.get(name, name) if u["name"].startswith("untyped") else name
            if name not in _BASIC_LAYOUT:
                raise Unsupported(f"layout de {u['name']}")
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
        raise Unsupported(f"layout de {k}")
