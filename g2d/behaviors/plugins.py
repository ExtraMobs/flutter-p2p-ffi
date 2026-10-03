"""Plugins padrão: cada um instala um conjunto coeso de serviços, análises e
comportamentos no motor. Para injetar comportamento, acrescente um plugin
(ou substitua um destes) na lista passada ao Engine."""

from g2d.analysis import analyses, color
from g2d.behaviors import builtins, decls, exprs, fmtcheck, stmts
from g2d.behaviors.conversions import CONVERSIONS
from g2d.engine.behavior import Plugin
from g2d.services.assertions import Assertions
from g2d.services.calls import Calls
from g2d.services.concurrency import Concurrency
from g2d.services.control import ControlFlow
from g2d.services.descriptors import DescriptorRegistry
from g2d.services.dualio import DualIO
from g2d.services.evalorder import EvalOrder
from g2d.services.functions import Functions
from g2d.services.goinfo import GoTypeInfo
from g2d.services.imports import ImportTable
from g2d.services.literals import Literals
from g2d.services.naming import Naming
from g2d.services.operands import Operands
from g2d.services.promotion import Promotion
from g2d.services.types import TypeMapper
from g2d.services.typesys import TypeSystem
from g2d.services.values import ValueSemantics
from g2d.services.vardecls import VarDecls


class CorePlugin(Plugin):
    """Serviços, análises, pacote, structs, tipos nomeados, conversões, o
    núcleo de expressões e statements e os builtins numéricos."""

    SERVICES = [ImportTable, Naming, TypeSystem, TypeMapper, DescriptorRegistry, ValueSemantics,
                Literals, GoTypeInfo, Operands, Calls, Assertions, ControlFlow, Functions,
                VarDecls, Promotion, EvalOrder]
    ANALYSES = [analyses.ImplementsAnalysis, analyses.MethodsAnalysis, analyses.TopNamesAnalysis,
                analyses.BoxingAnalysis, analyses.LocalTypesAnalysis, analyses.RecoverAnalysis, analyses.InitVarsAnalysis,
                analyses.InitFuncsAnalysis]
    STMTS = [stmts.BlockStmt, stmts.ExprStmt, stmts.EmptyStmt, stmts.IncDecStmt, stmts.DeclStmt,
             stmts.ReturnStmt, stmts.AssignStmt, stmts.IfStmt, stmts.ForStmt, stmts.RangeStmt,
             stmts.BranchStmt, stmts.LabeledStmt, stmts.SwitchStmt]
    EXPRS = [exprs.Ident, exprs.ParenExpr, exprs.BasicLit, exprs.BinaryExpr, exprs.UnaryExpr,
             exprs.SelectorExpr, exprs.KeyValueExpr, exprs.CompositeLit, exprs.FuncLit,
             exprs.CallExpr, exprs.G2DTemp]
    BUILTINS = [builtins.Min, builtins.Max, builtins.Real, builtins.Imag, builtins.ComplexBuiltin]

    def install(self, engine):
        for service in self.SERVICES:
            engine.register_service(service)
        for analysis in self.ANALYSES:
            engine.register_analysis(analysis)
        for s in self.STMTS:
            engine.register_stmt(s)
        for e in self.EXPRS:
            engine.register_expr(e)
        for b in self.BUILTINS:
            engine.register_builtin(b)
        for conv in CONVERSIONS:
            engine.register_conversion(conv)
        engine.register_type_decl(decls.StructClass)
        engine.register_type_decl(decls.NamedClass)
        engine.register_type_decl(decls.NamedCompositeClass)
        engine.package_behavior = decls.PackageBehavior(engine)


class CollectionsPlugin(Plugin):
    """Slices, arrays, maps e strings indexáveis: índice, slicing e os builtins
    deles."""

    def install(self, engine):
        engine.register_expr(exprs.IndexExpr)
        engine.register_expr(exprs.FuncInstance)  # antes do IndexExpr na cadeia
        engine.register_expr(exprs.SliceExpr)
        for b in (builtins.Len, builtins.Cap, builtins.Append, builtins.Copy,
                  builtins.Delete, builtins.Make, builtins.Clear):
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


class ConcurrencyPlugin(Plugin):
    """Goroutines, canais e `select` (M4): `go`, `ch <- v`, `<-ch`, `close`,
    `range` sobre chan (em RangeStmt/CollectionsPlugin) e a cor `async` das
    funções que suspendem diretamente."""

    def install(self, engine):
        engine.register_service(Concurrency)
        engine.register_service(DualIO)
        engine.register_analysis(color.ColorAnalysis)
        engine.register_expr(exprs.AsyncCall)
        engine.register_expr(exprs.AsyncValueGuard)
        engine.register_stmt(stmts.SendStmt)
        engine.register_stmt(stmts.GoStmt)
        engine.register_stmt(stmts.SelectStmt)
        engine.register_builtin(builtins.Close)


DEFAULT_PLUGINS = [CorePlugin(), CollectionsPlugin(), PointersPlugin(), InterfacesPlugin(),
                   DeferPlugin(), FmtPlugin(), ConcurrencyPlugin()]
