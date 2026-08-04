#!/usr/bin/env bash
# 将 .trae/skills 符号链接至 .ai-gates/skills（macOS / Linux）
# 用法（项目根目录）: bash .ai-gates/scripts/link-trae-skills.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CENTRAL_SKILLS="$ROOT/.ai-gates/skills"
TRAE_SKILLS="$ROOT/.trae/skills"

if [[ ! -d "$CENTRAL_SKILLS" ]]; then
  echo "未找到中央技能库: $CENTRAL_SKILLS" >&2
  exit 1
fi

mkdir -p "$ROOT/.trae"

if [[ -L "$TRAE_SKILLS" ]]; then
  current="$(readlink "$TRAE_SKILLS")"
  if [[ "$current" == "../.ai-gates/skills" || "$current" == "$CENTRAL_SKILLS" ]]; then
    echo "已链接: .trae/skills -> .ai-gates/skills"
    exit 0
  fi
  echo ".trae/skills 已指向: $current" >&2
  exit 1
fi

if [[ -e "$TRAE_SKILLS" ]]; then
  echo "删除旧的 .trae/skills 副本..."
  rm -rf "$TRAE_SKILLS"
fi

ln -s ../.ai-gates/skills "$TRAE_SKILLS"
echo "完成: .trae/skills -> .ai-gates/skills（同一份 Skill）"
