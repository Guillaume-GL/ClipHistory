#!/bin/bash
# Compile ClipHistory.app avec les outils en ligne de commande d'Apple et l'installe dans /Applications.
#   bash build.sh        compile, installe et lance l'app
#   bash build.sh test   compile et lance les tests (Tests.swift), sans installer ni lancer l'app
set -euo pipefail
cd "$(dirname "$0")"

APP="ClipHistory.app"
DEST="/Applications"
# Emplacement utilisé par les versions précédentes de ce script.
OLD_DEST="$HOME/Applications"
ARCH="$(uname -m)"

MODE="${1:-install}"
case "$MODE" in
  install|test) ;;
  *)
    # Un argument inconnu (ex. « tests ») ne doit pas déclencher l'installation par défaut.
    echo "Argument inconnu : $MODE" >&2
    echo "Usage : bash build.sh [test]" >&2
    exit 2
    ;;
esac

if [ "$MODE" = "test" ]; then
  # Mode test : un simple exécutable, hors du bundle de l'app. Avec -D TESTING, main.swift
  # appelle runTests() au lieu de lancer l'app. Pas de signature, pas de copie, pas de pkill/open.
  rm -rf build/test
  mkdir -p build/test
  echo "Compilation des tests…"
  xcrun --sdk macosx swiftc -O -swift-version 5 \
    -target "$ARCH-apple-macos13" \
    -D TESTING \
    main.swift Tests.swift -o build/test/ClipHistoryTests
  # Le code de retour du script est celui des tests (0 si tout passe, 1 sinon).
  status=0
  ./build/test/ClipHistoryTests || status=$?
  exit "$status"
fi

rm -rf build
mkdir -p "build/$APP/Contents/MacOS"

echo "Compilation…"
xcrun --sdk macosx swiftc -O -swift-version 5 \
  -target "$ARCH-apple-macos13" \
  main.swift -o "build/$APP/Contents/MacOS/ClipHistory"

# Icône : l'icône est dessinée en code (renderAppIcon dans main.swift). Un petit binaire compilé
# avec -D MAKE_ICON écrit les PNG du .iconset, puis iconutil les assemble en .icns.
echo "Génération de l'icône…"
mkdir -p "build/$APP/Contents/Resources"
xcrun --sdk macosx swiftc -O -swift-version 5 \
  -target "$ARCH-apple-macos13" \
  -D MAKE_ICON \
  main.swift -o build/MakeAppIcon
./build/MakeAppIcon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "build/$APP/Contents/Resources/AppIcon.icns"

cat > "build/$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.cliphistory</string>
  <key>CFBundleName</key><string>ClipHistory</string>
  <key>CFBundleExecutable</key><string>ClipHistory</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
# Quitte toute copie en cours, y compris l'ancienne copie de ~/Applications.
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
# Le « ^ » ancre le chemin au début de la ligne de commande : sans lui,
# « /Applications/ClipHistory.app/… » correspondrait aussi à
# « /Users/moi/Applications/ClipHistory.app/… » (l'ancienne copie).
open "$DEST/$APP" || true
sleep 2
if pgrep -f "^$DEST/$APP/Contents/MacOS/ClipHistory" >/dev/null; then
  rm -rf "$DEST/.$APP.old"
  echo "Installé : $DEST/$APP"
else
  echo "La nouvelle version ne démarre pas." >&2
  restore_old
  exit 1
fi

# Migration : l'ancienne copie de ~/Applications a le même identifiant de bundle et pourrait
# encore être lancée par « Ouvrir à la connexion ». Elle n'est retirée qu'ici, une fois la
# nouvelle version lancée : si l'installation échoue, l'ancienne copie reste utilisable.
if [ -d "$OLD_DEST/$APP" ]; then
  rm -rf "$OLD_DEST/$APP"
  echo "Ancienne copie supprimée : $OLD_DEST/$APP"
  echo "Réactive ClipHistory dans Réglages Système > Accessibilité, et « Ouvrir à la connexion » dans le menu de l'icône."
fi
