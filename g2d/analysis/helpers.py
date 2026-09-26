"""Consultas puras sobre a AST Go (sem estado): usadas por análises e comportamentos."""



def doc_comment(group):
    """CommentGroup Go → linhas `///`."""
    if not group:
        return []
    lines = []
    for c in group["list"]:
        text = c["text"]
        if text.startswith("//"):
            lines.append("///" + (text[2:] if text[2:3] in ("", " ") else " " + text[2:]))
        else:
            for ln in text[2:-2].strip("\n").split("\n"):
                lines.append(("/// " + ln.strip()).rstrip())
    return lines


def is_blank(n):
    """O identificador em branco `_`."""
    return n["node"] == "Ident" and n["name"] == "_"


def has_recover(node):
    """A função (sem contar func literals aninhadas) chama `recover()`?"""
    if isinstance(node, list):
        return any(has_recover(x) for x in node)
    if not isinstance(node, dict) or node.get("node") == "FuncLit":
        return False
    if (node.get("node") == "CallExpr" and node["fun"]["node"] == "Ident"
            and node["fun"]["name"] == "recover" and node["fun"].get("$builtin")):
        return True
    return any(has_recover(v) for v in node.values() if isinstance(v, (dict, list)))


def has_defer(node):
    """A função (sem contar func literals aninhadas) tem `defer`?"""
    if isinstance(node, list):
        return any(has_defer(x) for x in node)
    if not isinstance(node, dict) or node.get("node") == "FuncLit":
        return False
    if node.get("node") == "DeferStmt":
        return True
    return any(has_defer(v) for v in node.values() if isinstance(v, (dict, list)))


def has_bare_return(node):
    """A função (sem contar func literals aninhadas) tem `return` sem valores?"""
    if isinstance(node, list):
        return any(has_bare_return(x) for x in node)
    if not isinstance(node, dict) or node.get("node") == "FuncLit":
        return False
    if node.get("node") == "ReturnStmt" and not node["results"]:
        return True
    return any(has_bare_return(v) for v in node.values() if isinstance(v, (dict, list)))


def pos_key(pos):
    """Chave "arquivo:offset" de uma posição (igual ao `decl` do goast)."""
    return f"{pos['file']}:{pos['offset']}"


def tuple_expr(items):
    """Um valor ou um record Dart `(a, b)` (múltiplos resultados)."""
    return items[0] if len(items) == 1 else "(" + ", ".join(items) + ")"


def uses_decl(node, decl):
    if isinstance(node, list):
        return any(uses_decl(x, decl) for x in node)
    if not isinstance(node, dict):
        return False
    if node.get("node") == "Ident" and node.get("$obj", {}).get("decl") == decl:
        return True
    return any(uses_decl(v, decl) for v in node.values() if isinstance(v, (dict, list)))


def assigns_var(node, decl):
    """Atribuição direta à variável (`s = x`, `s, err = f()`, `s++`, `for s =
    range`), inclusive em func literais do corpo."""
    def is_var(n):
        while n and n.get("node") == "ParenExpr":
            n = n["x"]
        return bool(n) and n.get("node") == "Ident" and n.get("$obj", {}).get("decl") == decl

    if isinstance(node, list):
        return any(assigns_var(x, decl) for x in node)
    if not isinstance(node, dict):
        return False
    k = node.get("node")
    if k == "AssignStmt" and any(is_var(x) for x in node["lhs"]):
        return True
    if k == "IncDecStmt" and is_var(node["x"]):
        return True
    if k == "RangeStmt" and node.get("tok") == "=" and (is_var(node.get("key")) or is_var(node.get("value"))):
        return True
    return any(assigns_var(v, decl) for v in node.values() if isinstance(v, (dict, list)))


def mutates_receiver(body, decl):
    """O corpo pode mutar o receptor (valor)? Conservador: atribuição,
    ++/--, & ou chamada de método com raiz no receptor."""
    def root(n):
        while n["node"] in ("SelectorExpr", "IndexExpr", "ParenExpr"):
            if n["node"] == "SelectorExpr" and "$sel" not in n:
                return None
            n = n["x"]
        return n.get("$obj", {}).get("decl") if n["node"] == "Ident" else None

    def visit(n):
        if isinstance(n, list):
            return any(visit(x) for x in n)
        if not isinstance(n, dict):
            return False
        k = n.get("node")
        if k == "AssignStmt" and any(root(x) == decl for x in n["lhs"]):
            return True
        if k == "IncDecStmt" and root(n["x"]) == decl:
            return True
        if k == "UnaryExpr" and n["op"] == "&" and root(n["x"]) == decl:
            return True
        if (k == "CallExpr" and n["fun"]["node"] == "SelectorExpr"
                and n["fun"].get("$sel", {}).get("kind") == "method" and root(n["fun"]["x"]) == decl):
            return True
        return any(visit(v) for v in n.values() if isinstance(v, (dict, list)))
    return visit(body)
