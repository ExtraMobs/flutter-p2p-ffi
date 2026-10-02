"""`g2d audit`: mede o grafo real, pacote a pacote, e gera as docs vivas.

    go list (grafo) → goast -outdir (cache) → Engine em modo coleta →
    dart analyze do que emitiu inteiro → status por pacote → docs/*.md

Status, na ordem de precedência:

- `substituicao`: tem assembly no contexto de build (vai ser escrito à mão);
- `unsupported`: alguma declaração caiu em Unsupported (ou erro interno);
- `bloqueado`: emitiu, mas alguma dependência do grafo não está verde;
- `dart-invalido`: emitiu com as deps verdes, mas o `dart analyze` reclama;
- `verde`.

Os problemas de pacotes bloqueados não entram no ranking (podem ser eco da
dependência). Tudo sai ordenado e sem data: duas rodadas, mesma saída.
"""

import collections
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field

from g2d.analysis.color import ColorSummary, ColorTable
from g2d.config import STDLIB_SHIMS
from g2d.engine import Engine
from g2d.graph import BUILD_ENV, build_env, go_list, init_deps, topo_order
from g2d.model import Unsupported, load_dump
from g2d.pipeline import run_dart, write_tree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOAST = os.path.join(ROOT, "tools", "goast")
WIN = sys.platform == "win32"

STATUSES = ("verde", "dart-invalido", "bloqueado", "unsupported", "substituicao")


@dataclass(frozen=True)
class Finding:
    """Um problema: código estável, mensagem e onde (arquivo Go ou Dart)."""

    code: str
    what: str
    where: str = ""

    @property
    def area(self):
        return self.code.split(":", 1)[0]


@dataclass
class PackageReport:
    path: str
    deps: list  # imports diretos do grafo
    module: str = ""
    asm: list = field(default_factory=list)  # .s no contexto de build
    findings: list = field(default_factory=list)  # Unsupported (modo coleta)
    dart: list = field(default_factory=list)  # dart analyze
    status: str = None


# ------------------------------------------------------------------ coleta
def finding(e):
    where = f"{e.pos['file']}:{e.pos['line']}:{e.pos['column']}" if e.pos else ""
    return Finding(e.code, e.what, where)


def emit_collect(pkg, colors=None):
    """(Dart ou None, [Finding]): o Engine segue depois de cada declaração
    que falha; só um pacote sem problemas tem Dart."""
    try:
        engine = Engine(pkg, colors=colors)
        engine.errors = []
        source = engine.emit_package()
        errors = engine.errors
    except Unsupported as e:
        source, errors = None, [e]
    except Exception as e:  # noqa: BLE001 — bug do g2d fora de declaração
        source, errors = None, [Unsupported.internal(e)]
    return (None if errors else source), [finding(e) for e in errors]


_MACHINE = re.compile(r"(?<!\\)\|")


def parse_machine(text, lib):
    """`dart analyze --format=machine` → {arquivo relativo a lib: [Finding]}."""
    out = collections.defaultdict(list)
    for line in text.splitlines():
        cols = [c.replace("\\|", "|").replace("\\\\", "\\") for c in _MACHINE.split(line)]
        if len(cols) != 8:
            continue
        severity, _, code, path, ln, col, _, msg = cols
        rel = os.path.relpath(path, lib).replace(os.sep, "/")
        out[rel].append(Finding(f"dart:{code.lower()}", f"{severity.lower()}: {msg}", f"{ln}:{col}"))
    return out


def classify(reports, order):
    """Status de cada pacote, em ordem topológica (deps primeiro)."""
    for path in order:
        r = reports[path]
        if r.asm:
            r.status = "substituicao"
        elif r.findings:
            r.status = "unsupported"
        elif any(reports[d].status != "verde" for d in r.deps):
            r.status = "bloqueado"
        elif r.dart:
            r.status = "dart-invalido"
        else:
            r.status = "verde"


def ranked_findings(r):
    """Problemas que contam no ranking (os de bloqueado são eco)."""
    if r.status == "unsupported":
        return r.findings
    if r.status == "dart-invalido":
        return r.dart
    return []


def frontier(reports, order):
    """Não verdes (fora substituição) com todas as deps do grafo verdes."""
    return [p for p in order if reports[p].status in ("unsupported", "dart-invalido")
            and all(reports[d].status == "verde" for d in reports[p].deps)]


# ------------------------------------------------------------------ docs
def md(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def top_codes(findings, n=5):
    c = collections.Counter(f.code for f in findings)
    items = sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))
    shown = ", ".join(f"`{k}`×{v}" if v > 1 else f"`{k}`" for k, v in items[:n])
    return shown + (f" (+{len(items) - n})" if len(items) > n else "")


def render_audit(reports, order, meta):
    total = len(order)
    by_status = collections.Counter(reports[p].status for p in order)
    front = frontier(reports, order)
    front_set = set(front)
    lines = [
        "# Auditoria do grafo real",
        "",
        f"Gerado por `{meta['command']}`. **Não edite**: rode o comando de novo.",
        "",
        f"- Alvo: `{meta['target']}` ({meta['module']}), {total} pacotes fora da stdlib.",
        f"- Contexto: {meta['go']}, `{' '.join(f'{k}={v}' for k, v in sorted(BUILD_ENV.items()))}`.",
        "- Ocorrência = declaração de nível de pacote que falha (o primeiro problema dela);",
        "  do `dart analyze`, cada diagnóstico. Pacote bloqueado não conta no ranking.",
        "",
        "## Resumo",
        "",
        "| status | pacotes | % |",
        "|---|---:|---:|",
    ]
    for s in STATUSES:
        lines.append(f"| {s} | {by_status[s]} | {100 * by_status[s] / total:.1f} |")
    lines += ["", f"**Verde: {by_status['verde']} de {total} ({100 * by_status['verde'] / total:.1f}%).**", ""]

    counted = [(p, f) for p in order for f in ranked_findings(reports[p])]
    lines += ["## Ranking de códigos", "",
              "Ordem: pacotes da fronteira afetados, pacotes afetados, ocorrências.", "",
              "| código | ocorrências | pacotes | na fronteira | exemplo |", "|---|---:|---:|---:|---|"]
    occ, pkgs, front_pkgs, example = collections.Counter(), collections.defaultdict(set), \
        collections.defaultdict(set), {}
    for p, f in counted:
        occ[f.code] += 1
        pkgs[f.code].add(p)
        if p in front_set:
            front_pkgs[f.code].add(p)
        example.setdefault(f.code, f"`{p}` {f.where}: {f.what}")
    rank = sorted(occ, key=lambda c: (-len(front_pkgs[c]), -len(pkgs[c]), -occ[c], c))
    for c in rank:
        lines.append(f"| `{c}` | {occ[c]} | {len(pkgs[c])} | {len(front_pkgs[c])} | {md(example[c])[:200]} |")

    lines += ["", "## Ranking por área", "", "| área | ocorrências | pacotes |", "|---|---:|---:|"]
    aocc, apkgs = collections.Counter(), collections.defaultdict(set)
    for p, f in counted:
        aocc[f.area] += 1
        apkgs[f.area].add(p)
    for a in sorted(aocc, key=lambda a: (-len(apkgs[a]), -aocc[a], a)):
        lines.append(f"| `{a}` | {aocc[a]} | {len(apkgs[a])} |")

    lines += ["", f"## Fronteira ({len(front)} pacotes)", "",
              "Não verdes com todas as dependências do grafo verdes: o próximo trabalho.", "",
              "| pacote | status | problemas |", "|---|---|---|"]
    for p in front:
        lines.append(f"| `{p}` | {reports[p].status} | {top_codes(ranked_findings(reports[p]))} |")

    lines += ["", "## Pacotes (ordem de inicialização do Go)", "",
              "| # | pacote | status | problemas |", "|---:|---|---|---|"]
    for i, p in enumerate(order, 1):
        r = reports[p]
        problems = top_codes(r.findings or r.dart) if r.status != "substituicao" else "assembly: " + ", ".join(r.asm)
        lines.append(f"| {i} | `{p}` | {r.status} | {problems} |")
    return "\n".join(lines) + "\n"


def render_stdlib(usage, command):
    """usage: {pacote do grafo: [símbolo stdlib]} → docs/stdlib-coverage.md."""
    users, syms = collections.defaultdict(set), collections.defaultdict(collections.Counter)
    for p, symbols in usage.items():
        for s in symbols:
            std, _, name = s.rpartition(".")
            users[std].add(p)
            syms[std][name] += 1
    lines = ["# Cobertura da stdlib", "",
             f"Gerado por `{command}`. **Não edite**.", "",
             "Pacotes da stdlib usados pelo grafo, por número de pacotes do grafo que os usam.",
             "Símbolos com o número de pacotes que usam cada um. Shim = `golib_dart/lib/<pacote>.dart`.", "",
             f"{len(users)} pacotes da stdlib; {sum(1 for s in users if s in STDLIB_SHIMS)} com shim.", "",
             "| pacote | pacotes do grafo | shim | símbolos |", "|---|---:|---|---|"]
    for std in sorted(users, key=lambda s: (-len(users[s]), s)):
        items = sorted(syms[std].items(), key=lambda kv: (-kv[1], kv[0]))
        shown = ", ".join(f"{k}({v})" for k, v in items)
        lines.append(f"| `{std}` | {len(users[std])} | {'✅' if std in STDLIB_SHIMS else '❌'} | {md(shown)} |")
    return "\n".join(lines) + "\n"


def render_reflection(uses, command):
    """uses: [(pacote, pos, expr)] → docs/reflection-report.md."""
    by_name, pkgs = collections.Counter(), collections.defaultdict(set)
    for p, _, expr in uses:
        name = expr.rsplit(".", 1)[-1]
        by_name[name] += 1
        pkgs[name].add(p)
    lines = ["# Uso de `reflect`", "",
             f"Gerado por `{command}`. **Não edite**.", "",
             "Toda seleção que toca o pacote `reflect` nos pacotes do grafo. Status: todas pendentes",
             "até o M5 (reflexão estática, `TODO/P0-design-m5-reflexao.md`).", "",
             f"{len(uses)} usos em {len({p for p, _, _ in uses})} pacotes.", "",
             "## Por símbolo", "", "| símbolo | usos | pacotes |", "|---|---:|---:|"]
    for n in sorted(by_name, key=lambda n: (-len(pkgs[n]), -by_name[n], n)):
        lines.append(f"| `{n}` | {by_name[n]} | {len(pkgs[n])} |")
    per_pkg = collections.defaultdict(collections.Counter)
    for p, _, expr in uses:
        per_pkg[p][expr.rsplit(".", 1)[-1]] += 1
    lines += ["", "## Por pacote", "",
              "Posições exatas: `reflectUsage` do dump do pacote (goast).", "",
              "| pacote | usos | símbolos | status |", "|---|---:|---|---|"]
    for p in sorted(per_pkg, key=lambda p: (-sum(per_pkg[p].values()), p)):
        items = sorted(per_pkg[p].items(), key=lambda kv: (-kv[1], kv[0]))
        lines.append(f"| `{p}` | {sum(per_pkg[p].values())} | {', '.join(f'{k}({v})' for k, v in items)} | pendente |")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------ execução
def cache_key(corpus):
    """Dumps valem enquanto o goast, o corpus e o contexto não mudam."""
    h = hashlib.sha256(json.dumps(sorted(BUILD_ENV.items())).encode())
    files = sorted(glob.glob(os.path.join(GOAST, "*.go"))) + [os.path.join(GOAST, "go.mod")]
    files += [os.path.join(corpus, n) for n in ("go.mod", "go.sum")]
    for f in files:
        with open(f, "rb") as fh:
            h.update(fh.read())
    return h.hexdigest()[:12]


def color_graph(order, dumps, log=print, imports=None):
    """ColorTable do grafo inteiro (a cor `async` atravessa pacotes nos dois
    sentidos: implementação num pacote colore a interface de outro). Os
    resumos ficam em cache ao lado dos dumps, por versão do código da cor."""
    h = hashlib.sha256()
    for f in ("analysis/color.py", "services/concurrency.py"):
        with open(os.path.join(ROOT, "g2d", f), "rb") as fh:
            h.update(fh.read())
    cache = os.path.join(dumps, "color-" + h.hexdigest()[:12])
    summaries = []
    for i, path in enumerate(order, 1):
        cached = os.path.join(cache, *path.split("/")) + ".json"
        if os.path.exists(cached):
            with open(cached, encoding="utf-8") as f:
                summaries.append(ColorSummary.from_json(json.load(f)))
            continue
        (pkg,) = load_dump(dump_path(dumps, path))
        if pkg.name == "main" and imports is not None:
            pkg.init_deps = init_deps(path, imports)  # o $goInit do main espera o grafo
        try:
            s = Engine(pkg).color_summary()
        except Exception:  # noqa: BLE001 — o pacote cai na emissão, com o erro dele
            continue
        summaries.append(s)
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        with open(cached, "w", encoding="utf-8") as f:
            json.dump(s.to_json(), f)
        if i % 100 == 0:
            log(f"  cor {i}/{len(order)}")
    return ColorTable(summaries)


def dump_path(dumps, path):
    return os.path.join(dumps, *path.split("/")) + ".json"


def dump_graph(order, corpus, dumps):
    """Despeja (goast -outdir) os pacotes que ainda não estão no cache."""
    missing = [p for p in order if not os.path.exists(dump_path(dumps, p))]
    if not missing:
        return
    os.makedirs(dumps, exist_ok=True)
    listing = os.path.abspath(os.path.join(dumps, "pacotes.txt"))
    with open(listing, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(missing) + "\n")
    # O goast compila para o host; só a carga dos pacotes usa o BUILD_ENV.
    exe = os.path.abspath(os.path.join(dumps, "goast.exe" if WIN else "goast"))
    subprocess.run(["go", "build", "-o", exe, "."], cwd=GOAST, check=True)
    subprocess.run([exe, "dump", "-C", os.path.abspath(corpus), "@" + listing, "-outdir", os.path.abspath(dumps)],
                   env=build_env(), check=True)


def analyze(out, sources):
    """Escreve o mono-repo com os pacotes emitidos e roda o dart analyze."""
    shutil.rmtree(out, ignore_errors=True)
    write_tree(out, sources)
    run_dart(["pub", "get", "--offline"], cwd=out, capture_output=True, check=True)
    r = run_dart(["analyze", "--format=machine", "lib"], cwd=out, capture_output=True, text=True, encoding="utf-8")
    by_file = parse_machine(r.stdout + r.stderr, os.path.abspath(os.path.join(out, "lib")))
    return {rel[:-len(".dart")]: fs for rel, fs in by_file.items()}


def audit(target, corpus, docs, cache, log=print):
    graph = go_list(target, cwd=corpus)
    order = [p for p in topo_order(graph) if not graph[p]["standard"]]
    dumps = os.path.join(cache, "dumps-" + cache_key(corpus))
    log(f"{len(order)} pacotes; dumps em {dumps}")
    dump_graph(order, corpus, dumps)

    imports = {p: graph[p]["imports"] for p in graph}
    colors = color_graph(order, dumps, log, imports)
    reports, sources, stdlib, reflection, meta = {}, {}, {}, [], {}
    for i, path in enumerate(order, 1):
        (pkg,) = load_dump(dump_path(dumps, path))
        r = reports[path] = PackageReport(path, sorted(d for d in graph[path]["imports"] if d in graph
                                                       and not graph[d]["standard"]))
        r.module = (pkg.module or {}).get("path", "")
        r.asm = [f for f in pkg.other_files if f.endswith((".s", ".S"))]
        stdlib[path] = pkg.stdlib_usage
        reflection += [(path, u["pos"], u["expr"]) for u in pkg.reflect_usage]
        if path == target:
            v = (pkg.module or {}).get("version") or "módulo principal"
            meta = {"module": f"`{r.module}` {v}", "go": pkg.go_version}
        if not r.asm:
            if pkg.name == "main":
                pkg.init_deps = init_deps(path, imports)
            source, r.findings = emit_collect(pkg, colors)
            if source is not None:
                sources[path] = source
        if i % 100 == 0:
            log(f"  {i}/{len(order)}")
    log(f"dart analyze de {len(sources)} pacotes emitidos")
    for path, fs in analyze(os.path.join(cache, "out"), sources).items():
        if path in reports:
            reports[path].dart = fs
    classify(reports, order)

    command = f"python -m g2d audit {target} -C {corpus.replace(os.sep, '/')}"
    meta.update(command=command, target=target)
    os.makedirs(docs, exist_ok=True)
    for name, text in (("audit.md", render_audit(reports, order, meta)),
                       ("stdlib-coverage.md", render_stdlib(stdlib, command)),
                       ("reflection-report.md", render_reflection(reflection, command))):
        with open(os.path.join(docs, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    return reports, order

