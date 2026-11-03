#!/usr/bin/env bash
# link-platform.sh — 创建各 IDE 到中央技能库 .ai-gates/ 的传送门（macOS / Linux 符号链接）。
# 用法（仓库根）： bash .ai-gates/link-platform.sh
# 可选： --accept-codex-migration  --no-migrate
set -euo pipefail
NO_MIGRATE=0
ACCEPT_CODEX_MIGRATION=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-migrate) NO_MIGRATE=1 ;;
    --accept-codex-migration) ACCEPT_CODEX_MIGRATION=1 ;;
  esac
  shift
done
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CENTRAL="$ROOT/.ai-gates"
CONFLICTS=()
if [[ ! -f "$CENTRAL/skills/CORE.md" ]]; then
  echo "central library not found: $CENTRAL/skills/CORE.md" >&2
  exit 1
fi
comparable_path() {
  local p="$1"
  p="${p%/}"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || echo "$p"
  elif readlink -f / >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null || echo "$p"
  else
    local dir base
    dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd || echo "$(dirname "$p")")"
    base="$(basename "$p")"
    echo "$dir/$base"
  fi
}
same_target() {
  local a b
  a="$(comparable_path "$1")"
  b="$(comparable_path "$2")"
  a="${a%/}"
  b="${b%/}"
  [[ "$a" == "$b" ]]
}
link_target_abs() {
  local link="$1"
  local raw
  raw="$(readlink "$link")"
  if [[ "$raw" = /* ]]; then
    comparable_path "$raw"
  else
    local dir
    dir="$(cd "$(dirname "$link")" && pwd)"
    comparable_path "$dir/$raw"
  fi
}
report_stale() {
  local label="$1" link="$2" actual="$3" expected="$4"
  echo "STALE: $label -> $actual (expected $expected)"
  CONFLICTS+=("$label (stale link: $link)")
}
hardlink_points_to() {
  local link="$1" target="$2"
  local i1 i2
  i1="$(stat -c %i "$link" 2>/dev/null || stat -f %i "$link" 2>/dev/null || true)"
  i2="$(stat -c %i "$target" 2>/dev/null || stat -f %i "$target" 2>/dev/null || true)"
  [[ -n "$i1" && -n "$i2" && "$i1" == "$i2" ]]
}
migrate_state() {
  local from to name
  migrate_one() {
    from="$1"; to="$2"; name="$3"
    if [[ -e "$from" && ! -e "$to" ]]; then
      if cp -r "$from" "$to" 2>/dev/null; then
        rm -rf "$from"
        echo "MIGRATED: .cursor/$name -> .ai-gates/$name"
      else
        echo "MIGRATE WARN: $name copy failed"
      fi
    elif [[ -e "$from" && -e "$to" ]]; then
      echo "MIGRATE skip (target exists): .ai-gates/$name"
    fi
  }
  migrate_one "$ROOT/.cursor/regression-index.yaml" "$CENTRAL/regression-index.yaml" "regression-index.yaml"
  migrate_one "$ROOT/.cursor/lessons-learned.md" "$CENTRAL/lessons-learned.md" "lessons-learned.md"
  migrate_one "$ROOT/.cursor/lessons-outline.md" "$CENTRAL/lessons-outline.md" "lessons-outline.md"
  migrate_one "$ROOT/.cursor/pipeline-outcome.log" "$CENTRAL/pipeline-outcome.log" "pipeline-outcome.log"
  migrate_one "$ROOT/.cursor/pipeline-snapshot.log" "$CENTRAL/pipeline-snapshot.log" "pipeline-snapshot.log"
  migrate_one "$ROOT/.cursor/pipeline-recovery-log.md" "$CENTRAL/pipeline-recovery-log.md" "pipeline-recovery-log.md"
  migrate_one "$ROOT/.cursor/hooks-log" "$CENTRAL/hooks-log" "hooks-log"
  migrate_one "$ROOT/.cursor/tmp" "$CENTRAL/tmp" "tmp"
  migrate_one "$ROOT/.cursor/verify" "$CENTRAL/verify" "verify"
}
migrate_state
link_dir() {
  local link="$1" target="$2" label="$3"
  if [[ -e "$link" || -L "$link" ]]; then
    if [[ -L "$link" ]]; then
      local actual expected
      actual="$(link_target_abs "$link")"
      expected="$(comparable_path "$target")"
      if same_target "$actual" "$expected"; then
        echo "OK (linked): $label -> $actual"
      else
        report_stale "$label" "$link" "$actual" "$expected"
      fi
      return
    fi
    echo "CONFLICT: $label occupied by a real directory (old-version layout) - $link"
    CONFLICTS+=("$label (real dir: $link)")
    return
  fi
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
  echo "linked: $label -> $target"
}
link_file() {
  local link="$1" target="$2" label="$3"
  if [[ -e "$link" || -L "$link" ]]; then
    if [[ -L "$link" ]]; then
      local actual expected
      actual="$(link_target_abs "$link")"
      expected="$(comparable_path "$target")"
      if same_target "$actual" "$expected"; then
        echo "OK (linked): $label -> $actual"
      else
        report_stale "$label" "$link" "$actual" "$expected"
      fi
      return
    fi
    if hardlink_points_to "$link" "$target"; then
      echo "OK (file portal exists): $label"
      return
    fi
    # 升级残留检测（2026-08-04）：真实文件且与中央库不一致 → 提示替换，不自动删除
    if cmp -s "$link" "$target"; then
      echo "OK (file matches central copy): $label"
    else
      echo "STALE: $label is a real file and differs from $target (old-version wiring)."
      CONFLICTS+=("$label (stale real file: $link)")
      echo "  Fix: rm '$link' and re-run this script to link the new hooks.json."
      echo "  (keep it only if you intentionally customized the project hooks wiring)"
    fi
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
      local actual expected
      actual="$(link_target_abs "$link")"
      expected="$(comparable_path "$target")"
      if same_target "$actual" "$expected"; then
        echo "OK (linked): .codex -> $actual"
      else
        report_stale ".codex" "$link" "$actual" "$expected"
      fi
      return
    fi
    if [[ "$NO_MIGRATE" -eq 1 ]]; then
      echo ".codex exists as a real directory; re-run without --no-migrate to migrate it." >&2
      exit 1
    fi
    mkdir -p "$target"
    local ts backup conflict=0
    ts="$(date +%Y%m%d%H%M%S)"
    backup="$CENTRAL/tmp/codex-migrate-backup-$ts"
    for f in hooks.json config.toml; do
      if [[ -f "$link/$f" && ! -f "$target/$f" ]]; then
        cp -f "$link/$f" "$target/$f"
        echo "migrated: $link/$f -> $target/$f"
      elif [[ -f "$link/$f" && -f "$target/$f" ]]; then
        if cmp -s "$link/$f" "$target/$f"; then
          echo "migrate skip (same hash): $f"
        else
          mkdir -p "$backup"
          cp -f "$link/$f" "$backup/$f"
          echo "DIFF: old=$link/$f new=$target/$f backup=$backup/$f"
          conflict=1
        fi
      fi
    done
    if [[ "$conflict" -eq 1 && "$ACCEPT_CODEX_MIGRATION" -eq 0 ]]; then
      echo "Review the backup, then re-run with --accept-codex-migration. Not deleting old .codex, not creating a new link."
      CONFLICTS+=(".codex (content differs; backup $backup)")
      return
    fi
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
  actual="$(link_target_abs "$ROOT/.trae/skills")"
  expected="$(comparable_path "$CENTRAL/skills")"
  if same_target "$actual" "$expected"; then
    echo "OK (linked): .trae/skills -> $actual"
  else
    report_stale ".trae/skills" "$ROOT/.trae/skills" "$actual" "$expected"
  fi
else
  if [[ -e "$ROOT/.trae/skills" ]]; then
    echo "CONFLICT: .trae/skills occupied by a real directory (old-version layout) - $ROOT/.trae/skills"
    CONFLICTS+=(".trae/skills (real dir: $ROOT/.trae/skills)")
  else
    mkdir -p "$ROOT/.trae"
    ln -s "$CENTRAL/skills" "$ROOT/.trae/skills"
    echo "linked: .trae/skills -> $CENTRAL/skills"
  fi
fi
if [[ -L "$ROOT/.trae/rules" ]]; then
  actual="$(link_target_abs "$ROOT/.trae/rules")"
  expected="$(comparable_path "$CENTRAL/rules")"
  if same_target "$actual" "$expected"; then
    echo "OK (linked): .trae/rules -> $actual"
  else
    report_stale ".trae/rules" "$ROOT/.trae/rules" "$actual" "$expected"
  fi
else
  if [[ -e "$ROOT/.trae/rules" ]]; then
    echo "CONFLICT: .trae/rules occupied by a real directory - $ROOT/.trae/rules"
    CONFLICTS+=(".trae/rules (real dir: $ROOT/.trae/rules)")
  else
    mkdir -p "$ROOT/.trae"
    ln -s "$CENTRAL/rules" "$ROOT/.trae/rules"
    echo "linked: .trae/rules -> $CENTRAL/rules"
  fi
fi
if (( ${#CONFLICTS[@]} > 0 )); then
  echo ""
  echo "=== 升级处理指引 ==="
  echo "以下位置被旧版真实目录/文件占据，脚本拒绝自动删除（防误删项目数据）："
  for c in "${CONFLICTS[@]}"; do echo "  - $c"; done
  echo ""
  echo "处理步骤："
  echo "1) 确认 .cursor/skills|hooks|scripts|rules 里没有项目自己放的文件（按设计只放技能内容）；"
  echo "2) 删除这些旧目录和旧的 .cursor/hooks.json；"
  echo "3) 项目状态文件（regression-index.yaml、lessons-*、pipeline-*.log、hooks-log/、tmp/、verify/）已自动迁入 .ai-gates/；保留、不要删：.cursor/project-context.md、mcp.json；"
  echo "4) 删除后重新运行本脚本。"
  echo "（.codex 旧真实目录：内容不同时先备份，确认后带 --accept-codex-migration 再换链接。）"
  exit 1
fi
echo "link-platform: all portals ready."
