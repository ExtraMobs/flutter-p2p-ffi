"""Motor do g2d: registros, injeção de comportamentos e plugins."""

import json
import os
import unittest

from g2d.behaviors.plugins import DEFAULT_PLUGINS, CollectionsPlugin
from g2d.engine import Engine
from g2d.engine.behavior import NOT_HANDLED, BuiltinBehavior, ExprBehavior, Plugin
from g2d.engine.precedence import POSTFIX
from g2d.engine.registry import ChainRegistry, HandlerRegistry
from g2d.model import Unsupported, parse_dump
from g2d.services.names import Naming

GOLDEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "golden")


def load(case):
    with open(os.path.join(GOLDEN, case, case + ".goast.json"), encoding="utf-8") as f:
        (pkg,) = parse_dump(json.load(f))
    return pkg


class Fixed:
    def __init__(self, value):
        self.value = value

    def emit(self, *args):
        return self.value


class RegistryTest(unittest.TestCase):
    def test_last_registered_wins(self):
        r = HandlerRegistry()
        r.register("k", Fixed("antigo"))
        r.register("k", Fixed("novo"))
        self.assertEqual(r.dispatch("k"), "novo")

    def test_not_handled_falls_back(self):
        r = HandlerRegistry()
        r.register("k", Fixed("base"))
        r.register("k", Fixed(NOT_HANDLED))
        self.assertEqual(r.dispatch("k"), "base")
        self.assertIs(r.dispatch("outra"), NOT_HANDLED)

    def test_chain_prefers_last_accepting(self):
        class Accepts:
            def __init__(self, ok, tag):
                self.ok, self.tag = ok, tag

            def accepts(self, *_):
                return self.ok

        c = ChainRegistry()
        c.register(Accepts(True, "primeiro"))
        c.register(Accepts(False, "recusa"))
        c.register(Accepts(True, "último"))
        self.assertEqual(c.find().tag, "último")


class LenAsCall(BuiltinBehavior):
    """Substitui `len`: sempre trata."""

    name = "len"

    def emit(self, n, args):
        return f"lenOf({self.expr(args[0])})", POSTFIX


class PrintlnAsPrint(ExprBehavior):
    """Especializa CallExpr só para fmt.Println; o resto cai no padrão."""

    kinds = ("CallExpr",)

    def emit(self, n):
        fun = n["fun"]
        if not (fun["node"] == "SelectorExpr" and fun["sel"]["name"] == "Println"):
            return NOT_HANDLED
        return f"print([{', '.join(self.expr(a) for a in n['args'] or [])}])", POSTFIX


class TestPlugin(Plugin):
    def install(self, engine):
        engine.register_builtin(LenAsCall)
        engine.register_expr(PrintlnAsPrint)


class InjectionTest(unittest.TestCase):
    def test_default_is_unchanged(self):
        out = Engine(load("hello")).emit_package()
        self.assertIn("fmt.println(", out)

    def test_plugin_replaces_and_specializes(self):
        out = Engine(load("basics"), plugins=[*DEFAULT_PLUGINS, TestPlugin()]).emit_package()
        self.assertIn("lenOf(", out)  # builtin substituído
        self.assertIn("print([", out)  # CallExpr especializado para Println
        self.assertNotIn("fmt.println(", out)
        self.assertIn("_divmod(", out)  # demais chamadas: comportamento padrão

    def test_behavior_comes_from_plugin(self):
        plugins = [p for p in DEFAULT_PLUGINS if not isinstance(p, CollectionsPlugin)]
        with self.assertRaises(Unsupported):
            Engine(load("collections"), plugins=plugins).emit_package()

    def test_service_can_be_replaced(self):
        class LoudNaming(Naming):
            def temp(self):
                self.scope.temps += 1
                return f"$tmp{self.scope.temps}"

        engine = Engine(load("basics"))
        engine.services.replace(LoudNaming(engine))
        out = engine.emit_package()
        self.assertIn("$tmp1", out)
        self.assertNotIn("$t1 ", out)


if __name__ == "__main__":
    unittest.main()
