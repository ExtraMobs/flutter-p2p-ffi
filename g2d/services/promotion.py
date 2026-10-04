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
segue o índice do método até quem o declara de fato; o mixin e os
forwarders inline só repassam métodos exportados, ou não exportados que o
próprio pacote declarou. O que sobra (não exportado de outro pacote, a dois
ou mais saltos) entra por um `with D$Promote` extra do dono de fato D, com
o getter `$D` encadeado pelos campos até ele (`foreign_owners`). Ver
`docs/mapping-spec.md` § embedding."""

from g2d.engine.behavior import Service
from g2d.model import Unsupported
from g2d.services.naming import is_exported, member_name, type_name


class Promotion(Service):
    """Mixin `T$Promote` (sempre emitido pelo dono de T), `with` dos mixins
    na struct que embute e forwarders inline (sombreamento ou ambiguidade)."""

    name = "promoter"

    def __init__(self, engine):
        super().__init__(engine)
        self.mixin_decls = []
        self.declared = set()  # nomes Dart de tipo com o mixin já emitido

    def class_name(self, t):
        """Nome Dart (não qualificado) da classe de T: o içado se T é local
        (`$_main$Q`; dois locais homônimos em funções diferentes não
        colidem), senão o do nome Go."""
        return type_name(self.facts.local_types.get(id(t), t["name"]))

    def mixin_name(self, t):
        return f"{self.class_name(t)}$Promote"

    def getter(self, t):
        return f"${self.class_name(t)}"

    def chain(self, t, index):
        """Campos embutidos percorridos pelo índice `index` de um método de
        `t`: ([(struct dona do campo, campo, é ponteiro)], tipo que declara
        o método de fato)."""
        hops, cur = [], t
        for i in index[:-1]:
            field = self.typesys.underlying(cur)["fields"][i]
            ft = self.pkg.type_at(field["type"])
            ptr = ft["kind"] == "pointer"
            hops.append((cur, field, ptr))
            cur = self.pkg.type_at(ft["elem"]) if ptr else ft
        return hops, cur

    def owner_pkg(self, t, index):
        """Pacote que de fato declara o método de índice `index` em `t`
        (segue a cadeia de campos embutidos até a declaração própria)."""
        return self.chain(t, index)[1]["pkg"]

    def shim_lacks(self, t, m):
        """O método `m` de `t` é declarado por um tipo de shim que não o tem
        (`time.Time.GobEncode`): sem forwarder. ponytail: chamá-lo já dá
        `shim-simbolo:` na chamada; só a interface que o exige fica de fora."""
        d = self.chain(t, m["index"])[1]
        return (not self.imports.transpiled(d["pkg"])
                and not self.imports.has_shim_member(d, m["name"]))

    def spellable(self, t, m):
        """Se o forwarder de `m` (método efetivo de `t`) pode ser escrito na
        library do pacote de `t`: exportado (nome público, qualquer
        library) ou não exportado e o próprio pacote de `t` quem declara
        (`owner_pkg == t['pkg']`). O resto só a library do dono de fato
        cita (`foreign_owners`)."""
        return is_exported(m["name"]) or self.owner_pkg(t, m["index"]) == t["pkg"]

    def ptr_getter(self, t):
        """Tipo nomeado não-valor (básico/slice/map/func) com métodos de
        receptor ponteiro que o mixin repassa: o mixin pede, além de `$T`,
        o getter `$T$Ptr` (a vista `T$Ptr` sobre o campo de quem embute),
        porque esses métodos vivem em `T$Ptr`, não em T."""
        return (not self.typesys.is_value(t) and self.typesys.ptr_class(t)
                and any(m["ptr"] and len(m["index"]) == 1 and self.spellable(t, m)
                        for m in t.get("methods") or []))

    def declare(self, t, methods):
        """Emite (uma vez) o mixin `T$Promote` de um tipo nomeado não
        genérico e não interface com method set não vazio: getter `$T`
        anulável + forwarders para o method set que dá pra citar daqui
        (`spellable`), sempre na library de T. Chamado pela emissão de toda
        struct/tipo nomeado (`decls.py`), tenha ou não uso local — o pacote
        de T não sabe, no momento em que T é emitido, quem vai embuti-lo.

        Struct/array: `$T` é a própria classe, com todos os métodos (valor e
        ponteiro) direto nela (M3: struct é o próprio endereço). Tipo
        nomeado sobre básico/slice/map/func: os de receptor valor vão por
        `$T`; os de receptor ponteiro vivem em `T$Ptr` e vão pelo getter
        `$T$Ptr` (`ptr_getter`), que quem embute implementa com a vista
        sobre o campo (`go.FieldPtr`) ou o próprio ponteiro embutido."""
        if not methods:
            return
        cls = self.class_name(t)
        if cls in self.declared:
            return
        self.declared.add(cls)
        value = self.typesys.is_value(t)
        getter = self.getter(t)
        lines = ["", f"/// Métodos de {t['name']} promovidos por embedding (delegação).",
                 f"mixin {cls}$Promote {{", f"{cls}? get {getter};"]
        ptr_getter = self.ptr_getter(t)
        if ptr_getter:
            lines.append(f"{self.types.ptr_view(t)} get {getter}$Ptr;")
        for m in methods:
            if not self.spellable(t, m) or self.shim_lacks(t, m):
                continue
            if value or not m["ptr"]:
                recv = f"{getter}!"
            elif ptr_getter and len(m["index"]) == 1:
                recv = f"{getter}$Ptr"
            else:
                continue  # sem `T$Ptr` (ou promovido: não-struct não embute)
            lines += self.forwarder(m, recv, self.concurrency.method_key(t, m["name"]))
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
        forwarders inline (só os `spellable` daqui). Os não exportados que
        nenhum dos dois repassa entram por `foreign_owners`. Devolve
        ([(mixin qualificado, [getters])], linhas inline)."""
        withs, inline, covered = [], [], set()
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
            if self.mixin_ok(et, emethods, via):
                name = self.imports.qualify(et["pkg"], self.mixin_name(et))
                withs.append((name, self.getters(t, et, [(t, f, ptr)], [field])))
                covered |= {m["name"] for m in via if self.owner_pkg(t, m["index"]) == et["pkg"]}
            else:
                iface = self.typesys.underlying(et)["kind"] == "interface"
                recv = f"{field}!" if ptr or iface else field
                for m in via:
                    if not self.spellable(t, m):
                        continue
                    if self.shim_lacks(t, m):
                        continue
                    r = recv
                    if m["ptr"] and len(m["index"]) == 2 and not iface and not self.typesys.is_value(et):
                        r = self.ptr_view_expr(t, et, f, ptr, "this", field)
                    inline += self.forwarder(m, r, self.concurrency.method_key(t, m["name"]))
        withs += self.foreign_owners(t, outer, withs, covered)
        return withs, inline

    def mixin_ok(self, et, emethods, via):
        return (emethods and {m["name"] for m in via} == {m["name"] for m in emethods}
                and self.typesys.underlying(et)["kind"] != "interface"
                and not self.typesys.type_args(et)
                and self.imports.transpiled(et["pkg"]))

    def getters(self, t, et, hops, path):
        """Getters que `with E$Promote` exige, no struct `t` que alcança E
        pelos campos `hops` (nomes Dart em `path`): `$E` e, se o mixin pede,
        `$E$Ptr`. Ponteiro no caminho torna o resultado anulável (`?.`)."""
        nullable = any(p for _, _, p in hops[:-1])
        parent = "this" if len(path) == 1 else self.access(path[:-1], [p for _, _, p in hops[:-2]])
        expr = self.access(path, [p for _, _, p in hops[:-1]])
        last_ptr = hops[-1][2]
        et_dart = self.types.dart(et)
        if last_ptr and not self.typesys.is_value(et):
            value = f"{expr}?.value"  # *N não-struct: vista ou go.Ptr sobre o valor
        else:
            value = expr
        getter_t = et_dart.as_nullable() if last_ptr or nullable else et_dart.non_null()
        out = [f"{getter_t} get {self.getter(et)} => {value};"]
        if self.ptr_getter(et):
            if nullable:
                parent = f"({parent})!"
            view = self.ptr_view_expr(hops[-1][0], et, hops[-1][1], last_ptr, parent, path[-1])
            out.append(f"{self.types.ptr_view(et)} get {self.getter(et)}$Ptr => {view};")
        return out

    @staticmethod
    def access(path, ptrs):
        """`a.b?.c`: ponteiro em `ptrs[i]` (o campo path[i]) faz o acesso
        seguinte null-aware (e todos depois dele, pelo encurtamento)."""
        out, nullable = path[0], False
        for name, p in zip(path[1:], ptrs):
            nullable = nullable or p
            out += f"{'?.' if nullable else '.'}{name}"
        return out

    def ptr_view_expr(self, owner_t, et, f, ptr, owner, field):
        """`E$Ptr` sobre o campo embutido `field` de `owner` (struct
        `owner_t`): por valor, a vista sobre `go.FieldPtr`; por ponteiro, o
        próprio campo (já é a vista `E$Ptr`)."""
        if ptr:
            return f"{owner}.{field}!" if owner != "this" else f"{field}!"
        ot, ft = self.types.dart(owner_t).non_null(), self.types.dart(et).non_null()
        fp = (f"{self.imports.qualify(None, 'FieldPtr')}<{ot}, {ft}>({owner}, '{field}', "
              f"(o) => o.{field}, (o, v) => o.{field} = v)")
        return f"{self.types.ptr_view(et)}({fp})"

    def foreign_owners(self, t, outer, withs, covered):
        """Não exportado promovido de outro pacote que nem o mixin do campo
        direto nem um forwarder inline repassa (profundidade ≥ 2, com o
        dono de fato D num terceiro pacote, ou E sombreado): só a library
        de D cita o nome, então `t` embute também `D$Promote`, com o getter
        `$D` encadeado pelos campos até D (`w.t`, `w?.t`). Campo do caminho
        que não dá pra citar daqui (não exportado de outro pacote), D sem
        mixin (interface, genérico) ou getter `$D` já usado por outro mixin:
        `Unsupported`."""
        extra, seen = [], {}
        taken = {g.split(" get ")[1].split(" ")[0] for _, gs in withs for g in gs}
        for m in outer:
            if (is_exported(m["name"]) or len(m["index"]) < 2 or m["name"] in covered
                    or self.owner_pkg(t, m["index"]) == t["pkg"]):
                continue
            hops, d = self.chain(t, m["index"])
            if not self.imports.transpiled(d["pkg"]):
                continue  # stdlib (shim): nenhum código transpilado chama o não exportado dela
            key = (d["pkg"], d["name"])
            if key in seen:
                continue
            what = f"método não exportado {m['name']} promovido de {d['pkg']}.{d['name']}"
            if self.typesys.underlying(d)["kind"] == "interface" or self.typesys.type_args(d):
                raise Unsupported("promocao:nao-exportada", f"{what} (interface ou genérico, sem mixin)")
            for s, f, _ in hops:
                if not is_exported(f["name"]) and s["pkg"] != t["pkg"]:
                    raise Unsupported("promocao:nao-exportada", f"{what} pelo campo não exportado {f['name']}")
            getter = self.getter(d)
            if getter in taken:
                raise Unsupported("promocao:nao-exportada", f"{what}: getter {getter} já usado")
            taken.add(getter)
            seen[key] = True
            path = [member_name(f["name"]) for _, f, _ in hops]
            extra.append((self.imports.qualify(d["pkg"], self.mixin_name(d)), self.getters(t, d, hops, path)))
        return extra

    def embedded_methods(self, et):
        """Method set de um tipo embutido (struct/básico: `methods` do goast,
        já com os promovidos pelo próprio tipo; interface: os métodos dela,
        que nunca usam mixin — ver `promotion`)."""
        u = self.typesys.underlying(et)
        if u["kind"] == "interface":
            return [{"name": m["name"], "type": m["type"], "index": [0], "ptr": False} for m in u["methods"]]
        return et.get("methods") or []

    def forwarder(self, m, recv, key):
        sig = self.pkg.type_at(m["type"])
        params = [f"{self.types.dart(pt)} p{i}" for i, pt in enumerate(sig["params"])]
        args = ", ".join(f"p{i}" for i in range(len(params)))
        # Future<R> se o método promovido é async; as duas formas no I/O dual.
        return [f"{ret} {dn}({', '.join(params)}) => {recv}.{dn}({args});"
                for dn, ret in self.dualio.members(key, m["name"], sig)]
