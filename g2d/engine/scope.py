"""Estado do motor: fatos do pacote e escopo da função sendo emitida."""

from dataclasses import dataclass, field


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
    class_tparams: tuple = ("", "")  # (<T extends B>, dicionários) da struct genérica corrente


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
