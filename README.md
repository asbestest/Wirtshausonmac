# Wirtshaus covers my Mac

Spielkarten und Kleinkram, die über allem schweben – über Browsern, normalen Apps und auch über Vollbild-Apps.
Damit lassen sich kleine Dinge auf dem Bildschirm verdecken. Geschwister-Projekt von Rugonmac.

- Jede Karte ist ein eigenes, kartengroßes Fenster: alles drumherum bleibt klickbar.
- Klicken/Ziehen einer Karte aktiviert die App nicht – man fliegt also nicht aus dem Vollbild.
- Größe per Schieberegler (Menüleiste, Rechtsklick-Menü, Einstellungen), 8 bis 900 pt, logarithmisch.
  Scrollen oder Zoomen mit zwei Fingern über der Karte geht auch.
- Drehen: Zwei-Finger-Drehgeste, ⌥ + Scrollen oder Schieberegler (rastet bei 0°/90°/180° ein).
  Die leeren Ecken eines gedrehten Fensters lassen Klicks durch.
- Zwei Blätter, nur die wichtigen Karten, selbst als Vektorgrafik gezeichnet und scharf in jeder Größe:
  französisch für Skat (Buben, Asse; `CardArt.swift`) und bayerisch für Schafkopf
  (Ober, Unter, Säue mit Eichel/Gras/Herz/Schellen; `BavarianArt.swift`). Umschalten tauscht Bube ↔ Ober, Ass ↔ Sau.
  Das bayerische Blatt nutzt Kartenbilder aus `Resources/bavarian/` (`<farbe>-<ober|unter|sau>.jpg`, Farbe 0–3 =
  Eichel, Gras, Herz, Schellen). Sie werden mit `swift scripts/crop-bavarian.swift Artwork/bayerisches-blatt.webp`
  aus einem Bild des ganzen Blatts (4 Reihen × 8 Spalten) geschnitten; kleine Vorlagen rechnet das Skript mit
  MetalFX auf 4× hoch und schärft leicht nach. Für echte Schärfe ein höher aufgelöstes Bild nehmen und das Skript
  erneut laufen lassen. Fehlt ein Bild, wird die Karte gezeichnet.
- Schlank: jede Karte hält nur ein fertiges Bild (kein zweiter AppKit-Puffer), Kartenbilder werden erst beim Zeichnen
  und nur in der nötigen Größe dekodiert, große Dinge rendern mit höchstens ~1100 px, das Einstellungsfenster wird
  beim Schließen freigegeben. Typisch 11–14 MB Speicher.
- Animierte Dinge (`PropArt.swift`): Maß Bier, Zigarette, Bratwurstsemmel, Kaffee, Brezn. Feste Ebenen werden
  einmal gerendert, pro Bild (20 fps) nur Rauch, Dampf, Schaum usw. – ca. 5 % CPU pro Ding.
  Rauch und Dampf lassen Klicks durch.
- **Fixieren** (⌃⌥⌘L): Karten lassen jeden Klick an die App darunter durch und können nicht verrutschen.
- **Ein/Aus** (⌃⌥⌘K), systemweit, auch im Vollbild.

## Bauen

```sh
scripts/build.sh            # "build/Wirtshaus covers my Mac.app" (Apple silicon + Intel)
scripts/build.sh --install  # nach /Applications kopieren und starten
scripts/package.sh          # dist/Wirtshaus-covers-my-Mac-<version>.zip zum Weitergeben
```

Braucht nur die Xcode Command Line Tools. Debug (Programm `Wirtshaus` im App-Bundle): `--snapshot cards.png` rendert alle Karten,
`--icon icon.png` das App-Icon, `--settings settings.png` das Einstellungsfenster, `--turned turned.png` gedrehte Dinge samt Klickbereich, `--bench` misst die Zeichenzeit der Dinge.

Hieß früher Cardonmac; die Einstellungen von dort werden beim ersten Start übernommen.

## Weitergeben

Die Zip-Datei aus `dist/` verschicken; die enthaltene „Zum Installieren.txt“ erklärt den ersten Start.
Die App ist nur ad-hoc signiert, daher fragt macOS beim ersten Öffnen nach
(Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“). Ohne diese Abfrage ginge es nur mit
einer Developer-ID-Signatur und Notarisierung (Apple Developer Program).
