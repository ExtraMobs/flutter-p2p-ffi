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

# Pacotes da stdlib com shim em golib_dart/.
STDLIB_SHIMS = {
    "fmt": "package:golib_dart/fmt.dart",
}

_INT_TYPES = frozenset("""
int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 uintptr byte rune
""".split()) | {"untyped int", "untyped rune"}
_FLOAT_TYPES = frozenset(["float32", "float64", "untyped float"])
_BASIC = {"string": "String", "untyped string": "String", "bool": "bool", "untyped bool": "bool"}


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
    """Tipos: exportado mantém o nome; não exportado ganha `_`."""
    return name if is_exported(name) else "_" + name


def local_name(name):
    """Variáveis locais e parâmetros: nome Go, escapando reservadas."""
    return escape(name)


def is_int(t):
    return t is not None and t["kind"] == "basic" and t["name"] in _INT_TYPES


def is_float(t):
    return t is not None and t["kind"] == "basic" and t["name"] in _FLOAT_TYPES


def underlying(pkg, t):
    while t["kind"] == "named":
        t = pkg.type_at(t["underlying"])
    return t


class TypeMapper:
    """Converte descritores da typeTable em tipos Dart.

    `qualify(pkg_path, name)` devolve o nome Dart qualificado de um tipo
    nomeado (e registra o import usado).
    """

    def __init__(self, pkg, qualify):
        self.pkg = pkg
        self.qualify = qualify

    def dart(self, index_or_desc):
        t = self.pkg.type_at(index_or_desc) if isinstance(index_or_desc, int) else index_or_desc
        k = t["kind"]
        if k == "basic":
            n = t["name"]
            if n in _INT_TYPES:
                return "int"
            if n in _FLOAT_TYPES:
                return "double"
            if n in _BASIC:
                return _BASIC[n]
            if n == "untyped nil":
                return "Null"
            raise Unsupported(f"tipo básico {n}")
        if k == "named":
            if t["pkg"] == "" and t["name"] == "error":
                return self.qualify(None, "GoError") + "?"
            if t.get("args"):
                raise Unsupported(f"tipo genérico instanciado {t['name']}")
            name = self.qualify(t["pkg"], type_name(t["name"]))
            return name + "?" if self.nilable(t) else name
        if k == "pointer":
            elem = self.pkg.type_at(t["elem"])
            if underlying(self.pkg, elem)["kind"] != "struct":
                raise Unsupported("ponteiro para tipo não-struct")
            return self.dart(elem).rstrip("?") + "?"
        if k == "slice":
            return f"List<{self.dart(t['elem'])}>"
        if k == "map":
            return f"Map<{self.dart(t['key'])}, {self.dart(t['elem'])}>"
        if k == "interface":
            if not t["methods"] and not t["embeddeds"]:
                return "Object?"
            raise Unsupported("interface anônima")
        if k == "func":
            return self.func_type(t) + "?"
        if k == "tuple":
            return self.results(t["elems"])
        raise Unsupported(f"tipo {k}")

    def results(self, elems):
        if not elems:
            return "void"
        if len(elems) == 1:
            return self.dart(elems[0])
        return "(" + ", ".join(self.dart(e) for e in elems) + ")"

    def func_type(self, t):
        # Variádico ...T já vem como []T na assinatura → List<T>.
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
            if is_int(u):
                return "0"
            if is_float(u):
                return "0.0"
            if u["name"] in ("string", "untyped string"):
                return "''"
            if u["name"] in ("bool", "untyped bool"):
                return "false"
        if k in ("interface", "pointer", "func"):
            return "null"
        if k == "struct" and t["kind"] == "named":
            return self.dart(t) + "()"
        if k == "slice":
            return f"<{self.dart(u['elem'])}>[]"
        if k == "map":
            return f"<{self.dart(u['key'])}, {self.dart(u['elem'])}>{{}}"
        raise Unsupported(f"zero value de {k}")
