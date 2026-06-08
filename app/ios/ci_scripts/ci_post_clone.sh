#!/bin/zsh
# Xcode Cloud CI hook. Runs after the repository is cloned and before archive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$(cd "$IOS_DIR/.." && pwd)"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
FLUTTER_REPO="${FLUTTER_REPO:-https://github.com/flutter/flutter.git}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    git clone "$FLUTTER_REPO" --depth 1 -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
  fi

  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter config --no-analytics
# Keep iOS plugin integration on CocoaPods to match the checked-in Podfile.lock.
flutter config --no-enable-swift-package-manager
flutter --version
flutter precache --ios

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

APP_VERSION="$(git -C "$APP_DIR" rev-parse --short HEAD) ($(git -C "$APP_DIR" log -1 --format=%cd --date=format:'%Y-%m-%d'))"

cd "$APP_DIR"
flutter pub get
flutter build ios --release --no-codesign --dart-define="APP_VERSION=$APP_VERSION"

cd "$IOS_DIR"
pod install || {
  echo "pod install failed, retrying in 30 seconds..."
  sleep 30
  pod install
}
