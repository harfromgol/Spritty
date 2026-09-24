# Spritty für macOS

[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-orange)](LICENSE)

Spritty ist eine kleine macOS-Menüleisten-App (SwiftUI), die die aktuellen
Spritpreise ausgewählter Tankstellen direkt in der Menüleiste anzeigt. Die
Preisdaten kommen von [Tankerkönig](https://creativecommons.tankerkoenig.de).

> [!WARNING]
> Dies ist ein reines Vibe-Coding-Projekt: Die App wurde komplett mit Claude Code
> erstellt. Nutzung auf eigene Gefahr! :)

## Funktionen

- **Nur Menüleiste** – kein Dock-Symbol, keine App-Menüleiste, keine
  Hauptfenster. Sichtbar ist nur das Zapfsäulen-Symbol mit dem Preis der obersten
  angepinnten Tankstelle.
- **Angepinnte Tankstellen/Sorten** – beliebig viele Kombinationen aus Tankstelle
  und Spritsorte (Diesel, Super E5, Super E10). Ein Klick auf das Symbol zeigt sie
  alle mit ihrem letzten Preis; per Auf/Ab-Pfeil legst du die Reihenfolge fest.
  Der Preis der obersten Zeile erscheint in der Menüleiste.
- **Tankstelle wählen** – Umkreissuche um den aktuellen Standort mit Filter nach
  Sorte; je Tankstelle und Sorte eine Checkbox zum Anpinnen.
- **Automatische Aktualisierung** – manuell, alle 30, 60 oder 120 Minuten. Die
  Preise aus einer Umkreissuche werden direkt für bereits angepinnte Kombinationen
  übernommen.
- **Schonender Umgang mit der API** – nach jeder Abfrage an Tankerkönig ist der
  Button „Tankstelle wählen“ für 5 Minuten gesperrt und zeigt stattdessen einen
  Countdown.
- **Einstellungen** – Tankerkönig-API-Schlüssel, Suchradius (1–25 km),
  Erscheinungsbild (Hell/Dunkel/System) und „App bei Anmeldung starten“.

## Voraussetzungen

- macOS 26 oder neuer
- Xcode 26 und [XcodeGen](https://github.com/yonaskolb/XcodeGen) zum Bauen
- Ein kostenloser API-Schlüssel von
  [Tankerkönig](https://creativecommons.tankerkoenig.de)

## Bauen und starten

```bash
xcodegen generate
xcodebuild -project Spritty.xcodeproj -scheme Spritty -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Spritty.app
```

Das Xcode-Projekt (`Spritty.xcodeproj`) wird aus `project.yml` erzeugt und ist
deshalb nicht eingecheckt. Nach dem Hinzufügen neuer Quelldateien einfach
`xcodegen generate` erneut ausführen.

## Erste Schritte

1. Zapfsäulen-Symbol in der Menüleiste anklicken und über das Zahnrad die
   **Einstellungen** öffnen.
2. Im Abschnitt **Tankerkönig** den API-Schlüssel eintragen (ein grüner Rahmen
   zeigt einen gültigen Schlüssel) und den Suchradius wählen, dann auf **Fertig**
   klicken.
3. Im Popover **Tankstelle wählen** anklicken, den Zugriff auf den Standort
   erlauben und in der Liste die gewünschten Tankstellen/Sorten anhaken.

## Datenschutz

- Der API-Schlüssel und deine Auswahl werden ausschließlich lokal gespeichert
  (`UserDefaults` im Sandbox-Container der App).
- Dein Standort wird nur für die Umkreissuche verwendet und nur dann abgefragt,
  wenn du „Tankstelle wählen“ anklickst.
- Es gibt keine Konten, keine Analyse und keine Anfragen an andere Server als
  Tankerkönig.

## Projektstruktur

```
Sources/
  App/          Einstieg (SprittyApp), Erscheinungsbild
  Models/       Tankstelle, Spritsorte, angepinnte Auswahl
  Services/     Tankerkönig-API, Standortermittlung
  Persistence/  UserDefaults-Speicher (Schlüssel, Auswahl, Preis-Cache)
  Views/        Menüleisten-Popover, Tankstellenauswahl, Einstellungen
Resources/      Info.plist, Entitlements, Asset-Katalog mit App-Icon
Scripts/        Generator für das App-Icon
```

Das App-Icon wird mit `swift Scripts/generate_app_icon.swift` erzeugt.

## Lizenz

Spritty steht unter der [MIT-Lizenz](LICENSE). Für die Preisdaten gilt
zusätzlich die Lizenz von Tankerkönig (siehe unten).

## Datenquelle

Preisdaten: [Tankerkönig](https://creativecommons.tankerkoenig.de) –
Lizenz [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Die Daten stammen
von der Markttransparenzstelle für Kraftstoffe (MTS-K).
