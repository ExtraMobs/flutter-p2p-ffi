"""Descritores de tipo `go.Elem` (const por tipo; dicionários de genéricos)."""

from g2d.engine.behavior import Service


class DescriptorRegistry(Service):
    """Descritores de tipo `go.Elem` (const por tipo; dicionários de genéricos)."""

    name = "descriptors"

    def __init__(self, engine):
        super().__init__(engine)
        self.elems = {}  # tipo Dart → nome do const go.Elem
        self.elem_decls = []  # declarações de nível de library

    def has_tparam(self, t, seen=None):
        t = self.pkg.type_at(t) if isinstance(t, int) else t
        k = t["kind"]
        if k == "typeparam":
            return True
        if k == "named":
            return any(self.has_tparam(a) for a in self.typesys.type_args(t))
        return any(self.has_tparam(t[f]) for f in ("elem", "key") if f in t)

    def elem(self, t):
        """Descritor go.Elem<T> do tipo Go t: const registrado uma vez; para
        um parâmetro de tipo, o dicionário `$T`; para tipos que dependem de
        parâmetros de tipo, um Elem construído na hora."""
        t = self.pkg.type_at(t) if isinstance(t, int) else t
        if t["kind"] == "typeparam":
            return f"${t['name']}"
        dt = self.types.dart(t)
        if self.has_tparam(t):
            ptrs = ", pointers: true" if self.typesys.underlying(t)["kind"] != "basic" else ""
            size = 24 if self.typesys.underlying(t)["kind"] == "slice" else 8
            return f"{self.imports.qualify(None, 'Elem')}<{dt}>({size}, () => {self.types.zero(t)}{ptrs})"
        if dt not in self.elems:
            name = f"_$e{len(self.elems)}"
            self.elems[dt] = name
            size, _, ptrs = self.typesys.layout(t)
            zero = self.zero_fn(t, dt)
            flag = ", pointers: true" if ptrs else ""
            b = self.typesys.basic(t)
            if b is not None and b.cat in ("wint", "float"):
                flag += f", ofInt: {self.of_int_fn(t, b, dt)}, ofFloat: {self.of_float_fn(t, b, dt)}"
            self.elem_decls.append(f"const {name} = {self.imports.qualify(None, 'Elem')}<{dt}>({size}, {zero}{flag});")
        return self.elems[dt]

    def of_int_fn(self, t, b, dt):
        """T(n) a partir de um inteiro Go (conversão para parâmetro de tipo)."""
        if b.cat == "wint":
            return f"{self.types.cls(t)}.from"
        name = f"_$i{len(self.elem_decls)}_{len(self.elems)}"
        g = self.types.golang
        f = g(b.cls)
        v = f"(n.$signed ? {f}.fromInt64({g('Int64')}.from(n)) : {f}.fromUint64({g('Uint64')}.from(n)))"
        if t["kind"] == "named":
            v = f"{dt}({v}.toDouble())"
        self.elem_decls.append(f"{dt} {name}({g('IntBase')} n) => {v};")
        return name

    def of_float_fn(self, t, b, dt):
        """T(f) a partir de um float Go (conversão para parâmetro de tipo):
        as regras de FloatToInt/FloatToFloat."""
        name = f"_$f{len(self.elem_decls)}_{len(self.elems)}"
        g = self.types.golang
        if b.cat == "wint":
            v = f"{self.types.cls(t)}.from(f.toInteger({b.width}, signed: {'true' if b.signed else 'false'}))"
        else:
            v = f"{self.types.cls(t)}(f.toDouble())"
        self.elem_decls.append(f"{dt} {name}({g('FloatBase')} f) => {v};")
        return name

    def zero_fn(self, t, dt):
        """Função const que cria o zero value de t (tear-off)."""
        u = self.typesys.underlying(t)
        if u["kind"] == "basic":
            b = self.typesys.basic(u)
            if b.cat == "bool" and not self.typesys.named_bool(t):
                return self.imports.qualify(None, "zeroBool")
            return f"{self.types.cls(t)}.new"
        if u["kind"] in ("interface", "pointer", "func", "chan") and not self.typesys.named_func(t):
            return self.imports.qualify(None, "zeroNull")  # (func nomeado é classe, não anulável)
        if self.typesys.is_struct(t) and not self.typesys.type_args(t):
            return f"{dt}.new"
        name = f"_$z{len(self.elem_decls)}_{len(self.elems)}"
        self.elem_decls.append(f"{dt} {name}() => {self.types.zero(t)};")
        return name
