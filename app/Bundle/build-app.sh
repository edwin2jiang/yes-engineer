#!/usr/bin/env bash
# Build Yes Engineer.app from SwiftPM products.
# Usage: ./Bundle/build-app.sh   (run from app/ root)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)
APP_NAME="Yes Engineer"
APP="${ROOT}/build/${APP_NAME}.app"

echo "==> swift build -c release"
swift build -c release --arch arm64

BIN_DIR=$(swift build -c release --arch arm64 --show-bin-path)
echo "    bin dir: ${BIN_DIR}"

echo "==> assembling bundle at ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Library/LaunchDaemons"
mkdir -p "${APP}/Contents/Resources"

cp "${BIN_DIR}/YesEngineer" "${APP}/Contents/MacOS/YesEngineer"
cp "${BIN_DIR}/YesEngineerDaemon" "${APP}/Contents/Library/LaunchDaemons/YesEngineerDaemon"
cp "${ROOT}/Bundle/Info.plist" "${APP}/Contents/Info.plist"
cp "${ROOT}/Bundle/ai.yesengineer.daemon.plist" "${APP}/Contents/Library/LaunchDaemons/ai.yesengineer.daemon.plist"
if [ -f "${ROOT}/Bundle/AppIcon.icns" ]; then
    cp "${ROOT}/Bundle/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"
fi

echo "==> codesign (ad-hoc)"
codesign --force --sign - --options runtime "${APP}/Contents/Library/LaunchDaemons/YesEngineerDaemon"
codesign --force --sign - --deep --options runtime "${APP}"

echo "==> verify"
codesign -dvv "${APP}" 2>&1 | head -8 || true

echo
echo "✓ Built: ${APP}"
echo "  Install:  cp -r '${APP}' /Applications/"
echo "  Run:      open /Applications/${APP_NAME}.app"
