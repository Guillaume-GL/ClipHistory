[English version](README.md)

# ClipHistory

Historique du presse-papiers pour macOS, dans l'esprit de **Win+V** sous Windows ou de Maccy.
Un seul fichier Swift, aucune dépendance, compilé sur ta machine avec les outils d'Apple.

**L'historique reste en mémoire** : il disparaît quand l'app se ferme ou au redémarrage.
Aucun contenu copié n'est enregistré sur le disque.

## Prérequis

- macOS 13 ou plus récent (testé pour Tahoe / macOS 26)
- Outils en ligne de commande d'Apple : `xcode-select -p` doit répondre
  `/Library/Developer/CommandLineTools`. Sinon : `xcode-select --install`.

## Installation

```bash
bash build.sh
```

Le script compile l'app, la signe en local (signature *ad hoc*), l'installe dans
`/Applications/ClipHistory.app` et la lance. Si la nouvelle version ne démarre pas (ou
s'arrête dans les 2 secondes qui suivent son lancement), l'ancienne est remise en place. Pas besoin de `sudo` si ton compte est administrateur.
Si l'app installée n'est pas modifiable (par exemple installée une fois avec `sudo`) ou ne
se ferme pas, le script s'arrête avec un message, sans rien remplacer.

> Les anciennes versions du script installaient l'app dans `~/Applications`. S'il trouve
> cette ancienne copie, le script la supprime une fois la nouvelle lancée (elle pourrait
> sinon être relancée par « Ouvrir à la connexion »). Après ce déplacement, réactive
> ClipHistory dans la liste **Accessibilité** et recoche **Ouvrir à la connexion** dans
> le menu de l'icône.

Au premier collage automatique, macOS demande l'autorisation **Accessibilité**
(Réglages Système > Confidentialité et sécurité > Accessibilité).

> Après chaque recompilation, la signature change : désactive puis réactive ClipHistory
> dans la liste Accessibilité.

## Utilisation

Une icône en forme de trombone apparaît dans la barre des menus. **⌃⌘V** ouvre la fenêtre au niveau du pointeur.

| Touche | Action |
|---|---|
| Taper du texte | Rechercher (sans tenir compte des accents ni des majuscules) |
| ↑ ↓ | Naviguer |
| ↩ ou clic | Coller avec la mise en forme d'origine |
| ⌥↩ ou ⌥ clic | Coller en texte brut |
| ⌘1 … ⌘9 | Coller directement l'un des 9 premiers éléments |
| ⌥⌘1 … ⌥⌘9 | Idem, en texte brut |
| ⌘⌫ | Retirer l'élément de l'historique |
| Échap | Fermer |

Tous les formats copiés sont conservés : texte, texte enrichi, HTML, images, références de fichiers.
Recopier un contenu déjà présent le remonte en tête au lieu de créer un doublon.

## Menu de l'icône

L'interface est en français ou en anglais selon la langue de macOS (la première des langues préférées) :
français si c'est le français, anglais sinon.

- **Afficher l'historique (⌃⌘V)** : ouvre la même fenêtre que le raccourci.
- **Suspendre la capture** : la pause est conservée après un redémarrage.
- **Coller automatiquement** : désactivé, l'élément choisi est seulement remis dans le
  presse-papiers et tu fais ⌘V toi-même. Il n'y a alors pas besoin de l'autorisation Accessibilité.
- **Ouvrir à la connexion**
- **Ignorer les copies depuis « App »** : exclut l'app au premier plan.
- **Apps ignorées** : clique sur une app pour ne plus l'ignorer.
- **Vider l'historique et le presse-papiers**
- **Quitter ClipHistory**

## Confidentialité

- Rien n'est capturé depuis les apps exclues. Par défaut : Trousseau d'accès, Mots de passe,
  1Password, Bitwarden, KeePassXC. Une copie n'est pas enregistrée si une app exclue est passée
  au premier plan juste avant, même brièvement.
- Les copies marquées comme secrètes ou temporaires par l'app d'origine (convention
  [nspasteboard.org](https://nspasteboard.org/)) ne sont jamais enregistrées.
  Ce marquage dépend de l'app qui copie : **un mot de passe copié depuis le Terminal, un
  navigateur ou un fichier texte sera enregistré**. Retire-le avec ⌘⌫, ou exclus l'app.
- Ce qui est déjà dans le presse-papiers au lancement de l'app n'est pas importé.
- Seuls les réglages (pause, collage automatique, apps exclues) sont enregistrés, dans les
  préférences macOS (`local.cliphistory`).
- L'app ne fait aucun appel réseau.

## Limites connues

- **Mémoire** : l'historique est plafonné à environ 512 Mo. Au-delà, les éléments les plus
  anciens sont oubliés ; une copie plus grosse que ce plafond n'est pas conservée. Un pic
  ponctuel reste possible pendant la lecture d'une grosse copie.
- **Collage automatique** : ⌘V n'est envoyé que si l'app au premier plan est toujours celle
  d'où la fenêtre a été ouverte. La fenêtre ou le champ de destination ne sont pas vérifiés.
- **⌃⌘V** remplace, tant que l'app tourne, le « Collage spécial » d'Excel et de Word pour Mac.
- Effacer de la mémoire n'est pas un effacement sécurisé.

## Personnaliser

En haut de `main.swift` :

- `hotKeyCode` / `hotKeyModifiers` / `hotKeyLabel` : le raccourci global
- `maxMemoryBytes` : le plafond mémoire
- `defaultExcludedApps` : les apps exclues par défaut (identifiants de bundle)

L'icône de l'app est dessinée en code dans `main.swift` (section « Icône de l'app ») :
tons du papier et de l'encre dans `appIconPaperWhite` / `appIconInkBlack` / `appIconFaceBlack`.
L'icône de la barre des menus (`makeMenuBarIcon`) reprend le même trombone, sans visage.

Puis relance `bash build.sh`.

## Tests

```bash
bash build.sh test
```

Compile `main.swift` avec `Tests.swift` et lance les tests (historique, langue français /
anglais, raccourci global, icône de l'app et icône de la barre des menus), sans installer ni lancer l'app, et
sans toucher à ton presse-papiers. Chaque test s'affiche avec `PASS` ou `FAIL` ; le code de
retour est 0 si tout passe, différent de 0 sinon.

`bash build.sh install` est accepté et fait la même chose que `bash build.sh`. Tout autre
argument que `test` ou `install` (y compris un argument vide `""` ou un argument en trop, ex.
`bash build.sh test extra`) affiche l'usage et s'arrête avec le code 2, sans rien compiler
ni installer.

## Désinstaller

1. Menu de l'icône > Quitter ClipHistory (et décocher « Ouvrir à la connexion » au préalable)
2. `rm -rf /Applications/ClipHistory.app`
3. Facultatif : `defaults delete local.cliphistory` pour effacer les réglages
4. Retirer ClipHistory de la liste Accessibilité
