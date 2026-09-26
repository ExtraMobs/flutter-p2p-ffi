"""Motor do g2d: registros, injeção de comportamentos e plugins."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from g2d.behaviors.plugins import DEFAULT_PLUGINS, CollectionsPlugin
from g2d.engine import Engine
from g2d.engine.behavior import NOT_HANDLED, BuiltinBehavior, ExprBehavior, Plugin
from g2d.engine.precedence import POSTFIX
from g2d.engine.registry import ChainRegistry, HandlerRegistry
from g2d.model import Unsupported, link_packages, parse_dump
from g2d.services.names import Naming

GOLDEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "golden")
GOAST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools", "goast")


def load(case):
    with open(os.path.join(GOLDEN, case, case + ".goast.json"), encoding="utf-8") as f:
        (pkg,) = parse_dump(json.load(f))
    return pkg


def dump_source(src):
    """Pacote de um fonte Go avulso, via goast (modo loose)."""
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "main.go"), "w", encoding="utf-8") as f:
            f.write(src)
        out = subprocess.run(["go", "run", ".", "dump", tmp], cwd=GOAST, capture_output=True,
                             text=True, encoding="utf-8", check=True).stdout
    (pkg,) = parse_dump(json.loads(out))
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


@unittest.skipUnless(shutil.which("go"), "go ausente")
class UnsupportedTest(unittest.TestCase):
    """Código estável e posição real (a auditoria agrupa e localiza por eles)."""

    def emit_error(self, src):
        with self.assertRaises(Unsupported) as cm:
            Engine(dump_source(src)).emit_package()
        e = cm.exception
        return e.code, (e.pos["file"], e.pos["line"], e.pos["column"]) if e.pos else None

    def test_node_position(self):
        src = 'package main\n\nfunc main() {\n\tb := []byte{}\n\tb = append(b, "x"...)\n\t_ = b\n}\n'
        self.assertEqual(self.emit_error(src), ("append-string", ("main.go", 5, 6)))

    def test_falls_back_to_declaration(self):
        src = 'package main\n\nimport "errors"\n\nvar E = errors.New("x")\n\nfunc main() { _ = E }\n'
        self.assertEqual(self.emit_error(src), ("shim-ausente:errors", ("main.go", 5, 5)))

    def test_doc_comment_is_not_the_position(self):
        src = 'package main\n\nimport "errors"\n\n// F documenta.\nfunc F() error { return errors.New("x") }\n\nfunc main() {}\n'
        self.assertEqual(self.emit_error(src), ("shim-ausente:errors", ("main.go", 6, 6)))  # nome de F

    def test_error_inside_closure_in_loop(self):
        """O erro real sobe; antes o escopo trocado pela closure virava IndexError."""
        src = ('package main\n\nimport "strings"\n\nfunc main() {\n\tfor _, s := range []string{"a"} {\n'
               '\t\tf := func() string { return strings.ToUpper(s) }\n\t\t_ = f\n\t}\n}\n')
        self.assertEqual(self.emit_error(src), ("shim-ausente:strings", ("main.go", 5, 6)))  # decl de main

    def test_bodyless_func(self):
        src = "package main\n\nfunc fastrand() uint64\n\nfunc main() {}\n"
        self.assertEqual(self.emit_error(src), ("func-sem-corpo", ("main.go", 3, 6)))

    def test_missing_shim_symbol(self):
        """Símbolo que o shim não tem é recusado (antes: chamada Dart inexistente)."""
        src = 'package main\n\nimport "math"\n\nfunc main() { _ = math.Sqrt(2) }\n'
        self.assertEqual(self.emit_error(src)[0], "shim-simbolo:math.sqrt")

    def test_import_spec_position(self):
        src = 'package main\n\nimport _ "fmt"\n\nfunc main() {}\n'
        self.assertEqual(self.emit_error(src), ("import:_", ("main.go", 3, 8)))

    def test_main_without_graph(self):
        """main transpilado sem as dependências no dump: init incompleto
        vira erro explícito, não Dart que pula inicialização."""
        with open(os.path.join(GOLDEN, "multiinit", "multiinit.goast.json"), encoding="utf-8") as f:
            pkgs = parse_dump(json.load(f))
        (main,) = link_packages([p for p in pkgs if p.name == "main"])
        with self.assertRaises(Unsupported) as cm:
            Engine(main).emit_package()
        self.assertEqual(cm.exception.code, "init-grafo-incompleto")
        self.assertEqual(cm.exception.pos["line"], 8)  # import de .../a


if __name__ == "__main__":
    unittest.main()
