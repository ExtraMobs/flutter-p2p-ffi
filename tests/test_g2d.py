import unittest

from g2d.graph import parse_go_list, topo_order
from g2d.mapping import lower_camel, member_name, type_name
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


class ModelTest(unittest.TestCase):
    def test_rejects_other_schema(self):
        with self.assertRaises(ValueError):
            parse_dump({"tool": "goast", "schemaVersion": 1, "packages": []})


if __name__ == "__main__":
    unittest.main()
