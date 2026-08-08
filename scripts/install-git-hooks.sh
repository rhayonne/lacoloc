#!/bin/bash
# Instala os git hooks versionados (scripts/git-hooks/*) em .git/hooks/.
#
# `.git/hooks/` NUNCA é versionado pelo git (mesmo entre clones do mesmo
# repo) — por isso este passo manual é necessário uma vez por clone, e de
# novo sempre que scripts/git-hooks/* mudar.
#
# Uso: bash scripts/install-git-hooks.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SRC_DIR="scripts/git-hooks"
DST_DIR=".git/hooks"

for hook in "$SRC_DIR"/*; do
  name=$(basename "$hook")
  cp "$hook" "$DST_DIR/$name"
  chmod +x "$DST_DIR/$name"
  echo "✅ Instalado: $DST_DIR/$name"
done

echo ""
echo "Hooks ativos. Para pular pontualmente: git commit --no-verify"
