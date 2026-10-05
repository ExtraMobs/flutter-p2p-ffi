"""Structs anônimas canônicas: uma classe por estrutura, igual em todo o grafo.

No Go, `struct{ X int }` é o mesmo tipo em qualquer pacote (atribuição,
comparação, type assertion). A classe Dart de uma struct anônima só com
nomes exportados vive numa library própria, `lib/_anon/<hash>.dart`, com o
nome `Struct$<hash>`: o hash vem da estrutura (campos, tags e tipos, com o
import path completo dos nomeados), então todo pacote que a usa escreve o
mesmo arquivo e importa a mesma classe. `_anon` não tem ponto no primeiro
segmento: nunca é o import path de um pacote do grafo.

A interface anônima com métodos, todos exportados e sem interface embutida,
segue o mesmo esquema (`Iface$<hash>`, D8): um tipo de outro pacote pode
declará-la no `implements` (`g2d/analysis/ifacecross.py`).

O resto continua local (`$_anon$N` na library do pacote, correto dentro
dele): com campo não exportado (o pacote do campo entra na identidade: só o
dono escreve esse tipo), parâmetro de tipo ou interface anônima com
embutida.
E o `main` que só importa a stdlib também fica com as locais: ninguém o
importa e ele não importa pacote do grafo, então nenhuma outra library
transpilada vê os tipos dele (programa de um pacote só sai como antes).
"""

import hashlib

from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported
from g2d.services.naming import is_exported

ANON_DIR = "_anon"


def anon_path(h):
    """Import path da library de uma struct canônica (`lib/<path>.dart`)."""
    return f"{ANON_DIR}/{h}"


def anon_class(h):
    return f"Struct${h}"


def anon_iface(h):
    return f"Iface${h}"


def anon_hash(key):
    """Hash da chave estrutural (nome da library e da classe)."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]


class AnonTypes(Service):
    """Chave estrutural e registro das structs anônimas canônicas usadas."""

    name = "anon"

    def __init__(self, engine):
        super().__init__(engine)
        self.used = {}  # hash → índice na typeTable (para emitir a library)
        self._keys = {}  # índice → chave estrutural (ou None)
        # `main` sem import do grafo: as structs dele não encontram outra library.
        self.closed = self.pkg.name == "main" and all(is_std(imp["path"]) for imp in self.pkg.imports)

    def canonical(self, t):
        """Hash da struct anônima t se ela é canônica (registra o uso), ou None."""
        if self.closed:
            return None
        idx = self.typesys.index_of(t)
        if idx not in self._keys:
            self._keys[idx] = self.key(t)
        k = self._keys[idx]
        if k is None:
            return None
        h = anon_hash(k)
        self.used.setdefault(h, idx)
        return h

    def key(self, t):
        """Chave estrutural do tipo (como o go/types escreve, com import paths
        completos), ou None se ele não pode ser compartilhado entre libraries."""
        t = self.pkg.type_at(t)
        k = t["kind"]
        if k == "basic":
            return t["name"]
        if k == "named":
            if t["pkg"] and (not is_exported(t["name"]) or id(t) in self.facts.local_types):
                return None  # classe privada da library dona, ou tipo local
            args = [self.key(a) for a in self.typesys.type_args(t)]
            if None in args:
                return None
            return (f"{t['pkg']}." if t["pkg"] else "") + t["name"] + (f"[{','.join(args)}]" if args else "")
        if k in ("pointer", "slice", "array", "chan"):
            elem = self.key(t["elem"])
            if elem is None:
                return None
            prefix = {"pointer": "*", "slice": "[]", "array": f"[{t.get('len')}]",
                      "chan": f"chan({t.get('dir')})"}[k]
            return prefix + elem
        if k == "map":
            key, elem = self.key(t["key"]), self.key(t["elem"])
            return None if key is None or elem is None else f"map[{key}]{elem}"
        if k == "func":
            parts = [self.key(p) for p in t["params"]] + [self.key(r) for r in t["results"]]
            if None in parts:
                return None
            n = len(t["params"])
            dots = "..." if t["variadic"] else ""
            return f"func({','.join(parts[:n])}{dots})({','.join(parts[n:])})"
        if k == "interface":
            if not t["methods"] and not t["embeddeds"]:
                return "interface{}"
            if t["embeddeds"]:
                return None  # a classe declara as embutidas: depende de como se escreveu
            ms = []
            for m in t["methods"]:
                sig = self.key(m["type"]) if is_exported(m["name"]) else None
                if sig is None:
                    return None
                ms.append(f"{m['name']} {sig}")
            return "interface{" + "; ".join(sorted(ms)) + "}"
        if k == "struct":
            fields = []
            for f in t["fields"]:
                if not is_exported(f["name"]):
                    return None  # `_` e não exportado: identidade do pacote dono
                ft = self.key(f["type"])
                if ft is None:
                    return None
                emb = "embedded " if f["embedded"] else ""
                fields.append(f"{emb}{f['name']} {ft} {f['tag']!r}")
            return "struct{" + "; ".join(fields) + "}"
        return None  # typeparam, tuple, union

    def owners(self, t):
        """Pacotes dos nomes não exportados na estrutura de t (campos, métodos
        e tipos nomeados): só eles escrevem esse tipo anônimo."""
        t = self.pkg.type_at(t)
        k = t["kind"]
        if k == "named":
            out = {t["pkg"]} if t["pkg"] and not is_exported(t["name"]) else set()
            for a in self.typesys.type_args(t):
                out |= self.owners(a)
            return out
        out = set()
        for m in (t.get("fields") or []) + (t.get("methods") or []):
            if m.get("pkg") is not None:
                out.add(m["pkg"])
            out |= self.owners(m["type"])
        for key in ("elem", "key"):
            if key in t:
                out |= self.owners(t[key])
        for key in ("params", "results", "embeddeds"):
            for x in t.get(key) or []:
                out |= self.owners(x)
        return out

    def check_owner(self, t, node=None):
        """Struct/interface anônima com nome não exportado de outro pacote
        (campo, método ou tipo nomeado): o tipo é do dono e a classe local
        (privada) seria outra."""
        other = sorted(self.owners(t) - {self.pkg.path})
        if other:
            raise Unsupported("anonima:nao-exportada-de-outro-pacote",
                              f"{self.goinfo.go_type_name(t)} anônima com nome não exportado do pacote {other[0]}",
                              node)
