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

usage_error() {
  echo "$1" >&2
  echo "Usage : bash build.sh [test]" >&2
  exit 2
}

# Le mode se déduit du NOMBRE d'arguments, pas de leur valeur : avec « ${1:-install} »,
# « bash build.sh "" » (ex. une variable vide) lançait une installation complète.
#   (aucun)        → install
#   test           → test
#   "" / foo       → erreur, rien n'est compilé
#   test extra     → erreur (un argument en trop n'est pas ignoré en silence)
if [ "$#" -gt 1 ]; then
  usage_error "Trop d'arguments : $*"
fi
if [ "$#" -eq 0 ]; then
  MODE="install"
else
  MODE="$1"
fi
case "$MODE" in
  install|test) ;;
  "") usage_error "Argument vide." ;;
  # Un argument inconnu (ex. « tests ») ne doit pas déclencher l'installation par défaut.
  *) usage_error "Argument inconnu : $MODE" ;;
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

# Vérifications avant de toucher à quoi que ce soit : rien n'est encore copié ni arrêté.
# Remplacer l'app demande d'écrire dans $DEST, et supprimer un dossier demande d'écrire dans
# chacun de ses sous-dossiers. Ex. : une app installée une fois avec sudo appartient à root ;
# sans ce contrôle, l'app serait arrêtée puis « mv » échouerait, laissant l'utilisateur sans app.
mkdir -p "$DEST"
if [ ! -w "$DEST" ]; then
  echo "Impossible d'écrire dans $DEST : rien n'a été modifié." >&2
  exit 1
fi
# Affiche le premier dossier non modifiable sous $1 (rien si tout est modifiable ou si $1 n'existe pas).
first_locked_dir() {
  if [ ! -d "$1" ]; then return 0; fi
  while IFS= read -r dir; do
    if [ ! -w "$dir" ]; then
      echo "$dir"
      return 0
    fi
  done < <(find "$1" -type d)
}
# Les restes .new/.old d'une installation précédente sont aussi supprimés plus bas.
for target in "$DEST/$APP" "$DEST/.$APP.new" "$DEST/.$APP.old"; do
  locked="$(first_locked_dir "$target")"
  if [ -n "$locked" ]; then
    echo "Impossible de remplacer $target : $locked n'est pas modifiable (installé avec sudo ?)." >&2
    echo "Rien n'a été modifié, l'app n'a pas été arrêtée. Pour corriger :" >&2
    echo "  sudo chown -R \"\$(id -un)\" \"$target\"" >&2
    exit 1
  fi
done

# Copie d'abord à côté, puis remplace : une copie ratée ne supprime pas la version installée.
rm -rf "$DEST/.$APP.new"
cp -R "build/$APP" "$DEST/.$APP.new"
# pkill et pgrep limités à l'utilisateur courant : sur un Mac à plusieurs comptes, pgrep verrait
# la ClipHistory d'un autre compte, que pkill ne peut pas arrêter (attente inutile, faux diagnostic).
ME="$(id -u)"
# Quitte toute copie en cours, y compris l'ancienne copie de ~/Applications.
pkill -u "$ME" -x ClipHistory 2>/dev/null || true
# pkill ne fait que demander à l'app de quitter : sans attendre sa fin, « open » peut
# tomber sur le processus en train de s'arrêter et échouer (erreur -600). Attente max 5 s.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  pgrep -u "$ME" -x ClipHistory >/dev/null || break
  sleep 0.25
done
# Toujours vivante après 5 s : on s'arrête là. Sinon le contrôle de démarrage plus bas
# trouverait l'ANCIEN processus, conclurait « Installé » et supprimerait la version précédente.
if pgrep -u "$ME" -x ClipHistory >/dev/null; then
  rm -rf "$DEST/.$APP.new"
  echo "ClipHistory ne s'est pas arrêtée en 5 s : rien n'a été remplacé." >&2
  echo "Quitte-la (menu de l'icône > Quitter, ou Moniteur d'activité) puis relance bash build.sh." >&2
  exit 1
fi
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
# Attente du démarrage, max 10 s : un délai fixe prendrait un démarrage lent (ex. 3 s après
# une recompilation) pour un échec, et supprimerait la nouvelle version en plein lancement.
# L'ancienne version est arrêtée (vérifié plus haut) : un processus trouvé ici est le nouveau.
open "$DEST/$APP" || true
started="no"
for _ in $(seq 1 40); do
  if pgrep -u "$ME" -f "^$DEST/$APP/Contents/MacOS/ClipHistory" >/dev/null; then
    started="yes"
    break
  fi
  sleep 0.25
done
if [ "$started" = "yes" ]; then
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
