[Version française](README.fr.md)

# ClipHistory

Clipboard history for macOS, in the spirit of **Win+V** on Windows or Maccy.
A single Swift file, no dependencies, built on your machine with Apple's tools.

**The history stays in memory**: it disappears when the app quits or the Mac restarts.
Nothing you copy is written to disk.

## Requirements

- macOS 13 or later (tested for Tahoe / macOS 26)
- Apple's command line tools: `xcode-select -p` must print
  `/Library/Developer/CommandLineTools`. Otherwise: `xcode-select --install`.

## Installation

```bash
bash build.sh
```

The script builds the app, signs it locally (*ad hoc* signature), installs it in
`/Applications/ClipHistory.app` and launches it. If the new version does not start (or
quits within 2 seconds of launching), the previous one is put back. No need for `sudo` if your account is an administrator.
If the installed app cannot be modified (for example, installed once with `sudo`) or does
not quit, the script stops with a message, without replacing anything.

> Older versions of the script installed the app in `~/Applications`. If it finds
> this old copy, the script deletes it once the new one is running (otherwise it could
> be relaunched by "Open at Login"). After this move, re-enable
> ClipHistory in the **Accessibility** list and tick **Open at Login** again in
> the icon menu.

On the first automatic paste, macOS asks for the **Accessibility** permission
(System Settings > Privacy & Security > Accessibility).

> After each rebuild, the signature changes: turn ClipHistory off and back on
> in the Accessibility list.

## Usage

A paperclip icon appears in the menu bar. **⌃⌘V** opens the window at the pointer.

| Key | Action |
|---|---|
| Type text | Search (ignoring accents and case) |
| ↑ ↓ | Navigate |
| ↩ or click | Paste with the original formatting |
| ⌥↩ or ⌥ click | Paste as plain text |
| ⌘1 … ⌘9 | Paste one of the first 9 items directly |
| ⌘⌫ | Remove the item from the history |
| Esc | Close |

All copied formats are kept: text, rich text, HTML, images, file references.
Copying something that is already in the history moves it to the top instead of creating a duplicate.

## Icon menu

The interface is in French or English depending on the macOS language (the first of your preferred languages):
French if it is French, English otherwise.

- **Show History (⌃⌘V)**: opens the same window as the shortcut.
- **Pause Capture**: the pause is kept after a restart.
- **Paste Automatically**: when off, the chosen item is only put back on the
  clipboard and you press ⌘V yourself. The Accessibility permission is then not needed.
- **Open at Login**
- **Ignore Copies from “App”**: excludes the frontmost app.
- **Ignored Apps**: click an app to stop ignoring it.
- **Clear History and Clipboard**
- **Quit ClipHistory**

## Privacy

- Nothing is captured from excluded apps. By default: Keychain Access, Passwords,
  1Password, Bitwarden, KeePassXC. A copy is not recorded if an excluded app came
  to the front just before, even briefly.
- Copies marked as secret or transient by the source app (the
  [nspasteboard.org](https://nspasteboard.org/) convention) are never recorded.
  This marking depends on the app that copies: **a password copied from Terminal, a
  browser or a text file will be recorded**. Remove it with ⌘⌫, or exclude the app.
- Whatever is already on the clipboard when the app launches is not imported.
- Only the settings (pause, automatic paste, excluded apps) are saved, in the
  macOS preferences (`local.cliphistory`).
- The app makes no network calls.

## Known limitations

- **Memory**: the history is capped at about 512 MB. Beyond that, the oldest items
  are dropped; a copy larger than this cap is not kept. A temporary
  spike is still possible while a large copy is being read.
- **Automatic paste**: ⌘V is only sent if the frontmost app is still the one
  the window was opened from. The destination window or field is not checked.
- **⌃⌘V** replaces, while the app is running, the "Paste Special" shortcut of Excel and Word for Mac.
- Clearing from memory is not a secure erase.

## Customizing

At the top of `main.swift`:

- `hotKeyCode` / `hotKeyModifiers` / `hotKeyLabel`: the global shortcut
- `maxMemoryBytes`: the memory cap
- `defaultExcludedApps`: the apps excluded by default (bundle identifiers)

The app icon is drawn in code in `main.swift` (section "Icône de l'app"):
paper and ink tones in `appIconPaperWhite` / `appIconInkBlack` / `appIconFaceBlack`.
The menu bar icon (`makeMenuBarIcon`) uses the same paperclip, without the face.

Then run `bash build.sh` again.

## Tests

```bash
bash build.sh test
```

Builds `main.swift` with `Tests.swift` and runs the tests (history, French /
English language, global shortcut, app icon and menu bar icon), without installing or launching the app, and
without touching your clipboard. Each test is printed with `PASS` or `FAIL`; the exit
code is 0 if everything passes, non-zero otherwise.

`bash build.sh install` is accepted and does the same as `bash build.sh`. Any
argument other than `test` or `install` (including an empty argument `""` or an extra argument, e.g.
`bash build.sh test extra`) prints the usage and stops with exit code 2, without building
or installing anything.

## Uninstall

1. Icon menu > Quit ClipHistory (and untick "Open at Login" first)
2. `rm -rf /Applications/ClipHistory.app`
3. Optional: `defaults delete local.cliphistory` to erase the settings
4. Remove ClipHistory from the Accessibility list
