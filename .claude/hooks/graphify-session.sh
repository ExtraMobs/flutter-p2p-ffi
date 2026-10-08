#!/usr/bin/env bash
# SessionStart: grafo de conhecimento do graphify (https://github.com/Graphify-Labs/graphify).
# O contêiner da sessão é efêmero: instala o `graphifyy` se faltar e refaz o
# grafo do código (só AST, sem LLM, ~15 s). Com a pasta compartilhada do
# projeto, `graphify-out/` vive nela e sobrevive entre sessões (inclusive a
# camada semântica do `/graphify`, que custa tokens). Nunca falha a sessão.
set -u
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
export PATH="$HOME/.local/bin:$PATH"
if ! command -v graphify >/dev/null 2>&1; then
  python3 -m pip install --user -q graphifyy >/dev/null 2>&1 || exit 0
fi
shared=/mnt/project-files/graphify/transpiled_ipfs
if [ -d /mnt/project-files/ ] && [ ! -e graphify-out ]; then
  mkdir -p "$shared" 2>/dev/null && ln -s "$shared" graphify-out
fi
(graphify update . >/dev/null 2>&1 &)
exit 0
