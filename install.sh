#!/usr/bin/env bash
# Installe la commande `o2` dans ~/.local/bin et le skill Claude Code dans ~/.claude/skills/o2switch (liens symboliques).
set -euo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
mkdir -p "$HOME/.local/bin" "$HOME/.claude/skills"
ln -sfn "$KIT/bin/o2" "$HOME/.local/bin/o2"
ln -sfn "$KIT" "$HOME/.claude/skills/o2switch"
echo "ok  ~/.local/bin/o2 → $KIT/bin/o2"
echo "ok  ~/.claude/skills/o2switch → $KIT"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "!!  ajoute ~/.local/bin à ton PATH";; esac
echo
echo "Étape suivante : o2 init"
