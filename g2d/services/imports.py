"""Imports Dart usados e prefixos (qualificação de símbolos)."""

from g2d.config import BUILTIN_PREFIX, BUILTIN_URI, GOLANG, GOLANG_PREFIX, GOLANG_URI, STDLIB_SHIMS
from g2d.engine.behavior import Service
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
            if imp["name"] in ("_", ".", GOLANG_PREFIX):
                raise Unsupported(f"import {imp['name']} {imp['path']}")
            self.prefixes.setdefault(imp["path"], escape(imp["name"]))

    def directives(self):
        """`import '...' as p;` dos imports usados, em ordem."""
        return [f"import '{self.used[p]}' as {p};" for p in sorted(self.used)]

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
        if pkg_path not in STDLIB_SHIMS:
            raise Unsupported(f"pacote sem shim/transpilação: {pkg_path}")
        prefix = self.prefixes.get(pkg_path)
        if prefix is None:  # tipo alcançado sem import direto
            prefix = escape(pkg_path.rsplit("/", 1)[-1])
            while prefix in self.used and self.used[prefix] != STDLIB_SHIMS[pkg_path]:
                prefix += "_"
            self.prefixes[pkg_path] = prefix
        self.used[prefix] = STDLIB_SHIMS[pkg_path]
        return f"{prefix}.{name}"
