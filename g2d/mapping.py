"""Correspondência Go → Dart: identificadores, tipos e shims da stdlib.

Regras documentadas em docs/mapping-spec.md.
"""

from g2d.model import Unsupported

# Palavras reservadas do Dart (não podem ser identificadores).
DART_RESERVED = frozenset("""
assert break case catch class const continue default do else enum extends
false final finally for if in is new null rethrow return super switch this
throw true try var void while with
""".split())

# Prefixo do shim do universo Go (builtin.dart). `go` é palavra-chave em Go,
# então nenhum pacote ou identificador Go colide com ele.
BUILTIN_PREFIX = "go"
BUILTIN_URI = "package:golib_dart/builtin.dart"

# Tipos fixos do Go (golib_dart/fixed_types, origem: boilerplate do dart IPFS).
# O sentinela não é um import path Go válido (`$`), então não colide.
GOLANG = "$golang"
GOLANG_PREFIX = "Golang"
GOLANG_URI = "package:golib_dart/fixed_types/golang.dart"

# Interfaces da stdlib que existem nos shims (podem ir em `implements`).
SHIM_INTERFACES = {("fmt", "Stringer")}

# Pacotes da stdlib com shim em golib_dart/.
STDLIB_SHIMS = {
    "fmt": "package:golib_dart/fmt.dart",
    "math": "package:golib_dart/math.dart",
}



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


def basic(pkg, t):
    """Basic do tipo subjacente, ou None se não for tipo básico."""
    if t is None:
        return None
    u = underlying(pkg, t)
    if u["kind"] != "basic":
        return None
    if u["name"] not in _BASICS:
        raise Unsupported(f"tipo básico {u['name']}")
    return _BASICS[u["name"]]


def escape(name):
    return name + "$" if name in DART_RESERVED else name


def lower_camel(name):
    """Primeira "palavra" em minúsculas, tratando siglas: URL→url,
    HTTPServer→httpServer, MD5Sum→md5Sum."""
    run = 0
    while run < len(name) and name[run].isupper():
        run += 1
    if run == 0:
        return name
    if run == len(name) or not name[run].islower() or run == 1:
        cut = run
    else:
        cut = run - 1  # a última maiúscula inicia a próxima palavra
    return name[:cut].lower() + name[cut:]


def is_exported(name):
    return name[:1].isupper()


def member_name(name):
    """Funções, variáveis, constantes, campos e métodos (nível de pacote/tipo).

    Exportado → lowerCamel; não exportado → `_` + nome (privado da library;
    um pacote Go = uma library Dart).
    """
    if name == "_":
        return name
    return escape(lower_camel(name)) if is_exported(name) else "_" + name


def type_name(name):
    """Tipos: exportado mantém o nome; não exportado ganha `_`. `Golang` é o
    prefixo dos tipos fixos."""
    if name == GOLANG_PREFIX:
        return name + "$"
    return name if is_exported(name) else "_" + name


def local_name(name):
    """Variáveis locais e parâmetros: nome Go, escapando reservadas."""
    return escape(name)


def underlying(pkg, t):
    while t["kind"] == "named":
        t = pkg.type_at(t["underlying"])
    return t


def is_struct(pkg, t):
    """Struct por valor (nomeada)."""
    return t is not None and t["kind"] == "named" and underlying(pkg, t)["kind"] == "struct"


def is_value(pkg, t):
    """Valor com armazenamento próprio (struct nomeada ou array): o objeto Dart
    é o endereço; atribuir copia; `x = y` é in-place (go.GoValue)."""
    return t is not None and (is_struct(pkg, t) or underlying(pkg, t)["kind"] == "array")


def is_struct_pointer(pkg, t):
    """`*T` com T struct/array: representado pelo próprio objeto (`T?`)."""
    return t is not None and t["kind"] == "pointer" and is_value(pkg, pkg.type_at(t["elem"]))


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


def layout(pkg, t):
    """(unsafe.Sizeof, unsafe.Alignof, contém ponteiros) em amd64 — decide o
    cap do append (growslice) no runtime."""
    t = pkg.type_at(t) if isinstance(t, int) else t
    u = underlying(pkg, t)
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
        size, align, ptrs = layout(pkg, u["elem"])
        return size * u["len"], align, ptrs and u["len"] > 0
    if k == "struct":
        off, maxalign, ptrs, last = 0, 1, False, 1
        for f in u["fields"]:
            size, align, fp = layout(pkg, f["type"])
            off = (off + align - 1) // align * align + size
            maxalign, ptrs, last = max(maxalign, align), ptrs or fp, size
        if u["fields"] and last == 0 and off > 0:
            off += 1  # campo final de tamanho zero ganha padding (cmd/compile)
        return (off + maxalign - 1) // maxalign * maxalign, maxalign, ptrs
    raise Unsupported(f"layout de {k}")


class TypeMapper:
    """Converte descritores da typeTable em tipos Dart.

    `qualify(pkg_path, name)` devolve o nome Dart qualificado de um tipo
    nomeado (e registra o import usado).
    """

    def __init__(self, pkg, qualify, elem):
        self.pkg = pkg
        self.qualify = qualify
        self.elem = elem  # t → nome do descritor const go.Elem<T>

    def dart(self, index_or_desc):
        t = self.pkg.type_at(index_or_desc) if isinstance(index_or_desc, int) else index_or_desc
        k = t["kind"]
        if k == "basic":
            b = basic(self.pkg, t)
            if b.cat == "bool":
                return b.cat
            if b.cat == "nil":
                return "Null"
            return self.golang(b.cls)
        if k == "named":
            if t["pkg"] == "" and t["name"] == "error":
                return self.qualify(None, "GoError") + "?"
            name = self.qualify(t["pkg"], type_name(t["name"]))
            if t.get("args"):
                name += "<" + ", ".join(self.dart(a) for a in t["args"]) + ">"
            return name + "?" if self.nilable(t) else name
        if k == "pointer":
            elem = self.pkg.type_at(t["elem"])
            if is_value(self.pkg, elem):
                return self.dart(elem) + "?"  # struct/array é o próprio endereço
            return f"{self.qualify(None, 'Ptr')}<{self.dart(elem)}>?"
        if k == "slice":
            return f"{self.qualify(None, 'Slice')}<{self.dart(t['elem'])}>"
        if k == "array":
            return f"{self.qualify(None, 'GoArray')}<{self.dart(t['elem'])}>"
        if k == "map":
            key = self.pkg.type_at(t["key"])
            if key["kind"] == "pointer" and is_struct_pointer(self.pkg, key):
                raise Unsupported("map com chave ponteiro-para-struct")
            return f"{self.qualify(None, 'GoMap')}<{self.dart(key)}, {self.dart(t['elem'])}>"
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
        return self.golang(basic(self.pkg, t).cls)

    def golang(self, cls):
        """Nome qualificado de uma classe de fixed_types (registra o import)."""
        return self.qualify(GOLANG, cls)

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
        return underlying(self.pkg, t)["kind"] in ("interface", "pointer", "func")

    def zero(self, index_or_desc):
        """Expressão Dart do zero value do tipo."""
        t = self.pkg.type_at(index_or_desc) if isinstance(index_or_desc, int) else index_or_desc
        u = underlying(self.pkg, t)
        k = u["kind"]
        if k == "basic":
            b = basic(self.pkg, u)
            if b.cat == "bool":
                return "false"
            if b.cls:
                return self.cls(t) + "()"
        if k in ("interface", "pointer", "func"):
            return "null"
        if k == "struct" and t["kind"] == "named":
            # Struct genérica: o construtor recebe os dicionários dos argumentos.
            dicts = ", ".join(self.elem(a) for a in t.get("args") or [])
            return f"{self.dart(t)}({dicts})"
        if k == "typeparam":
            return f"${t['name']}.zero()"  # dicionário do parâmetro de tipo
        if k == "array":
            return f"{self.dart(u)}.zero({u['len']}, {self.elem(u['elem'])})"
        if k in ("slice", "map"):  # nil
            return f"{self.dart(t)}.nil({self.elem(u['elem'])})"
        raise Unsupported(f"zero value de {k}")
