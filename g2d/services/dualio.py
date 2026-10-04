"""I/O que suspende (decisão D2): versão dupla dos métodos de I/O.

Cada método de interface de I/O do shim (`io.Reader.Read`...) existe em duas
formas no Dart: `read` (síncrono) e `read$async` (`Future`); o mesmo vale
para as funções do shim que os chamam (`io.ReadAll` e `io.readAll$async`).
Quem escolhe é a cor (`g2d/analysis/color.py`):

- o grupo de cor de um método de interface de I/O junta as implementações
  do grafo (união do `implements`); ele é `async` quando alguma delas
  suspende (`io.Pipe`, uma goroutine servidora atrás de canal...);
- todo membro de um grupo dual declara as duas formas: o corpo real mora na
  forma da cor do grupo, e a outra é derivada (`$async` síncrono embrulhado,
  ou o síncrono que cai no `fatal` `g2d:` de `go.syncOfAsync`, que o g2d
  nunca chama);
- quem chama pelo grupo `async` usa `await x.read$async(p)`;
- tipo concreto do shim (`bytes.Buffer`, `strings.Reader`...) nunca suspende
  (exceto `ASYNC_SHIM_METHODS`): chamá-lo direto é síncrono, seja qual for a
  cor do grupo, e ele tem as duas formas (mixins `io.*Sync`);
- uma função do shim com versão `$async` (`DUAL_SHIM_CALLS`) é `async` na
  chamada quando o método que o shim chama no argumento é `async` para o
  tipo ESTÁTICO do argumento: `fmt.Fprintf(&buf, ...)` com `*bytes.Buffer`
  fica síncrono mesmo com `io.Writer.Write` async no grafo.
"""

from g2d.config import SHIM_INTERFACES
from g2d.engine.behavior import Service
from g2d.graph import is_std
from g2d.model import Unsupported, unparen
from g2d.services.naming import member_name

# Interfaces de I/O do shim com versão dupla: os métodos que têm `$async`.
DUAL_IFACES = {
    ("io", "Reader"): ("Read",),
    ("io", "Writer"): ("Write",),
    ("io", "ByteReader"): ("ReadByte",),
    ("io", "ByteWriter"): ("WriteByte",),
    ("io", "StringWriter"): ("WriteString",),
    ("io", "Closer"): ("Close",),
    ("io", "ReaderAt"): ("ReadAt",),
    ("io", "WriterAt"): ("WriteAt",),
    ("io", "ReadCloser"): ("Read", "Close"),
    ("io", "WriteCloser"): ("Write", "Close"),
    ("io", "ReadWriter"): ("Read", "Write"),
    ("io", "ReadWriteCloser"): ("Read", "Write", "Close"),
    ("io", "ReadSeeker"): ("Read",),
    ("io", "WriteSeeker"): ("Write",),
    ("io", "ReadWriteSeeker"): ("Read", "Write"),
    ("io", "ReadSeekCloser"): ("Read", "Close"),
    ("io", "ByteScanner"): ("ReadByte",),
    ("io", "ReaderFrom"): ("ReadFrom",),
    ("io", "WriterTo"): ("WriteTo",),
}
DUAL_METHODS = frozenset(m for ms in DUAL_IFACES.values() for m in ms)

# Métodos de tipo do shim que sempre suspendem (o corpo é o `$async`).
ASYNC_SHIM_METHODS = frozenset({("m", "io", "PipeReader", "Read"), ("m", "io", "PipeWriter", "Write")})
# Tipo do shim que suspende → (método dele, interface onde entra): um
# pacote que cita o tipo liga os grupos (o valor pode virar a interface).
ASYNC_SHIM_TYPES = {
    ("io", "PipeReader"): (("Read", ("io", "Reader")),),
    ("io", "PipeWriter"): (("Write", ("io", "Writer")),),
}

# Interfaces do shim cujo valor é sempre um tipo do próprio shim (o `State`
# que o `fmt` passa ao `Format`): a chamada é síncrona, e o grupo delas não
# força o de `io.Writer` (um tipo gerado pode implementar as duas).
SYNC_SHIM_IFACES = frozenset({("fmt", "State")})

# Funções/métodos do shim com versão `$async`: (índice do argumento, método
# que o shim chama nele). ⚠️ `io.WriteString` e quem o usa testam
# `WriteString` no valor dinâmico; só o `Write` do tipo estático decide a
# forma (um `WriteString` que suspende atrás de um `io.Writer` síncrono cai
# no `fatal` `g2d:` do `syncOfAsync`, nunca num resultado errado).
DUAL_SHIM_CALLS = {
    ("f", "io", "ReadAll"): ((0, "Read"),),
    ("f", "io", "ReadFull"): ((0, "Read"),),
    ("f", "io", "ReadAtLeast"): ((0, "Read"),),
    ("f", "io", "WriteString"): ((0, "Write"),),
    ("f", "io", "Copy"): ((0, "Write"), (1, "Read")),
    ("f", "io", "CopyBuffer"): ((0, "Write"), (1, "Read")),
    ("f", "io", "CopyN"): ((0, "Write"), (1, "Read")),
    ("f", "fmt", "Fprint"): ((0, "Write"),),
    ("f", "fmt", "Fprintf"): ((0, "Write"),),
    ("f", "fmt", "Fprintln"): ((0, "Write"),),
    ("f", "encoding/binary", "Read"): ((0, "Read"),),
    ("f", "encoding/binary", "Write"): ((0, "Write"),),
    ("f", "encoding/binary", "ReadUvarint"): ((0, "ReadByte"),),
    ("f", "encoding/binary", "ReadVarint"): ((0, "ReadByte"),),
    ("m", "bytes", "Buffer", "ReadFrom"): ((0, "Read"),),
    ("m", "bytes", "Buffer", "WriteTo"): ((0, "Write"),),
    ("m", "bytes", "Reader", "WriteTo"): ((0, "Write"),),
    ("m", "strings", "Reader", "WriteTo"): ((0, "Write"),),
    ("m", "strings", "Replacer", "WriteString"): ((0, "Write"),),
}

# Funções do shim que só guardam a interface de I/O num tipo do shim que
# embrulha (`io.LimitReader`...): não chamam nada, e o embrulho tem as duas
# formas reais (a `$async` espera a de baixo). Não recusam argumento que
# suspende. ⚠️ O método do embrulho chamado direto pelo tipo concreto
# (`(*io.LimitedReader).Read`) é síncrono, como todo tipo do shim: sobre um
# leitor que suspende, cai no `fatal` `g2d:` do `syncOfAsync`.
WRAPPING_SHIM_CALLS = frozenset({
    ("f", "io", "LimitReader"), ("f", "io", "MultiReader"), ("f", "io", "MultiWriter"),
    ("f", "io", "TeeReader"), ("f", "io", "NopCloser"), ("f", "io", "NewSectionReader"),
    ("f", "io", "NewOffsetWriter"), ("f", "encoding/json", "NewEncoder"), ("f", "encoding/json", "NewDecoder"),
})


def _std(pkg):
    return pkg != "main" and is_std(pkg)


def dual_capable(key):
    """Método da stdlib com as duas formas no shim: método de uma interface
    de `DUAL_IFACES`, ou de um tipo concreto do shim com nome de método de
    I/O (os mixins `io.*Sync` dão o `$async`)."""
    if key is None or key[0] != "m" or not _std(key[1]) or key[3] not in DUAL_METHODS:
        return False
    owner = (key[1], key[2])
    return key[3] in DUAL_IFACES.get(owner, ()) or owner not in SHIM_INTERFACES or owner in SYNC_SHIM_IFACES


def sync_shim(key):
    """Método de I/O de tipo concreto do shim que nunca suspende (ou de
    `fmt.State`, cujo valor é sempre o impressor do shim): chamado direto é
    síncrono, seja qual for a cor do grupo dele."""
    if (key is None or key[0] != "m" or key[3] not in DUAL_METHODS or key in ASYNC_SHIM_METHODS
            or key in DUAL_SHIM_CALLS):  # `Buffer.WriteTo(w)` espera o `w`
        return False
    return _std(key[1]) and ((key[1], key[2]) not in SHIM_INTERFACES or (key[1], key[2]) in SYNC_SHIM_IFACES)


class DualIO(Service):
    """Versão dupla dos métodos de I/O na emissão: nomes, formas derivadas e
    chamadas às funções do shim com `$async`."""

    name = "dualio"

    def is_dual(self, key):
        """O grupo de cor da chave tem as duas formas (`m` e `m$async`)."""
        colors = self.facts.colors
        return colors.is_dual(key) if colors is not None else dual_capable(key)

    def members(self, key, go_name, sig):
        """[(nome Dart, retorno)] das formas de um método com a chave: as
        duas num grupo dual (síncrona e `$async`), senão uma só com a cor."""
        name = member_name(go_name)
        if not self.is_dual(key):
            return [(name, self.concurrency.results(key, sig))]
        ret = self.types.results(sig["results"])
        return [(name, ret), (member_name(go_name + "$async"), self.types.future(ret))]

    def derived(self, key, go_name, sig, is_async):
        """A forma derivada de um método declarado num grupo dual: o
        `$async` de um síncrono embrulha, o síncrono de um `async` é o
        `fatal` do runtime (o g2d nunca o chama)."""
        name = member_name(go_name)
        params = ", ".join(f"{self.types.dart(p)} p{i}" for i, p in enumerate(sig["params"]))
        args = ", ".join(f"p{i}" for i in range(len(sig["params"])))
        ret = self.types.results(sig["results"])
        if is_async:
            what = f"{key[2]}.{key[3]}"
            return [f"{ret} {name}({params}) => {self.imports.qualify(None, 'syncOfAsync')}('{what}');"]
        return [f"{self.types.future(ret)} {member_name(go_name + '$async')}({params}) async => {name}({args});"]

    def call_deps(self, call):
        """Chaves dos métodos que uma função do shim com `$async` chama nos
        argumentos (pelo tipo estático de cada um)."""
        spec = DUAL_SHIM_CALLS.get(self.concurrency.callee_key(call))
        if spec is None:
            return set()
        args, out = call["args"] or [], set()
        for i, method in spec:
            if i >= len(args):
                continue
            t = self.pkg.type_of(args[i])
            if t is None:
                continue
            key = self.concurrency.method_key(t, method)
            if key is not None:
                out.add(key)
        return out

    def async_form(self, call):
        """A chamada com o callee na forma `$async` (função do shim com
        versão dupla, ou método de grupo dual); chamada já `async`."""
        if not (self.dual_call(call) or self.is_dual(self.concurrency.callee_key(call))):
            return call
        fun = unparen(call["fun"])
        if fun["node"] == "Ident":  # import `.` do shim
            fun = dict(fun, **{"$obj": dict(fun["$obj"], name=fun["$obj"]["name"] + "$async")})
        else:
            fun = dict(fun, **{"$async": True})
        return dict(call, fun=fun)

    def sync_form(self, call):
        """Num contexto síncrono, a chamada que só espera I/O de versão
        dupla na forma síncrona: a função do shim ou o método dual direto,
        ou a gêmea `$sync` de uma função branda chamada direto. None se a
        chamada suspende de verdade."""
        key = self.concurrency.callee_key(call)
        colors = self.facts.colors
        if self.dual_call(call):
            # Interface não tem corpo: só uma declaração concreta suspende.
            return None if any(colors.suspends_itself(k) for k in self.call_deps(call)) else call
        if self.is_dual(key):
            return None if colors.suspends_itself(key) else call
        fun = unparen(call["fun"])
        if not self.concurrency.has_twin(key):
            return None
        if fun["node"] == "Ident" or (fun["node"] == "SelectorExpr" and (
                (fun["x"].get("$obj") or {}).get("kind") == "package"
                or len((fun.get("$sel") or {}).get("index") or []) == 1)):
            return dict(call, fun=dict(fun, **{"$sync": True}))
        return None

    def dual_call(self, call):
        """A chamada é de uma função do shim com versão `$async`."""
        return self.concurrency.callee_key(call) in DUAL_SHIM_CALLS

    def check_shim_args(self, call):
        """Função do shim SEM versão `$async` que recebe uma interface de I/O
        cujo método, para o argumento, suspende: o shim o chamaria de forma
        síncrona. Recusa (`async:shim-sincrono`)."""
        fun = unparen(call["fun"])
        if fun.get("$isType") or fun.get("$builtin"):
            return
        key = self.concurrency.callee_key(call)
        if key is None or key[0] not in ("f", "m") or not _std(key[1]) or key in DUAL_SHIM_CALLS or key in WRAPPING_SHIM_CALLS:
            return
        sig = self.pkg.type_of(fun)
        if sig is None or self.typesys.underlying(sig)["kind"] != "func":
            return
        params = self.typesys.underlying(sig)["params"]
        for i, a in enumerate(call["args"] or []):
            if i >= len(params):
                break
            p = self.pkg.type_at(params[i])
            ms = DUAL_IFACES.get((p.get("pkg"), p.get("name"))) if p["kind"] == "named" else None
            t = self.pkg.type_of(a)
            for m in ms or ():
                if t is not None and self.concurrency.is_async(self.concurrency.method_key(t, m)):
                    raise Unsupported("async:shim-sincrono",
                                      f"{key[-1]} do shim chamaria {m} de forma síncrona, mas o argumento suspende",
                                      call)
