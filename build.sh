#!/bin/bash
set -e

APP_NAME="Klok"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🧹 Cleaning previous build..."
rm -rf "$APP_BUNDLE"

echo "📁 Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🔨 Compiling Swift sources..."
swiftc Sources/*.swift \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework AppKit \
    -framework Foundation \
    -O \
    2>&1

echo "📋 Copying resources..."
cp Resources/Info.plist "$CONTENTS/"
cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"

# Optional: create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo ""
echo "✅ Build complete!"
echo ""
echo "To run:"
echo "   open $APP_BUNDLE"
echo ""
echo "To auto-start on login, drag Klok.app to Login Items in System Settings."
