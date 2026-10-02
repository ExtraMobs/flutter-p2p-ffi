"""Imports Dart usados e prefixos (qualificação de símbolos)."""

import re

from g2d.config import BUILTIN_PREFIX, BUILTIN_URI, GOLANG, GOLANG_PREFIX, GOLANG_URI, GRAPH_URI, STDLIB_SHIMS
from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported
from g2d.services.naming import escape, is_exported, member_name, top_member_name


def declared_names(pkg):
    """Nomes Dart exportados que a library declara: funções, vars e consts de
    pacote, e membros das classes dela (campos, métodos, promovidos). Um
    prefixo de import igual a um deles seria sombreado."""
    names, top = set(), set()
    for f in pkg.files:
        for d in f["ast"]["decls"] or []:
            if d["node"] == "FuncDecl" and not d["recv"]:
                top.add(top_member_name(d["name"]["name"], d["name"]["$obj"].get("fold")))
            elif d["node"] == "GenDecl" and d["tok"] in ("var", "const"):
                top.update(top_member_name(i["name"], (i.get("$obj") or {}).get("fold"))
                           for s in d["specs"] for i in s["names"])
    underlying = {t["underlying"] for t in pkg.type_table if t["kind"] == "named"}
    for i, t in enumerate(pkg.type_table):
        if t["kind"] == "named" and t["pkg"] == pkg.path:
            names.update(m["name"] for m in t.get("methods") or [])
            u = pkg.type_at(t["underlying"])
            names.update(x["name"] for x in u.get("fields") or u.get("methods") or [])
        elif t["kind"] == "struct" and i not in underlying:  # struct anônima
            names.update(x["name"] for x in t["fields"])
    return top | {member_name(n) for n in names if is_exported(n)}


SELF_PREFIX = "$self"


class ImportTable(Service):
    """Imports Dart usados e prefixos (qualificação de símbolos)."""

    name = "imports"

    def __init__(self, engine):
        super().__init__(engine)
        self.used = {}  # prefixo → URI (só os realmente usados)
        self.prefixes = {}  # import path → prefixo
        self.taken = declared_names(self.pkg)
        for imp in self.pkg.imports:
            if imp["name"] == ".":
                # `import .`: os identificadores já trazem o pacote do objeto
                # e são qualificados pelo prefixo derivado do import path.
                continue
            if imp["name"] == "_":
                # Só pelo init: os pacotes do grafo inicializam pela ordem
                # global do Go (`$goInit` do main); shims não têm init.
                # `_ "embed"` só existe para `//go:embed` (dados do arquivo).
                if imp["path"] == "embed":
                    raise Unsupported("go:embed", "//go:embed (import _ embed)", self.import_spec(imp["path"]))
                continue
            if imp["name"] == GOLANG_PREFIX:
                raise Unsupported(f"import:{imp['name']}", f"import {imp['name']} {imp['path']}",
                                  self.import_spec(imp["path"]))
            if imp["path"] not in self.prefixes:
                self.prefixes[imp["path"]] = self.free_prefix(escape(imp["name"]))

    def free_prefix(self, prefix):
        """Prefixo que nenhum nome declarado na library sombreia (campo
        `time` numa classe esconde o prefixo `time` no corpo dela) e que não
        é de outro import (arquivos diferentes podem importar `crypto/rand`
        e `math/rand` como `rand`)."""
        while prefix in self.taken or prefix in self.prefixes.values():
            prefix += "_"
        return prefix

    def import_spec(self, path):
        """ImportSpec da AST com esse import path (posição dos erros)."""
        return next((s for f in self.pkg.files for s in f["ast"]["imports"] or []
                     if s["path"]["value"].strip('"`') == path), None)

    def directives(self):
        """`import '...' as p;` dos imports usados, em ordem."""
        return [f"import '{self.used[p]}' as {p};" for p in sorted(self.used)]

    def transpiled(self, pkg_path):
        """Pacote transpilado pelo g2d: o próprio ou outro do grafo (fora da stdlib)."""
        return pkg_path == self.pkg.path or (bool(pkg_path) and not is_std(pkg_path))

    _shim_symbols = None

    def shim_symbol(self, pkg_path, name):
        """Símbolo de shim: existe no arquivo (lista do dartast), ou Unsupported."""
        if ImportTable._shim_symbols is None:
            from g2d import shims

            ImportTable._shim_symbols = shims.load()
        if name not in ImportTable._shim_symbols.get(pkg_path, ()):
            raise Unsupported(f"shim-simbolo:{pkg_path}.{name}", f"símbolo sem shim: {pkg_path}.{name}")

    def uri(self, pkg_path):
        """Library Dart de outro pacote: shim da stdlib ou library do grafo."""
        if pkg_path in STDLIB_SHIMS:
            return STDLIB_SHIMS[pkg_path]
        if self.transpiled(pkg_path):
            return GRAPH_URI.format(path=pkg_path)
        raise Unsupported(f"shim-ausente:{pkg_path}", f"pacote sem shim/transpilação: {pkg_path}")

    def qualify_self(self, name):
        """Nome exportado da própria library pelo import dela mesma (`$self`:
        nenhum nome Go tem `$`), para o corpo de uma classe com membro de
        mesmo nome. Nome privado não passa por import: `Naming.top_name`
        o renomeia. URI vazia: a própria library (referência relativa vazia
        resolve para o URI base), qualquer que seja o nome do arquivo."""
        self.used[SELF_PREFIX] = ""
        return f"{SELF_PREFIX}.{name}"

    def qualify(self, pkg_path, name):
        """Nome Dart de um símbolo de outro pacote (ou do universo, se None)."""
        if pkg_path is None:
            self.used[BUILTIN_PREFIX] = BUILTIN_URI
            return f"{BUILTIN_PREFIX}.{name}"
        if pkg_path == GOLANG:
            self.used[GOLANG_PREFIX] = GOLANG_URI
            return f"{GOLANG_PREFIX}.{name}"
        if pkg_path == self.pkg.path:
            return name
        uri = self.uri(pkg_path)
        if pkg_path in STDLIB_SHIMS:
            self.shim_symbol(pkg_path, name)
        prefix = self.prefixes.get(pkg_path)
        if prefix is None:  # tipo alcançado sem import direto
            prefix = self.free_prefix(escape(re.sub(r"\W", "_", pkg_path.rsplit("/", 1)[-1])))
            self.prefixes[pkg_path] = prefix
        self.used[prefix] = uri
        return f"{prefix}.{name}"
