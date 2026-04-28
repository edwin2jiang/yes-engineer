#!/usr/bin/env bash
# Build SlapToYes.app from SwiftPM products.
# Usage: ./Bundle/build-app.sh   (run from app/ root)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)
APP_NAME="Always Yes"
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

cp "${BIN_DIR}/SlapToYes" "${APP}/Contents/MacOS/SlapToYes"
cp "${BIN_DIR}/SlapDaemon" "${APP}/Contents/Library/LaunchDaemons/SlapDaemon"
cp "${ROOT}/Bundle/Info.plist" "${APP}/Contents/Info.plist"
cp "${ROOT}/Bundle/ai.slaptoyes.daemon.plist" "${APP}/Contents/Library/LaunchDaemons/ai.slaptoyes.daemon.plist"
if [ -f "${ROOT}/Bundle/AppIcon.icns" ]; then
    cp "${ROOT}/Bundle/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"
fi

echo "==> codesign (ad-hoc)"
codesign --force --sign - --options runtime "${APP}/Contents/Library/LaunchDaemons/SlapDaemon"
codesign --force --sign - --deep --options runtime "${APP}"

echo "==> verify"
codesign -dvv "${APP}" 2>&1 | head -8 || true

echo
echo "✓ Built: ${APP}"
echo "  Install:  cp -r '${APP}' /Applications/"
echo "  Run:      open /Applications/${APP_NAME}.app"
