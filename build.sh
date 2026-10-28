#!/bin/bash
# Compile ClipHistory.app avec les outils en ligne de commande d'Apple et l'installe dans ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="ClipHistory.app"
DEST="$HOME/Applications"
ARCH="$(uname -m)"

rm -rf build
mkdir -p "build/$APP/Contents/MacOS"

echo "Compilation…"
xcrun --sdk macosx swiftc -O -swift-version 5 \
  -target "$ARCH-apple-macos13" \
  main.swift -o "build/$APP/Contents/MacOS/ClipHistory"

cat > "build/$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.cliphistory</string>
  <key>CFBundleName</key><string>ClipHistory</string>
  <key>CFBundleExecutable</key><string>ClipHistory</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "build/$APP"

# Copie d'abord à côté, puis remplace : une copie ratée ne supprime pas la version installée.
mkdir -p "$DEST"
rm -rf "$DEST/.$APP.new"
cp -R "build/$APP" "$DEST/.$APP.new"
pkill -x ClipHistory 2>/dev/null || true
rm -rf "$DEST/.$APP.old"
if [ -d "$DEST/$APP" ]; then mv "$DEST/$APP" "$DEST/.$APP.old"; fi
restore_old() {
  rm -rf "$DEST/$APP"
  if [ -d "$DEST/.$APP.old" ]; then
    mv "$DEST/.$APP.old" "$DEST/$APP"
    open "$DEST/$APP" || true
    echo "Version précédente restaurée." >&2
  fi
}

if ! mv "$DEST/.$APP.new" "$DEST/$APP"; then
  echo "Échec du remplacement." >&2
  restore_old
  exit 1
fi

# L'ancienne version n'est supprimée qu'une fois la nouvelle effectivement lancée.
open "$DEST/$APP" || true
sleep 2
if pgrep -f "$DEST/$APP/Contents/MacOS/ClipHistory" >/dev/null; then
  rm -rf "$DEST/.$APP.old"
  echo "Installé : $DEST/$APP"
else
  echo "La nouvelle version ne démarre pas." >&2
  restore_old
  exit 1
fi
