"""Estado do motor: fatos do pacote e escopo da função sendo emitida."""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class TypeParams:
    """Parâmetros de tipo de uma função/struct genérica (estruturados)."""

    names: tuple = ()  # T, U
    bounds: tuple = ()  # bound Dart de cada um (ou None)
    dicts: tuple = ()  # parâmetros dicionário: `go.Elem<T> $T`

    @property
    def decl(self):
        """`<T extends B, U>` (vazio sem parâmetros)."""
        if not self.names:
            return ""
        return "<" + ", ".join(n + (f" extends {b}" if b else "") for n, b in zip(self.names, self.bounds)) + ">"


@dataclass
class Facts:
    """Resultados das análises do pacote, lidos pelos comportamentos."""

    methods: dict = field(default_factory=dict)  # nome do tipo Go → [FuncDecl]
    top_names: set = field(default_factory=set)  # nomes de library que locais não podem sombrear
    boxed: set = field(default_factory=set)  # decl de variáveis não-struct com `&x`
    recoverers: set = field(default_factory=set)  # decl de funções que chamam recover()
    var_inits: dict = field(default_factory=dict)  # posição de var de pacote → (ValueSpec, índice)
    init_funcs: list = field(default_factory=list)  # nomes Dart das funções init, em ordem
    implements: dict = field(default_factory=dict)  # tipo nomeado → interfaces (índices)
    class_tparams: TypeParams = TypeParams()  # parâmetros da struct genérica corrente
    local_types: dict = field(default_factory=dict)  # id(descritor) → nome Go içado (`first$pair`)
    local_specs: list = field(default_factory=list)  # [(TypeSpec, nome içado)] na ordem do fonte
    local_targs: dict = field(default_factory=dict)  # id(tipo local) → parâmetros de tipo da função genérica
    local_tparams: dict = field(default_factory=dict)  # id(tipo local) → campos typeParams da função
    synthetic: dict = field(default_factory=dict)  # índice da typeTable → nome Go da classe anônima


@dataclass
class FunctionScope:
    """Estado de uma função Go (compartilhado com as func literals dela)."""

    used: set = field(default_factory=set)  # nomes Dart de locais já usados
    locals: dict = field(default_factory=dict)  # decl → nome Dart
    temps: int = 0
    recv: str = None  # decl do receptor mapeado para `this`
    results: list = None  # nomes dos resultados (nomeados ou sintetizados)
    sig: dict = None  # assinatura da função corrente
    defers: str = None  # variável go.Defers da função (se tem defer)
    rd: str = None  # parâmetro `$rd` (se chama recover())
    breaks: list = field(default_factory=list)  # alvos de break: None (laço) ou rótulo (switch)
    used_labels: set = field(default_factory=set)
