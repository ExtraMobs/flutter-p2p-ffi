import os
import unittest

from g2d.audit import Finding, PackageReport, classify, frontier, parse_machine, ranked_findings, render_audit
from g2d.graph import init_deps, parse_go_list, topo_order
from g2d.services.dart_type import DartType
from g2d.services.naming import local_name, lower_camel, member_name, type_name
from g2d.model import parse_dump


class GraphTest(unittest.TestCase):
    def test_parse_go_list_concatenated(self):
        text = """{"ImportPath": "fmt", "Standard": true, "Imports": ["io"]}
{"ImportPath": "io", "Standard": true}
{"ImportPath": "ex.com/m", "Imports": ["fmt"], "Module": {"Path": "ex.com/m"}}"""
        pkgs = parse_go_list(text)
        self.assertEqual(pkgs["ex.com/m"], {"imports": ["fmt"], "standard": False, "module": "ex.com/m"})
        self.assertTrue(pkgs["io"]["standard"])

    def test_topo_order_deps_first_and_deterministic(self):
        pkgs = {
            "app": {"imports": ["b", "a", "unsafe"]},
            "a": {"imports": ["c"]},
            "b": {"imports": ["c"]},
            "c": {"imports": []},
        }
        self.assertEqual(topo_order(pkgs), ["c", "a", "b", "app"])

    def test_topo_order_is_go_init_order(self):
        # Go ≥ 1.21: um pacote por vez, o menor pronto. Em lotes sairia a, z, b.
        pkgs = {"a": {"imports": []}, "b": {"imports": ["a"]}, "z": {"imports": []}}
        self.assertEqual(topo_order(pkgs), ["a", "b", "z"])

    def test_init_deps(self):
        imports = {"x.io/cmd": ["fmt", "x.io/z", "x.io/a"], "x.io/a": ["x.io/b"],
                   "x.io/b": ["os"], "x.io/z": []}
        self.assertEqual(init_deps("x.io/cmd", imports), ["x.io/b", "x.io/a", "x.io/z"])
        self.assertIsNone(init_deps("x.io/cmd", {"x.io/cmd": ["x.io/falta"]}))


class NamingTest(unittest.TestCase):
    def test_lower_camel(self):
        cases = {"Name": "name", "HTTPServer": "httpServer", "URL": "url",
                 "MD5Sum": "md5Sum", "X": "x", "already": "already"}
        for go, dart in cases.items():
            self.assertEqual(lower_camel(go), dart)

    def test_non_ascii(self):
        self.assertEqual(local_name("Δ"), "$u0394")
        self.assertEqual(local_name("Δ0"), "$u03940")  # largura fixa: não é U+3940
        self.assertEqual(local_name("x𝔸"), "x$U0001d538")
        self.assertEqual(member_name("Δx"), "$u03b4x")  # exportado (IsUpper) → lowerCamel
        self.assertEqual(member_name("δx"), "_$u03b4x")
        self.assertEqual(type_name("Ωmega"), "$u03a9mega")
        self.assertEqual(type_name("ωmega"), "_$u03c9mega")

    def test_member_and_type_names(self):
        self.assertEqual(member_name("Greet"), "greet")
        self.assertEqual(member_name("add"), "_add")
        self.assertEqual(member_name("New"), "new$")  # palavra reservada
        self.assertEqual(type_name("Greeter"), "Greeter")
        self.assertEqual(type_name("point"), "_point")


class DartCoreNamesTest(unittest.TestCase):
    def test_core_names_are_escaped(self):
        self.assertEqual(type_name("Object"), "Object$")
        self.assertEqual(type_name("Map"), "Map$")
        self.assertEqual(member_name("Identical"), "identical$")
        self.assertEqual(local_name("int"), "int$")
        self.assertEqual(member_name("print"), "_print")  # privado: não colide
        self.assertEqual(member_name("Print"), "print")  # o gerado nunca usa o print do core

    def test_base_members_are_escaped(self):
        # Métodos Go que sobrescreveriam membros de go.Slice/go.GoMap/go.PtrView/Object.
        self.assertEqual(member_name("Delete"), "delete$")
        self.assertEqual(member_name("Value"), "value$")
        self.assertEqual(member_name("ToString"), "toString$")
        self.assertEqual(member_name("Len"), "len")


class DartTypeTest(unittest.TestCase):
    def test_render_and_nullability(self):
        m = DartType("go.GoMap", (DartType("K"), DartType("Pair", (DartType("A"), DartType("B")))))
        self.assertEqual(m, "go.GoMap<K, Pair<A, B>>")
        self.assertEqual(m.as_nullable(), "go.GoMap<K, Pair<A, B>>?")
        self.assertEqual(m.as_nullable().non_null(), m)
        self.assertEqual(m.args[1].args, ("A", "B"))  # estrutura, não texto

    def test_function_with_named_and_nested(self):
        inner = DartType.function(DartType("void"), [DartType("int")], nullable=True)
        f = DartType.function(DartType("R"), [inner, DartType("Map", ("K", "V"))])
        self.assertEqual(f, "R Function(void Function(int)?, Map<K, V>)")
        g = f.with_named("$rd", DartType("go.Defers", nullable=True))
        self.assertEqual(g, "R Function(void Function(int)?, Map<K, V>, {go.Defers? $rd})")
        self.assertEqual(DartType.function(DartType("void"), []).with_named("x", DartType("T")),
                         "void Function({T x})")

    def test_record(self):
        self.assertEqual(DartType.of_record([DartType("A"), DartType("B", nullable=True)]), "(A, B?)")


class ModelTest(unittest.TestCase):
    def test_rejects_other_schema(self):
        with self.assertRaises(ValueError):
            parse_dump({"tool": "goast", "schemaVersion": 1, "packages": []})


class AuditTest(unittest.TestCase):
    """Classificação e agrupamento do `g2d audit` sobre registros sintéticos."""

    def reports(self):
        f = Finding
        reports = {
            "x.io/asm": PackageReport("x.io/asm", [], asm=["a_amd64.s"]),
            "x.io/bad": PackageReport("x.io/bad", [], findings=[f("shim-ausente:errors", "e", "a.go:1:1"),
                                                                f("shim-ausente:errors", "e", "a.go:9:1")]),
            "x.io/leaf": PackageReport("x.io/leaf", []),
            "x.io/dart": PackageReport("x.io/dart", ["x.io/leaf"], dart=[f("dart:undefined_function", "error: pow", "3:4")]),
            "x.io/own": PackageReport("x.io/own", ["x.io/asm"], findings=[f("range:func", "r", "b.go:2:3")]),
            "x.io/top": PackageReport("x.io/top", ["x.io/bad", "x.io/leaf"], dart=[f("dart:eco", "eco", "1:1")]),
        }
        order = ["x.io/asm", "x.io/bad", "x.io/leaf", "x.io/dart", "x.io/own", "x.io/top"]
        classify(reports, order)
        return reports, order

    def test_status_precedence(self):
        reports, _ = self.reports()
        self.assertEqual({p: r.status for p, r in reports.items()}, {
            "x.io/asm": "substituicao", "x.io/bad": "unsupported", "x.io/leaf": "verde",
            "x.io/dart": "dart-invalido",
            "x.io/own": "unsupported",  # os próprios problemas contam mesmo com dep não verde
            "x.io/top": "bloqueado",
        })

    def test_frontier_and_echo(self):
        reports, order = self.reports()
        self.assertEqual(frontier(reports, order), ["x.io/bad", "x.io/dart"])
        self.assertEqual(ranked_findings(reports["x.io/top"]), [])  # eco da dep bloqueada

    def test_render_ranking_is_deterministic(self):
        reports, order = self.reports()
        meta = {"command": "c", "target": "x.io/top", "module": "m", "go": "go"}
        text = render_audit(reports, order, meta)
        self.assertEqual(text, render_audit(reports, order, meta))
        ranking = [ln.split("`")[1] for ln in text.split("## Ranking de códigos")[1].split("## Ranking por área")[0]
                   .splitlines() if ln.startswith("| `")]
        # fronteira primeiro; empate em pacotes → ocorrências (errors×2); range:func fora da fronteira
        self.assertEqual(ranking, ["shim-ausente:errors", "dart:undefined_function", "range:func"])
        self.assertIn("| verde | 1 | 16.7 |", text)

    def test_parse_machine(self):
        lib = os.path.join(os.sep, "tmp", "out", "lib")
        path = os.path.join(lib, "x.io", "a.dart").replace("\\", "\\\\")
        text = f"ERROR|COMPILE_TIME_ERROR|INVALID_ASSIGNMENT|{path}|3|7|1|a \| b\nlixo\n"
        got = parse_machine(text, lib)
        self.assertEqual(dict(got), {"x.io/a.dart": [Finding("dart:invalid_assignment", "error: a | b", "3:7")]})


if __name__ == "__main__":
    unittest.main()
