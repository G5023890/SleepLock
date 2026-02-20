#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"
if [[ "$MODE" != "--dry-run" && "$MODE" != "--apply" ]]; then
  echo "Usage: $0 [--dry-run|--apply]" >&2
  exit 1
fi

PROJECT_ROOT="$(pwd -P)"
LIST_FILE="${PROJECT_ROOT}/.cleanup_candidates.txt"

format_kb() {
  awk -v kb="$1" 'BEGIN {
    split("KB MB GB TB", u, " ")
    i = 1
    x = kb + 0
    while (x >= 1024 && i < 4) {
      x = x / 1024
      i++
    }
    printf "%.2f %s", x, u[i]
  }'
}

collect_candidates() {
  find "$PROJECT_ROOT" \
    \( -path "$PROJECT_ROOT/.git" -o -path "$PROJECT_ROOT/.git/*" \) -prune -o \
    \( -type d \( \
      -name node_modules -o \
      -name dist -o \
      -name build -o \
      -name .cache -o \
      -name tmp -o \
      -name .tmp -o \
      -name .build -o \
      -name DerivedData -o \
      -name __pycache__ -o \
      -name .pytest_cache -o \
      -name .mypy_cache -o \
      -name target -o \
      -name bin -o \
      -name pkg -o \
      -name CMakeFiles -o \
      -name xcuserdata -o \
      -name .codex -o \
      -name .agent \
    \) -print -prune \) -o \
    \( -type f \( \
      -name "*.log" -o \
      -name ".DS_Store" -o \
      -name "*.xcuserstate" -o \
      -name "*.pyc" -o \
      -name "CMakeCache.txt" \
    \) -print \)
}

collect_candidates | LC_ALL=C sort -u > "$LIST_FILE"

project_kb="$(du -sk "$PROJECT_ROOT" | awk '{print $1}')"

candidate_kb=0
if [[ -s "$LIST_FILE" ]]; then
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    size_kb="$(du -sk "$path" | awk '{print $1}')"
    candidate_kb=$((candidate_kb + size_kb))
  done < "$LIST_FILE"
fi

echo "Project root: $PROJECT_ROOT"
echo "Project size: $(format_kb "$project_kb")"
echo
echo "Candidates for removal:"
if [[ -s "$LIST_FILE" ]]; then
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    size_h="$(du -sh "$path" | awk '{print $1}')"
    rel="${path#"$PROJECT_ROOT"/}"
    echo "- $rel ($size_h)"
  done < "$LIST_FILE"
else
  echo "- none"
fi

echo
echo "Total removable size: $(format_kb "$candidate_kb")"

if [[ "$MODE" == "--dry-run" ]]; then
  echo
  echo "Dry-run complete."
  echo "Run '$0 --apply' to delete after confirmation."
  exit 0
fi

echo
read -r -p "Proceed with deletion of listed paths? Type YES to continue: " confirm
if [[ "$confirm" != "YES" ]]; then
  echo "Cancelled. Nothing deleted."
  exit 0
fi

while IFS= read -r path; do
  [[ -e "$path" ]] || continue
  if [[ -d "$path" ]]; then
    rm -rf -- "$path"
  else
    rm -f -- "$path"
  fi
done < "$LIST_FILE"

after_kb="$(du -sk "$PROJECT_ROOT" | awk '{print $1}')"
freed_kb=$((project_kb - after_kb))
if (( freed_kb < 0 )); then
  freed_kb=0
fi

echo
echo "Cleanup complete."
echo "New project size: $(format_kb "$after_kb")"
echo "Freed space: $(format_kb "$freed_kb")"
