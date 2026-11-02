#!/bin/bash
# Launch MyFinder with an English UI regardless of the system language.
# 以英文界面启动 MyFinder（不受系统语言影响）。若已在运行，请先退出再启动。
cd "$(dirname "$0")"
if pgrep -f "MyFinder.app/Contents/MacOS/MyFinder" >/dev/null; then
  echo "MyFinder 正在运行，请先退出后再启动英文版 / MyFinder is running — quit it first."
  exit 1
fi
open -n MyFinder.app --args -AppleLanguages "(en)"
