#!/bin/bash
cd "$(dirname "$0")"

APP_NAME="MiniTranslate"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SDK=$(xcrun --show-sdk-path --sdk macosx)
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"

echo "=== 清理旧构建 ==="
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "=== 编译 Swift 源码 ==="
swiftc -sdk "$SDK" -target "$TARGET" -O \
  -framework Cocoa -framework Security -framework SwiftUI -framework Vision -framework Carbon -framework ApplicationServices \
  Sources/main.swift \
  Sources/Translator/Language.swift \
  Sources/Translator/DeepLError.swift \
  Sources/Translator/TranslationServiceProtocol.swift \
  Sources/Translator/Translator.swift \
  Sources/Keychain/KeychainStore.swift \
  Sources/Settings/SettingsView.swift \
  Sources/TranslationWindow/TranslationView.swift \
  Sources/TranslationWindow/TranslationWindowController.swift \
  Sources/Hotkey/HotkeyManager.swift \
  Sources/TextAccess/TextAccessor.swift \
  Sources/OCR/OCRReader.swift \
  Sources/ScreenCapture/ScreenshotOverlay.swift \
  Sources/TranslationOrchestrator.swift \
  Sources/MiniTranslateApp.swift \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== 生成应用图标 ==="
swift Scripts/generate-icon.swift "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "=== 复制 Info.plist ==="
cp Info.plist "$APP_BUNDLE/Contents/"

echo "=== 代码签名（稳定身份，权限持久化） ==="
CERT_NAME="Mini Translate Developer"
IDENTITY=$(security find-identity -p codesigning 2>/dev/null | grep "$CERT_NAME" | head -1 | awk '{print $2}')
if [ -n "$IDENTITY" ]; then
    codesign --force --deep -s "$IDENTITY" "$APP_BUNDLE"
    echo "已签名: $CERT_NAME ($IDENTITY)"
else
    echo "警告: 证书 '$CERT_NAME' 未找到，请运行 bash setup-codesign.sh"
    codesign --force --deep -s - "$APP_BUNDLE"
    echo "已临时使用 ad-hoc 签名（每次重编译需重新授权权限）"
fi

echo ""
echo "构建完成，正在启动..."
open "$APP_BUNDLE"
echo ""
echo "首次：右键 Finder 中 MiniTranslate.app → 打开（仅一次）"
echo "然后在 系统设置>隐私与安全性 中授权辅助功能和屏幕录制（仅一次）"
