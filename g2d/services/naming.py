"""Regras de nome Go → Dart (puras, sem estado).

Regras documentadas em docs/mapping-spec.md.
"""

from g2d.config import GOLANG_PREFIX


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


class NamingRules:
    """As regras acima agrupadas (para quem prefere injetar um objeto)."""

    escape = staticmethod(escape)
    lower_camel = staticmethod(lower_camel)
    member_name = staticmethod(member_name)
    type_name = staticmethod(type_name)
    local_name = staticmethod(local_name)
