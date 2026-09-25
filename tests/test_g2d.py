import unittest

from g2d.graph import parse_go_list, topo_order
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


class NamingTest(unittest.TestCase):
    def test_lower_camel(self):
        cases = {"Name": "name", "HTTPServer": "httpServer", "URL": "url",
                 "MD5Sum": "md5Sum", "X": "x", "already": "already"}
        for go, dart in cases.items():
            self.assertEqual(lower_camel(go), dart)

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


if __name__ == "__main__":
    unittest.main()
