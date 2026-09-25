"""Pré-passos sobre as declarações do pacote (rodam antes da emissão e
gravam em `engine.facts`)."""

from g2d.analysis.helpers import has_recover, pos_key
from g2d.config import BUILTIN_PREFIX, GOLANG_PREFIX
from g2d.engine.behavior import Analysis
from g2d.services.naming import member_name, type_name


class ImplementsAnalysis(Analysis):
    """Tipo nomeado → interfaces que satisfaz (calculado pelo goast)."""

    def run(self, decls):
        self.facts.implements = {e["type"]: e["interfaces"] for e in self.pkg.implements}


class MethodsAnalysis(Analysis):
    """Métodos agrupados pelo tipo do receptor (a classe os emite)."""

    def run(self, decls):
        for d in decls:
            if d["node"] == "FuncDecl" and d["recv"]:
                recv_t = self.pkg.type_at(d["recv"]["list"][0]["type"]["$type"])
                if recv_t["kind"] == "pointer":
                    recv_t = self.pkg.type_at(recv_t["elem"])
                self.facts.methods.setdefault(recv_t["name"], []).append(d)


class TopNamesAnalysis(Analysis):
    """Nomes de nível de library que um local não pode sombrear."""

    def run(self, decls):
        names = self.facts.top_names
        names.update(self.imports.prefixes.values())
        names.update({BUILTIN_PREFIX, GOLANG_PREFIX})
        for d in decls:
            if d["node"] == "FuncDecl" and not d["recv"]:
                names.add(self.names.top_name(d["name"]["name"], "func"))
            elif d["node"] == "GenDecl" and d["tok"] in ("var", "const"):
                for spec in d["specs"]:
                    names.update(member_name(i["name"]) for i in spec["names"])
            elif d["node"] == "GenDecl" and d["tok"] == "type":
                names.update(type_name(s["name"]["name"]) for s in d["specs"])


class BoxingAnalysis(Analysis):
    """Variáveis não-struct cujo endereço é tomado (`&x`): moram numa go.Box."""

    def run(self, decls):
        self.visit(decls)

    def visit(self, node):
        if isinstance(node, list):
            for x in node:
                self.visit(x)
            return
        if not isinstance(node, dict):
            return
        if node.get("node") == "UnaryExpr" and node["op"] == "&":
            x = node["x"]
            while x["node"] == "ParenExpr":
                x = x["x"]
            obj = x.get("$obj") if x["node"] == "Ident" else None
            if obj and obj["kind"] == "var" and not self.typesys.is_value(self.pkg.type_of(x)):
                self.facts.boxed.add(obj["decl"])
        for v in node.values():
            if isinstance(v, (dict, list)):
                self.visit(v)


class RecoverAnalysis(Analysis):
    """Funções e métodos que chamam recover() diretamente (recebem `$rd`)."""

    def run(self, decls):
        self.facts.recoverers = {d["name"]["$obj"]["decl"] for d in decls
                                 if d["node"] == "FuncDecl" and d["body"] and has_recover(d["body"])}


class InitVarsAnalysis(Analysis):
    """Posição do nome de cada var de pacote com inicializador → (spec, índice)."""

    def run(self, decls):
        for d in decls:
            if d["node"] == "GenDecl" and d["tok"] == "var":
                for spec in d["specs"]:
                    if spec["values"]:
                        for i, ident in enumerate(spec["names"]):
                            self.facts.var_inits[pos_key(ident["namePos"])] = (spec, i)
