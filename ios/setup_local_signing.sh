#!/bin/sh
# 本地电脑首次配置：生成 Signing.local.xcconfig
set -e
cd "$(dirname "$0")/Config"
if [ -f Signing.local.xcconfig ]; then
  echo "Signing.local.xcconfig 已存在，请手动编辑。"
  exit 0
fi
cp Signing.local.xcconfig.example Signing.local.xcconfig
echo "已创建 Config/Signing.local.xcconfig"
echo "请取消注释并确认 BUNDLE_ID_PREFIX / RUNNER_BUNDLE_ID / DEVELOPMENT_TEAM 与本地 Apple 账号一致。"
