"""O dump JSON do goast: carga, `Package`, `Unsupported` e consultas puras
sobre a AST (os nós ficam como dicts)."""

import json
from dataclasses import dataclass

from g2d.graph import init_deps, is_std

SCHEMA_VERSION = 8


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


def is_blank(n):
    """O identificador em branco `_`."""
    return n["node"] == "Ident" and n["name"] == "_"


def unparen(n):
    """A expressão sem os parênteses em volta."""
    while n and n.get("node") == "ParenExpr":
        n = n["x"]
    return n


def pos_key(pos):
    """Chave "arquivo:offset" de uma posição (igual ao `decl` do goast)."""
    return f"{pos['file']}:{pos['offset']}"


def walk(node, funclits=True):
    """Os dicts da subárvore (nós e anotações `$`) em pré-ordem, na ordem do
    fonte. `funclits=False` não entra em func literals: o que é da função,
    não das closures dela. Pilha explícita: sem limite de recursão."""
    stack = [node]
    while stack:
        n = stack.pop()
        if isinstance(n, list):
            stack.extend(reversed(n))
        elif isinstance(n, dict) and (funclits or n.get("node") != "FuncLit"):
            yield n
            stack.extend(reversed([v for v in n.values() if isinstance(v, (dict, list))]))


def has_recover(node):
    """A função (sem contar func literals aninhadas) chama `recover()`?"""
    return any(n.get("node") == "CallExpr" and n["fun"]["node"] == "Ident" and n["fun"]["name"] == "recover"
               and n["fun"].get("$builtin") for n in walk(node, funclits=False))


def has_defer(node):
    """A função (sem contar func literals aninhadas) tem `defer`?"""
    return any(n.get("node") == "DeferStmt" for n in walk(node, funclits=False))


def has_bare_return(node):
    """A função (sem contar func literals aninhadas) tem `return` sem valores?"""
    return any(n.get("node") == "ReturnStmt" and not n["results"] for n in walk(node, funclits=False))


def uses_decl(node, decl):
    """Algum identificador da subárvore (closures inclusive) é a variável?"""
    return any(n.get("node") == "Ident" and n.get("$obj", {}).get("decl") == decl for n in walk(node))


def assigns_var(node, decl):
    """Atribuição direta à variável (`s = x`, `s, err = f()`, `s++`, `for s =
    range`), inclusive em func literais do corpo."""
    def is_var(n):
        n = unparen(n)
        return bool(n) and n.get("node") == "Ident" and n.get("$obj", {}).get("decl") == decl

    def assigns(n):
        k = n.get("node")
        return ((k == "AssignStmt" and any(is_var(x) for x in n["lhs"]))
                or (k == "IncDecStmt" and is_var(n["x"]))
                or (k == "RangeStmt" and n.get("tok") == "=" and (is_var(n.get("key")) or is_var(n.get("value")))))

    return any(assigns(n) for n in walk(node))


def mutates_receiver(body, decl):
    """O corpo pode mutar o receptor (valor)? Conservador: atribuição,
    ++/--, & ou chamada de método com raiz no receptor."""
    def root(n):
        while n["node"] in ("SelectorExpr", "IndexExpr", "ParenExpr"):
            if n["node"] == "SelectorExpr" and "$sel" not in n:
                return None
            n = n["x"]
        return n.get("$obj", {}).get("decl") if n["node"] == "Ident" else None

    def mutates(n):
        k = n.get("node")
        return ((k == "AssignStmt" and any(root(x) == decl for x in n["lhs"]))
                or (k == "IncDecStmt" and root(n["x"]) == decl)
                or (k == "UnaryExpr" and n["op"] == "&" and root(n["x"]) == decl)
                or (k == "CallExpr" and n["fun"]["node"] == "SelectorExpr"
                    and n["fun"].get("$sel", {}).get("kind") == "method" and root(n["fun"]["x"]) == decl))

    return any(mutates(n) for n in walk(body))


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
        """Descritor do tipo de uma expressão, ou None. Como o
        `types.Info.TypeOf`: sem `$type` (identificador que define, ex. a
        chave de `for i := range`), vale o tipo do objeto."""
        if not node:
            return None
        i = node.get("$type")
        if i is None:
            i = (node.get("$obj") or {}).get("type")
        return None if i is None else self.type_table[i]

    def type_at(self, t):
        """Descritor da typeTable pelo índice; um descritor passa direto."""
        return self.type_table[t] if isinstance(t, int) else t

    def recv_type(self, d):
        """Tipo do receptor de um método (FuncDecl): `T` ou `*T`."""
        return self.type_at(d["recv"]["list"][0]["type"]["$type"])


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
