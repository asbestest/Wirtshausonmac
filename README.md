# Wirtshausonmac

Spielkarten und Wirtshaus-Kleinkram, die über allem schweben: über normalen Apps, Browsern und auch über Vollbild-Apps.

![Wirtshausonmac](docs/screenshot.jpg)

- Französisches Blatt für Skat und bayerisches für Schafkopf, jeweils mit den wichtigen Karten
- Dazu animiert: Maß Bier, Zigarette, Bratwurstsemmel, Kaffee und Brezn
- Jede Karte ist ein eigenes kleines Fenster. Klicken oder Ziehen holt einen nicht aus dem Vollbild.
- Größe von 8 bis 900 pt, mit zwei Fingern zoomen und drehen
- **Fixieren** (⌃⌥⌘L): Klicks gehen durch die Karten hindurch an die App darunter
- **Ein/Aus** (⌃⌥⌘K), auch im Vollbild
- Typisch 11–14 MB Speicher, etwa 5 % CPU pro animiertem Ding

## Installieren

1. Die Zip-Datei unter [Releases](../../releases/latest) laden und entpacken.
2. `Wirtshausonmac.app` in den Programme-Ordner ziehen.
3. Einmal im Terminal ausführen, weil die App nicht notarisiert ist:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Wirtshausonmac.app
   ```
4. Öffnen.

Benötigt macOS 14, läuft auf Apple-Chip und Intel. Ausführlich: [Zum Installieren.txt](Zum%20Installieren.txt).

## Bauen

Es reichen die Xcode Command Line Tools.

```sh
scripts/build.sh --install   # Universal-App bauen, nach /Applications kopieren, starten
scripts/package.sh           # dist/Wirtshausonmac-<version>.zip zum Weitergeben
```

Die bayerischen Karten in `Resources/bavarian/` schneidet `scripts/crop-bavarian.swift` aus einem Bild des ganzen Blatts. Fehlt ein Bild, wird die Karte gezeichnet.

Debug-Ausgaben des Programms im App-Bundle: `--snapshot`, `--icon`, `--settings`, `--turned` (jeweils mit PNG-Pfad), `--bench`.
