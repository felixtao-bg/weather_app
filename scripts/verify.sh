#!/usr/bin/env bash
# 本地 / CI 通用检查：工具链版本、格式、静态分析、全量测试（单元 + widget + golden）。
# 用法：scripts/verify.sh            仅宿主机检查
#       scripts/verify.sh <device>   额外在设备/模拟器上跑 integration_test（含真实接口冒烟测试）
# 可用 FLUTTER=/path/to/flutter 指定 SDK（例如与全局版本并存的 3.41.0），不修改全局环境。
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"
DART="$(dirname "$(command -v "$FLUTTER")")/dart"

EXPECTED="3.41.0"
"$FLUTTER" --version
ACTUAL="$("$FLUTTER" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "期望 Flutter $EXPECTED，实际 $ACTUAL（pubspec 约束 >=3.41.0 <3.42.0）" >&2
  exit 1
fi

"$FLUTTER" pub get
"$DART" format --output=none --set-exit-if-changed .
"$FLUTTER" analyze
"$FLUTTER" test

if [[ $# -ge 1 ]]; then
  # 逐个文件运行：一次跑多个 integration 文件时偶发 "Failed to start Dart Development Service"。
  "$FLUTTER" test integration_test/app_flow_test.dart -d "$1"
  "$FLUTTER" test integration_test/live_api_test.dart -d "$1"
fi
