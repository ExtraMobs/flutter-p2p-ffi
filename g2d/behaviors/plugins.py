"""Plugins padrão: cada um instala um conjunto coeso de serviços, análises e
comportamentos no motor. Para injetar comportamento, acrescente um plugin
(ou substitua um destes) na lista passada ao Engine."""

from g2d.analysis import analyses
from g2d.behaviors import builtins, decls, exprs, fmtcheck, stmts
from g2d.behaviors.conversions import CONVERSIONS
from g2d.engine.behavior import Plugin
from g2d.services.assertions import Assertions
from g2d.services.calls import Calls
from g2d.services.consts import Literals
from g2d.services.control import ControlFlow
from g2d.services.descriptors import DescriptorRegistry
from g2d.services.functions import Functions
from g2d.services.goinfo import GoTypeInfo
from g2d.services.imports import ImportTable
from g2d.services.names import Naming
from g2d.services.operands import Operands
from g2d.services.promotion import Promotion
from g2d.services.types import TypeMapper
from g2d.services.typesys import TypeSystem
from g2d.services.values import ValueSemantics
from g2d.services.vardecls import VarDecls


class CorePlugin(Plugin):
    """Serviços, análises, pacote, structs, tipos nomeados, conversões e o
    núcleo de expressões e statements."""

    SERVICES = [ImportTable, Naming, TypeSystem, TypeMapper, DescriptorRegistry, ValueSemantics,
                Literals, GoTypeInfo, Operands, Calls, Assertions, ControlFlow, Functions,
                VarDecls, Promotion]
    ANALYSES = [analyses.ImplementsAnalysis, analyses.MethodsAnalysis, analyses.TopNamesAnalysis,
                analyses.BoxingAnalysis, analyses.LocalTypesAnalysis, analyses.RecoverAnalysis, analyses.InitVarsAnalysis]
    STMTS = [stmts.BlockStmt, stmts.ExprStmt, stmts.EmptyStmt, stmts.IncDecStmt, stmts.DeclStmt,
             stmts.ReturnStmt, stmts.AssignStmt, stmts.IfStmt, stmts.ForStmt, stmts.RangeStmt,
             stmts.BranchStmt, stmts.LabeledStmt, stmts.SwitchStmt]
    EXPRS = [exprs.Ident, exprs.ParenExpr, exprs.BasicLit, exprs.BinaryExpr, exprs.UnaryExpr,
             exprs.SelectorExpr, exprs.KeyValueExpr, exprs.CompositeLit, exprs.FuncLit,
             exprs.CallExpr, exprs.G2DTemp]

    def install(self, engine):
        for service in self.SERVICES:
            engine.register_service(service)
        for analysis in self.ANALYSES:
            engine.register_analysis(analysis)
        for s in self.STMTS:
            engine.register_stmt(s)
        for e in self.EXPRS:
            engine.register_expr(e)
        for conv in CONVERSIONS:
            engine.register_conversion(conv)
        engine.register_type_decl(decls.StructClass)
        engine.register_type_decl(decls.NamedClass)
        engine.register_type_decl(decls.NamedCompositeClass)
        engine.package_behavior = decls.PackageBehavior(engine)


class CollectionsPlugin(Plugin):
    """Slices, arrays, maps e strings indexáveis: índice, slicing e builtins."""

    def install(self, engine):
        engine.register_expr(exprs.IndexExpr)
        engine.register_expr(exprs.SliceExpr)
        for b in (builtins.Len, builtins.Cap, builtins.Append, builtins.Copy,
                  builtins.Delete, builtins.Make, builtins.Min, builtins.Max, builtins.Clear):
            engine.register_builtin(b)


class PointersPlugin(Plugin):
    """Desreferência e `new`."""

    def install(self, engine):
        engine.register_expr(exprs.StarExpr)
        engine.register_builtin(builtins.New)


class InterfacesPlugin(Plugin):
    """Interfaces (abstract mixin class), type assertion e type switch."""

    def install(self, engine):
        engine.register_type_decl(decls.InterfaceClass)
        engine.register_expr(exprs.TypeAssertExpr)
        engine.register_stmt(stmts.TypeSwitchStmt)


class DeferPlugin(Plugin):
    """defer / panic / recover."""

    def install(self, engine):
        engine.register_stmt(stmts.DeferStmt)
        engine.register_builtin(builtins.PanicBuiltin)
        engine.register_builtin(builtins.Recover)


class FmtPlugin(Plugin):
    """Recusa na transpilação os verbos que o shim `fmt` não formata."""

    def install(self, engine):
        engine.register_expr(fmtcheck.FmtVerbCheck)


DEFAULT_PLUGINS = [CorePlugin(), CollectionsPlugin(), PointersPlugin(), InterfacesPlugin(),
                   DeferPlugin(), FmtPlugin()]
