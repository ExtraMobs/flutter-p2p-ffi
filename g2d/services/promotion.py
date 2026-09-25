"""Métodos promovidos por embedding: mixins `E$Promote` e forwarders."""

from g2d.engine.behavior import Service
from g2d.services.naming import member_name, type_name


class Promotion(Service):
    """Métodos promovidos por embedding: mixins `E$Promote` e forwarders."""

    name = "promoter"

    def __init__(self, engine):
        super().__init__(engine)
        self.mixins = {}  # (tipo embutido, ponteiro?) → nome do mixin
        self.mixin_decls = []

    def promotion(self, t, st):
        """Métodos promovidos por campos embutidos. Se todo o method set do
        tipo embutido E é promovido por aquele campo, a classe usa o mixin
        reutilizável `E$Promote` (forwarders para o valor embutido); se há
        sombreamento ou ambiguidade, os forwarders promovidos vão inline.
        Devolve ([(mixin, getter)], linhas inline)."""
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
            if {m["name"] for m in via} == {m["name"] for m in emethods} and et["pkg"] == self.pkg.path \
                    and self.typesys.underlying(et)["kind"] != "interface":
                if emethods:
                    name = self.promote_mixin(et, ptr, emethods)
                    et_dart = self.types.dart(et)
                    getter_t = et_dart.as_nullable() if ptr else et_dart.non_null()
                    withs.append((name, f"{getter_t} get ${type_name(et['name'])} => {field};"))
            else:
                recv = f"{field}!" if ptr or self.typesys.underlying(et)["kind"] == "interface" else field
                for m in via:
                    inline += self.forwarder(m, recv)
        return withs, inline

    def embedded_methods(self, et):
        """Method set de um tipo embutido (struct/básico: `methods` do goast;
        interface: os métodos dela)."""
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

    def promote_mixin(self, et, ptr, emethods):
        """`mixin E$Promote` (uma vez por tipo embutido): forwarders do method
        set de E para o valor embutido, que continua sendo o receptor."""
        key = (et["name"], ptr)
        if key not in self.mixins:
            cls = type_name(et["name"])
            name = f"{cls}$Promote" + ("Ptr" if ptr else "")
            self.mixins[key] = name
            getter = f"${cls}"
            recv = getter + ("!" if ptr else "")
            lines = ["", f"/// Métodos de {et['name']} promovidos por embedding (delegação).",
                     f"mixin {name} {{", f"{cls}{'?' if ptr else ''} get {getter};"]
            for m in emethods:
                lines += self.forwarder(m, recv)
            self.mixin_decls += lines + ["}"]
        return self.mixins[key]
