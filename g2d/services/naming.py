"""Nomes Go → Dart: as regras (puras, sem estado; documentadas em
docs/mapping-spec.md) e o serviço `Naming` (locais, temporários, caixas).
"""

from g2d.config import GOLANG_PREFIX
from g2d.engine.behavior import Service
from g2d.model import Unsupported


# Palavras reservadas do Dart (não podem ser identificadores).
DART_RESERVED = frozenset("""
assert break case catch class const continue default do else enum extends
false final finally for if in is new null rethrow return super switch this
throw true try var void while with
""".split())


# Nomes do dart:core que o código gerado usa sem prefixo. Uma declaração Go
# com o mesmo nome (tipo `Object`, função `Identical` → `identical`, local
# `int`) sombrearia o core na library; ela ganha `$`.
DART_CORE_USED = frozenset("""
Object String List Map BigInt Function Null Never Iterable Uint8List
bool int double num dynamic identical
""".split())


# Membros das classes base que o código gerado estende ou implementa
# (go.Slice, go.GoMap, go.PtrView, função nomeada, bases inteiras de
# fixed_types, Object): um método/campo Go
# com o mesmo nome (`func (s Set) Delete`) os sobrescreveria; ganha `$`. A
# regra é global (vale também nas interfaces), então o despacho continua certo.
DART_BASE_MEMBERS = frozenset("""
isNil length capacity addr slice append appendSlice copyFrom items elem
containsKey lookup delete keysSnapshot entries value call
toInt toBigInt toLittleEndianBytes andNot compareTo from fromBigInt
hashCode runtimeType toString noSuchMethod
""".split())


def ascii_name(name):
    """Letra não-ASCII (Go aceita Unicode; Dart só `[A-Za-z0-9_$]`) → `$uXXXX`
    (BMP) ou `$UXXXXXXXX`, largura fixa como no C: sem ambiguidade com os
    dígitos seguintes, e nome Go não tem `$`, então não colide."""
    if name.isascii():
        return name
    return "".join(c if c.isascii() else f"$u{ord(c):04x}" if ord(c) <= 0xFFFF else f"$U{ord(c):08x}"
                   for c in name)


def escape(name):
    """Palavra reservada ou nome do dart:core usado pelo código gerado → `$`;
    letra não-ASCII → `ascii_name`."""
    name = ascii_name(name)
    return name + "$" if name in DART_RESERVED or name in DART_CORE_USED else name


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
    if not is_exported(name):
        return "_" + ascii_name(name)
    dart = escape(lower_camel(name))
    return dart + "$" if dart in DART_BASE_MEMBERS else dart


def top_member_name(name, fold=False):
    """Função, var ou const de nível de pacote. `fold` (goast): o pacote
    exporta outro nome igual a este sem diferenciar caixa (`BOOL` e `Bool`).
    O que perderia a caixa de mais de uma letra no lowerCamel (`BOOL` →
    `bool`, igual ao de `Bool`) mantém a grafia Go; dois nomes assim nunca
    colidem entre si, nem com um lowerCamel (começa minúsculo)."""
    if fold and is_exported(name) and lower_camel(name) != name[:1].lower() + name[1:]:
        return ascii_name(name)
    return member_name(name)


def type_name(name):
    """Tipos: exportado mantém o nome; não exportado ganha `_` e `$`. `Golang`
    é o prefixo dos tipos fixos."""
    if name == GOLANG_PREFIX or name in DART_CORE_USED:
        return name + "$"
    # Não exportado: `_t$`, nunca igual a um membro não exportado `_t` (um
    # campo embutido `t` ou método `t` dentro da classe sombrearia o tipo).
    return ascii_name(name) if is_exported(name) else "_" + ascii_name(name) + "$"


def local_name(name):
    """Variáveis locais e parâmetros: nome Go, escapando reservadas."""
    return escape(name)


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

    def top_name(self, go_name, kind, fold=False):
        """Função, var ou const de nível de pacote (`fold`: do `$obj`)."""
        if kind == "func" and go_name == "main" and self.pkg.name == "main":
            return "main"
        return top_member_name(go_name, fold)

    def boxed(self, obj):
        """Variável que mora num go.Box: endereço tomado no pacote, ou var
        exportada de pacote importável e tipo não-valor (outro pacote pode
        tomar `&a.X`; o dono não tem como saber)."""
        if obj.get("kind") != "var":
            return False
        if obj.get("pkg") == self.pkg.path and obj.get("decl") in self.facts.boxed:
            return True
        return (bool(obj.get("top")) and self.typesys.exported(obj["pkg"], obj["name"])
                and self.imports.transpiled(obj["pkg"])  # var de shim (io.EOF) é um final Dart
                and not self.typesys.is_value(self.pkg.type_at(obj["type"])))

    def box_suffix(self, obj):
        """Variável em go.Box: acesso via .value."""
        return ".value" if self.boxed(obj) else ""

    def box_name(self, obj):
        """Nome Dart da caixa (go.Box) de uma variável com `&x`."""
        if obj.get("top"):
            return self.top_name(obj["name"], obj["kind"], obj.get("fold"))
        return self.scope.locals[obj["decl"]]

    def local_decl(self, ident, t, init):
        """Declaração de uma variável local Go nova (com caixa se `&x`)."""
        name = self.declare_local(ident)
        dt = self.types.dart(t)
        if ident["$obj"]["decl"] in self.facts.boxed:
            box_t, box = self.types.box(t, init)
            return f"final {box_t} {name} = {box};"
        return f"{dt} {name} = {init};"
