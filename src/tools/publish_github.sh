#!/usr/bin/env bash
# 發佈到 GitHub（https://github.com/bkhotey4/red-storm）
#   src/  ← 本資料夾的原始碼（只複製 git 追蹤中的檔案）
#   docs/ ← 網頁版匯出（GitHub Pages 從 main 分支的 /docs 提供 https://bkhotey4.github.io/red-storm/）
# 用法（Git Bash，在 RedStorm 資料夾執行）：
#   bash tools/publish_github.sh            匯出 + 同步 + 提交（不上傳）
#   bash tools/publish_github.sh --push     同上，並推送到 GitHub
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="$(pwd)"
PUB="${PUB:-$SRC/../_publish/red-storm}"
GODOT="${GODOT:-../tools/godot/Godot_v4.7.2-stable_win64_console.exe}"

if [ ! -d "$PUB/.git" ]; then
  mkdir -p "$(dirname "$PUB")"
  git clone https://github.com/bkhotey4/red-storm.git "$PUB"
fi
git -C "$PUB" pull -q --ff-only

echo "== 匯出網頁版"
find build_web -mindepth 1 ! -name .gdignore -delete 2>/dev/null || true
mkdir -p build_web
"$GODOT" --headless --path . --export-release "Web" build_web/index.html > /dev/null 2>&1
test -s build_web/index.pck || { echo "匯出失敗：build_web/index.pck 不存在"; exit 1; }

echo "== 同步 src/ 與 docs/"
find "$PUB/src" "$PUB/docs" -mindepth 1 -delete 2>/dev/null || true
mkdir -p "$PUB/src" "$PUB/docs"
git ls-files -z | while IFS= read -r -d '' f; do
  mkdir -p "$PUB/src/$(dirname "$f")"
  cp "$f" "$PUB/src/$f"
done
rm -f "$PUB/src/README.md"
cp -r build_web/. "$PUB/docs/"
rm -f "$PUB/docs/.gdignore"
touch "$PUB/docs/.nojekyll"
cp README.md "$PUB/README.md"

cd "$PUB"
git add -A
if git diff --cached --quiet; then
  echo "== 沒有變更"
  exit 0
fi
git commit -q -m "Update Red Storm ($(date '+%Y-%m-%d'))"
git log --oneline -1
if [ "${1:-}" = "--push" ]; then
  echo "== 推送到 GitHub"
  git push origin main
  echo "== 完成。約 1～3 分鐘後網頁版會更新：https://bkhotey4.github.io/red-storm/"
else
  echo "== 已提交到 $PUB（尚未上傳）。上傳：cd \"$PUB\" && git push origin main"
fi
