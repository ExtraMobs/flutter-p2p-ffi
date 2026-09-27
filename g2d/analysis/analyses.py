"""Pré-passos sobre as declarações do pacote (rodam antes da emissão e
gravam em `engine.facts`)."""

from g2d.config import BUILTIN_PREFIX, GOLANG_PREFIX
from g2d.engine.behavior import Analysis
from g2d.model import has_recover, pos_key, unparen, walk
from g2d.services.naming import top_member_name, type_name


class ImplementsAnalysis(Analysis):
    """Tipo nomeado → interfaces que satisfaz (calculado pelo goast)."""

    def run(self, decls):
        self.facts.implements = {e["type"]: e["interfaces"] for e in self.pkg.implements}


class MethodsAnalysis(Analysis):
    """Métodos agrupados pelo tipo do receptor (a classe os emite)."""

    def run(self, decls):
        for d in decls:
            if d["node"] == "FuncDecl" and d["recv"]:
                recv_t = self.pkg.recv_type(d)
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
                names.add(self.names.top_name(d["name"]["name"], "func", d["name"]["$obj"].get("fold")))
            elif d["node"] == "GenDecl" and d["tok"] in ("var", "const"):
                for spec in d["specs"]:
                    names.update(top_member_name(i["name"], (i.get("$obj") or {}).get("fold")) for i in spec["names"])
            elif d["node"] == "GenDecl" and d["tok"] == "type":
                names.update(type_name(s["name"]["name"]) for s in d["specs"])


class BoxingAnalysis(Analysis):
    """Variáveis não-struct cujo endereço é tomado (`&x`): moram numa go.Box."""

    def run(self, decls):
        for node in walk(decls):
            if node.get("node") == "UnaryExpr" and node["op"] == "&":
                x = unparen(node["x"])
                obj = x.get("$obj") if x["node"] == "Ident" else None
                if obj and obj["kind"] == "var" and not self.typesys.is_value(self.pkg.type_of(x)):
                    self.facts.boxed.add(obj["decl"])
            elif node.get("node") == "SelectorExpr" and (node.get("$sel") or {}).get("kind") == "method":
                # Chamada/method value com receptor ponteiro sobre N endereçável: `&x`.
                x = unparen(node["x"])
                obj = x.get("$obj") if x["node"] == "Ident" else None
                t = self.pkg.type_of(x)
                if (obj and obj["kind"] == "var" and len(node["$sel"]["index"]) == 1
                        and self.typesys.ptr_class(t)
                        and any(m["name"] == node["sel"]["name"] and m["ptr"] for m in t["methods"])):
                    self.facts.boxed.add(obj["decl"])


class LocalTypesAnalysis(Analysis):
    """Tipos declarados dentro de funções: içados para a library com nome
    único `<função>$<Tipo>` (o go/types já os distingue na typeTable)."""

    def run(self, decls):
        used = set()
        for d in decls:
            if d["node"] != "FuncDecl" or not d["body"]:
                continue
            owner = d["name"]["name"]
            if d["recv"]:
                recv_t = self.pkg.recv_type(d)
                if recv_t["kind"] == "pointer":
                    recv_t = self.pkg.type_at(recv_t["elem"])
                owner = f"{recv_t['name']}_{owner}"
            for spec in self.type_specs(d["body"]):
                base = f"{owner[:1].lower()}{owner[1:]}${spec['name']['name']}"
                name, n = base, 1
                while name in used:
                    n += 1
                    name = f"{base}{n}"
                used.add(name)
                lt = id(self.pkg.type_at(spec["name"]["$obj"]["type"]))
                self.facts.local_types[lt] = name
                self.facts.local_specs.append((spec, name))
                tparams = d["type"].get("typeParams")
                if tparams and tparams.get("list"):
                    # Tipo local de função genérica: vira classe genérica nos
                    # parâmetros da função (`Wrap[T]` → `_wrap$box$<T>`).
                    self.facts.local_tparams[lt] = tparams
                    self.facts.local_targs[lt] = [i["$obj"]["type"] for f in tparams["list"] for i in f["names"]]

    @staticmethod
    def type_specs(body):
        """TypeSpecs locais (sem alias), na ordem do fonte: ela define os nomes."""
        return [s for n in walk(body) if n.get("node") == "DeclStmt" and n["decl"]["tok"] == "type"
                for s in n["decl"]["specs"] if not s["assign"]]


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
