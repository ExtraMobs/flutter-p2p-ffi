"""Imports Dart usados e prefixos (qualificação de símbolos)."""

from g2d.config import BUILTIN_PREFIX, BUILTIN_URI, GOLANG, GOLANG_PREFIX, GOLANG_URI, GRAPH_URI, STDLIB_SHIMS
from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported
from g2d.services.naming import escape


class ImportTable(Service):
    """Imports Dart usados e prefixos (qualificação de símbolos)."""

    name = "imports"

    def __init__(self, engine):
        super().__init__(engine)
        self.used = {}  # prefixo → URI (só os realmente usados)
        self.prefixes = {}  # import path → prefixo
        for imp in self.pkg.imports:
            if imp["name"] == ".":
                # `import .`: os identificadores já trazem o pacote do objeto
                # e são qualificados pelo prefixo derivado do import path.
                continue
            if imp["name"] in ("_", GOLANG_PREFIX):
                raise Unsupported(f"import:{imp['name']}", f"import {imp['name']} {imp['path']}",
                                  self.import_spec(imp["path"]))
            self.prefixes.setdefault(imp["path"], escape(imp["name"]))

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
            prefix = escape(pkg_path.rsplit("/", 1)[-1])
            while prefix in self.used and self.used[prefix] != uri:
                prefix += "_"
            self.prefixes[pkg_path] = prefix
        self.used[prefix] = uri
        return f"{prefix}.{name}"
