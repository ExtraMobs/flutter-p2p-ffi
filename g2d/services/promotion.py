"""Métodos promovidos por embedding: o pacote que declara T sempre emite o
mixin `T$Promote` (mesmo sem uso local), e quem embute T — no mesmo pacote
ou em outro — usa `with T$Promote` quando todo o method set de T é
promovido; o forwarder mora na library de T, o único jeito de expor um
método não exportado de T fora dela (uma interface de T com método não
exportado só é satisfeita por algo escrito na library de T).

Um método só pode ser citado pelo nome (`_secret`) no Dart gerado a partir
da library de quem o declarou de fato: um mixin ou forwarder de OUTRO
pacote que tentasse "repassar" um método não exportado promovido de um
terceiro pacote citaria um nome privado de uma library que não é a dele —
Dart recusa (`_secret` não é o mesmo símbolo em duas libraries). `owner_pkg`
segue o índice do método até quem o declara de fato; só forwarders (inline
ou no mixin) de métodos exportados, ou não exportados que o próprio pacote
declarou, são gerados. Ver `docs/mapping-spec.md` (limite de profundidade)."""

from g2d.engine.behavior import Service
from g2d.services.naming import is_exported, member_name, type_name


class Promotion(Service):
    """Mixin `T$Promote` (sempre emitido pelo dono de T) e forwarders
    inline (sombreamento ou ambiguidade)."""

    name = "promoter"

    def __init__(self, engine):
        super().__init__(engine)
        self.mixin_decls = []
        self.declared = set()  # nomes Go de tipo com o mixin já emitido

    def mixin_name(self, go_name):
        return f"{type_name(go_name)}$Promote"

    def owner_pkg(self, t, index):
        """Pacote que de fato declara o método de índice `index` em `t`
        (segue a cadeia de campos embutidos até a declaração própria,
        índice de tamanho 1)."""
        if len(index) == 1:
            return t["pkg"]
        field = self.typesys.underlying(t)["fields"][index[0]]
        ft = self.pkg.type_at(field["type"])
        et = self.pkg.type_at(ft["elem"]) if ft["kind"] == "pointer" else ft
        return self.owner_pkg(et, index[1:])

    def spellable(self, t, m):
        """Se o forwarder de `m` (método efetivo de `t`) pode ser escrito na
        library do pacote de `t`: exportado (nome público, qualquer
        library) ou não exportado e o próprio pacote de `t` quem declara
        (`owner_pkg == t['pkg']`). Não exportado promovido de outro pacote,
        através de dois ou mais saltos de embedding, não é reforwardável
        daqui — só quem embute o dono de fato pode citar o mixin dele
        (⚠️ `docs/mapping-spec.md`)."""
        return is_exported(m["name"]) or self.owner_pkg(t, m["index"]) == t["pkg"]

    def declare(self, t, methods):
        """Emite (uma vez) o mixin `T$Promote` de um tipo nomeado não
        genérico e não interface com method set não vazio: getter `$T`
        anulável + forwarders para o method set que dá pra citar daqui
        (`spellable`), sempre na library de T. Chamado pela emissão de toda
        struct/tipo nomeado (`decls.py`), tenha ou não uso local — o pacote
        de T não sabe, no momento em que T é emitido, quem vai embuti-lo.

        Struct: `$T` é a própria classe, com todos os métodos (valor e
        ponteiro) direto nela (M3: struct é o próprio endereço). Tipo
        nomeado sobre básico/slice/map/func: `$T` só tem os de receptor
        valor (os de ponteiro vivem em `T$Ptr`, outra classe); um método de
        ponteiro promovido por embedding desses (⚠️ `docs/mapping-spec.md`)
        não entra no mixin — ninguém tenta usá-lo hoje (não há fixture).
        Struct anônima (sem `name`/`methods` próprios: Go não deixa métodos
        em tipo sem nome) nunca chega com `methods` não vazio."""
        if not methods:
            return
        go_name = t["name"]
        if go_name in self.declared:
            return
        self.declared.add(go_name)
        struct = self.typesys.underlying(t)["kind"] == "struct"
        cls = type_name(go_name)
        getter = f"${cls}"
        lines = ["", f"/// Métodos de {go_name} promovidos por embedding (delegação).",
                 f"mixin {self.mixin_name(go_name)} {{", f"{cls}? get {getter};"]
        for m in methods:
            if (struct or not m["ptr"]) and self.spellable(t, m):
                lines += self.forwarder(m, f"{getter}!")
        self.mixin_decls += lines + ["}"]

    def promotion(self, t, st):
        """Métodos promovidos por campos embutidos. Se todo o method set do
        tipo embutido E é promovido por aquele campo (sem sombreamento nem
        ambiguidade — o goast/go-types já resolve os dois: um método
        ambíguo simplesmente não aparece em `outer`), a classe usa
        `with E$Promote` (E pode ser deste pacote ou de outro não-stdlib;
        o mixin mora sempre na library de E, gerado por `declare` quando E
        foi emitido lá). Sombreamento, ambiguidade, E genérico, E de um
        shim da stdlib (sem mixin pra referenciar) ou E interface (o valor
        é uma prova de outra classe, sem forwarder concreto pra reusar):
        forwarders inline (só os `spellable` daqui). Devolve ([(mixin
        qualificado, getter)], linhas inline)."""
        withs, inline = [], []
        outer = t.get("methods") or []
        for fi, f in enumerate(st["fields"]):
            if not f["embedded"]:
                continue
            ft = self.pkg.type_at(f["type"])
            ptr = ft["kind"] == "pointer"
            et = self.pkg.type_at(ft["elem"]) if ptr else ft
            if et["kind"] != "named":
                continue
            emethods = self.embedded_methods(et)
            via = [m for m in outer if len(m["index"]) >= 2 and m["index"][0] == fi]
            field = member_name(f["name"])
            mixin_ok = (emethods and {m["name"] for m in via} == {m["name"] for m in emethods}
                        and self.typesys.underlying(et)["kind"] != "interface"
                        and not self.typesys.type_args(et)
                        and self.imports.transpiled(et["pkg"]))
            if mixin_ok:
                name = self.imports.qualify(et["pkg"], self.mixin_name(et["name"]))
                et_dart = self.types.dart(et)
                getter_t = et_dart.as_nullable() if ptr else et_dart.non_null()
                withs.append((name, f"{getter_t} get ${type_name(et['name'])} => {field};"))
            else:
                recv = f"{field}!" if ptr or self.typesys.underlying(et)["kind"] == "interface" else field
                for m in via:
                    if self.spellable(t, m):
                        inline += self.forwarder(m, recv)
        return withs, inline

    def embedded_methods(self, et):
        """Method set de um tipo embutido (struct/básico: `methods` do goast,
        já com os promovidos pelo próprio tipo; interface: os métodos dela,
        que nunca usam mixin — ver `promotion`)."""
        u = self.typesys.underlying(et)
        if u["kind"] == "interface":
            return [{"name": m["name"], "type": m["type"], "index": [0], "ptr": False} for m in u["methods"]]
        return et.get("methods") or []

    def forwarder(self, m, recv):
        sig = self.pkg.type_at(m["type"])
        params = [f"{self.types.dart(pt)} p{i}" for i, pt in enumerate(sig["params"])]
        args = ", ".join(f"p{i}" for i in range(len(params)))
        name = member_name(m["name"])
        return [f"{self.types.results(sig['results'])} {name}({', '.join(params)}) => {recv}.{name}({args});"]
