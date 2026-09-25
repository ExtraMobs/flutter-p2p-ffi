"""Carga e acesso ao dump JSON do goast. Os nós da AST ficam como dicts."""

import json
from dataclasses import dataclass

SCHEMA_VERSION = 2


class Unsupported(Exception):
    """Construção Go ainda não coberta pelo transpilador."""

    def __init__(self, what, node=None):
        pos = node.get("pos") if isinstance(node, dict) else None
        where = f" em {pos['file']}:{pos['line']}:{pos['column']}" if pos else ""
        super().__init__(f"não suportado: {what}{where}")


@dataclass
class Package:
    path: str
    name: str
    files: list  # [{"path", "ast"}]
    imports: list
    type_table: list

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


def parse_dump(doc):
    if doc.get("tool") != "goast" or doc.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(
            f"dump incompatível: tool={doc.get('tool')!r} "
            f"schemaVersion={doc.get('schemaVersion')!r} (esperado goast v{SCHEMA_VERSION})"
        )
    return [
        Package(p["path"], p["name"], p["files"] or [], p["imports"] or [], p["typeTable"] or [])
        for p in doc["packages"]
    ]
