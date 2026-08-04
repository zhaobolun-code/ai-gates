#!/usr/bin/env bash
# link-platform.sh — 创建各 IDE 到中央技能库 .ai-gates/ 的传送门（macOS / Linux 符号链接）。
# 用法（仓库根）： bash .ai-gates/link-platform.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CENTRAL="$ROOT/.ai-gates"
if [[ ! -f "$CENTRAL/skills/CORE.md" ]]; then
  echo "central library not found: $CENTRAL/skills/CORE.md" >&2
  exit 1
fi
link_dir() {
  local link="$1" target="$2" label="$3"
  if [[ -e "$link" || -L "$link" ]]; then
    if [[ -L "$link" ]]; then
      echo "OK (linked): $label -> $(readlink "$link")"
      return
    fi
    echo "portal path occupied by a real directory (refusing to delete): $link" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
  echo "linked: $label -> $target"
}
link_file() {
  local link="$1" target="$2" label="$3"
  if [[ -e "$link" || -L "$link" ]]; then
    echo "OK (file portal exists): $label"
    return
  fi
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
  echo "linked: $label -> $target"
}
link_codex() {
  local link="$ROOT/.codex" target="$CENTRAL/codex"
  if [[ -e "$link" || -L "$link" ]]; then
    if [[ -L "$link" ]]; then
      echo "OK (linked): .codex -> $(readlink "$link")"
      return
    fi
    for f in hooks.json config.toml; do
      if [[ -f "$link/$f" && ! -f "$target/$f" ]]; then
        cp -f "$link/$f" "$target/$f"
        echo "migrated: $link/$f -> $target/$f"
      fi
    done
    rm -rf "$link"
  fi
  ln -s "$target" "$link"
  echo "linked: .codex -> $target"
}
for d in skills hooks scripts rules; do
  link_dir "$ROOT/.cursor/$d" "$CENTRAL/$d" ".cursor/$d"
done
link_file "$ROOT/.cursor/hooks.json" "$CENTRAL/hooks.json" ".cursor/hooks.json"
link_codex
if [[ -L "$ROOT/.trae/skills" ]]; then
  echo "OK (linked): .trae/skills -> $(readlink "$ROOT/.trae/skills")"
else
  mkdir -p "$ROOT/.trae"
  ln -s "$CENTRAL/skills" "$ROOT/.trae/skills"
  echo "linked: .trae/skills -> $CENTRAL/skills"
fi
echo "link-platform: all portals ready."
