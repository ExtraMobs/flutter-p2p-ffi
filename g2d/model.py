"""Carga e acesso ao dump JSON do goast. Os nós da AST ficam como dicts."""

import json
from dataclasses import dataclass

from g2d.graph import init_deps, is_std

SCHEMA_VERSION = 7


class Unsupported(Exception):
    """Construção Go ainda não coberta pelo transpilador.

    `code` é estável por caso (`área` ou `área:detalhe`, ex. `range:func`,
    `shim-ausente:errors`): é por ele que a auditoria agrupa. `pos` é a
    posição do nó; sem nó, quem emite a declaração a completa (`locate`).
    """

    def __init__(self, code, what, node=None):
        super().__init__(code, what)
        self.code, self.what, self.pos = code, what, None
        self.locate(node)

    @classmethod
    def internal(cls, exc, node=None):
        """Exceção inesperada do g2d como registro (`erro-interno:<Tipo>`),
        com o ponto do g2d que falhou na mensagem."""
        import traceback

        tb = traceback.extract_tb(exc.__traceback__)[-1]
        where = f"{tb.filename.replace(chr(92), '/').rsplit('/g2d/', 1)[-1]}:{tb.lineno}"
        return cls(f"erro-interno:{type(exc).__name__}", f"{where}: {exc}", node)

    def locate(self, node):
        """Completa a posição com a do nó (se ainda não houver)."""
        if self.pos is None:
            self.pos = first_pos(node)
        return self

    def __str__(self):
        where = f" em {self.pos['file']}:{self.pos['line']}:{self.pos['column']}" if self.pos else ""
        return f"não suportado [{self.code}]: {self.what}{where}"


def first_pos(node):
    """Primeira posição (`token.Pos` do goast) na travessia do nó, em ordem
    de campos: o início da construção no fonte. Anotações `$` e comentários
    (`doc`/`comment`, que vêm antes da declaração) não contam."""
    if isinstance(node, dict):
        if "line" in node and "column" in node and "file" in node:
            return node
        values = (v for k, v in node.items() if not k.startswith("$") and k not in ("doc", "comment"))
    elif isinstance(node, list):
        values = node
    else:
        return None
    for v in values:
        pos = first_pos(v)
        if pos is not None:
            return pos
    return None


@dataclass
class Package:
    path: str
    name: str
    files: list  # [{"path", "ast"}]
    imports: list
    type_table: list
    implements: list  # [{"type": i, "interfaces": [j, ...]}]
    init_order: list  # [[decl, ...], ...] (types.Info.InitOrder)
    other_files: list = ()  # não-Go no contexto de build (.s = assembly)
    module: dict = None  # {"path", "version"?}; None no modo loose
    stdlib_usage: list = ()  # "pacote.Símbolo" da stdlib usados
    reflect_usage: list = ()  # [{"pos", "expr"}]
    go_version: str = ""
    # main: pacotes do grafo a inicializar antes dele, na ordem do Go
    # (link_packages); None = grafo desconhecido.
    init_deps: list = None

    def graph_imports(self):
        """Imports diretos que são pacotes do grafo (fora da stdlib)."""
        return sorted({i["path"] for i in self.imports if not is_std(i["path"])})

    def type_of(self, node):
        """Descritor do tipo ($type) de uma expressão, ou None."""
        i = node.get("$type") if node else None
        return None if i is None else self.type_table[i]

    def type_at(self, index):
        return self.type_table[index]


def load_dump(path):
    """Lê um dump do goast e devolve a lista de Package."""
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    return parse_dump(doc)


def link_packages(pkgs):
    """Liga os pacotes carregados juntos: cada `main` recebe `init_deps`
    (None se o grafo dele não está todo aqui)."""
    imports = {p.path: [i["path"] for i in p.imports] for p in pkgs}
    for p in pkgs:
        if p.name == "main":
            p.init_deps = init_deps(p.path, imports)
    return pkgs


def parse_dump(doc):
    if doc.get("tool") != "goast" or doc.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(
            f"dump incompatível: tool={doc.get('tool')!r} "
            f"schemaVersion={doc.get('schemaVersion')!r} (esperado goast v{SCHEMA_VERSION})"
        )
    return [
        Package(p["path"], p["name"], p["files"] or [], p["imports"] or [], p["typeTable"] or [],
                p.get("implements") or [], p.get("initOrder") or [],
                p.get("otherFiles") or [], p.get("module"), p.get("stdlibUsage") or [],
                p.get("reflectUsage") or [], doc.get("goVersion", ""))
        for p in doc["packages"]
    ]
