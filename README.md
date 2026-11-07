# AzerothBuddy 1.0.3

## Entwicklung unter Linux

Öffne diesen Repository-Ordner in Codex oder starte hier `opencode`. Die Projektregeln stehen in [AGENTS.md](AGENTS.md).

- Fedora-Pakete bei Bedarf installieren mit `sudo dnf install luajit zip unzip`.
- `./tools/check.sh` prüft TOC-Dateipfade, Lua-Syntax und die vorhandenen Funktionstests.
- `./tools/package.sh` erstellt nach grüner Prüfung ein lokales Installations-ZIP unter `dist/`. Entpacke den darin enthaltenen Addon-Ordner zur Prüfung in den passenden WoW-Client und führe `/reload` aus.

### Release für WowUp

Für einen beauftragten Release die Version in der TOC, im README-Titel und in
vorhandenen Versionsmeldungen abgleichen. Den geprüften Stand auf `main` hochladen
und einen passenden Git-Tag setzen, etwa `git tag v1.2.3` und
`git push origin v1.2.3`. Die GitHub Action **WowUp Release** führt die Tests
aus, baut das Installations-ZIP und veröffentlicht es im privaten Repository.
In WowUp den passenden Spielclient auswählen und die Repository-URL importieren.
Der WowUp-Zugriffstoken benötigt Leserechte für dieses Repository.

Eigenständiges WoW-Retail-/Midnight-Addon mit Zentrale und Modulen für Charaktere,
Valeera-/Tiefenberatung, Aktionsleisten-Vorlagen sowie
weitere vorhandene Funktionen (z. B. Omnium, Transmog und Meter).
**Eigenes Minimap-Symbol:** goldener Buddy-Kompass. **Blizzard-Aufspürensymbol:**
wird ausschließlich von `AzerothBuddyUI` platziert, nicht von diesem Addon.

## Installation und Bedienung

- Ordner `AzerothBuddy` nach `World of Warcraft/_retail_/Interface/AddOns/` kopieren;
  `.toc` muss direkt in `AddOns/AzerothBuddy/` liegen. Danach Addon aktivieren und `/reload`.
- `/ab` oder `/azerothbuddy`: Zentrale öffnen/schließen.
- Buddy-Kompass: Linksklick Zentrale, Rechtsklick Charakterübersicht;
  Ziehen speichert die Position.
- `/ab chars`, `/ab tiefen`: Modulbedienung.
- `/ab bars` oder `/abbars`: Aktionsleisten-Bereich;
  `/abbars speichern|laden|an|aus|status`: Vorlagen steuern.
- `/tb hilfe`: Tiefenberater.
- Ein Moduswechsel im Tiefenbegleiter überträgt Rolle, Gift und beide Kuriositäten
  automatisch auf Valeera, sobald Blizzard eine zulässige Interaktion mit den
  Begleitervorräten signalisiert (z. B. geöffnetes Valeera-Fenster). Eine reine
  Annäherung wird nicht erkannt; der Wunsch bleibt bis zur nächsten Interaktion
  vorgemerkt.
- Vorlagen werden je Klasse/Spezialisierung verwaltet; vorhandene Aktionen,
  reservierte Plätze und Secret-/Kampfschutz respektieren.
- Eigene SavedVariables: `AzerothBuddyDB` und `AzerothBuddyCharDB`;
  alte separate Addon-Daten werden nicht automatisch importiert.

## Bereinigung vom 06.11.2026

- Buddy-Uhr und Zeitplan vollständig entfernt, einschließlich Module, Menü, Befehle, Events und Timer. Alte Einstellungen werden beim Laden entfernt.
- Valeera nutzt ohne Zeitplan den freien Minimap-Anker; manuelle Positionen bleiben erhalten.
- Version auf ausdrücklichen Auftrag unverändert 1.0.0. AzerothBuddyUI und dessen eigene Fußzeilen-Uhr bleiben unverändert.
- Automatische Prüfungen grün; keine Ingame-, Taint- oder vollständige aktuelle API-Zertifizierung.

## Tiefen und Omnium – 1.0.1

- Giftslot: Null-IDs für Unterbaum und Ersatzzauber überspringen die eigentliche Zaubererkennung nicht mehr. Ein fehlender Giftslot gilt als unvollständige Erkennung. Unbestätigte Entwürfe gelten nicht als übernommen.
- Ursache im Test reproduziert; der konkrete Live-Fehler ist ohne Client-Daten nicht abschließend zugeordnet.
- Omnium bietet genau Tank, Heiler und Schaden; Rollenwahl übernimmt verfügbare Runen über die vorhandene Trait-Transaktion. Keine Sekundärwert-Unterauswahl mehr.
- Empfehlungen und Begründung: `OMNIUM_PROFILES.md`. Fünf ursprüngliche Reihen, keine unbestätigten 12.1.7-Runen.
- Syntax, Funktionstests und TOCs erfolgreich; check.sh insgesamt Exit 1 wegen bereits vorhandenem, abweichendem `dist/AzerothBuddy-1.0.1.zip`. Archiv unverändert, kein Release erstellt.
- Ingame-/Taint-Prüfung ausstehend.

## Omnium-Rollenwahl – 1.0.2

- Während einer laufenden Übernahme wurde ein Rollen-Klick verworfen. Jetzt wird die letzte Wahl gemerkt und nach bestätigter Speicherung im vorhandenen Ablauf übernommen.
- Kein paralleles Schreiben, keine neuen Timer und keine UI-Änderungen. Speicherfehler löschen die gemerkte Wahl ohne Wiederholungsversuch.
- Regression: erster Klick während laufendem Commit, letzte Wahl gewinnt, Slot 4/5 vollständig übernommen, keine Wiederholung nach Speicherfehler. Vor Korrektur fehlgeschlagen, nachher erfolgreich.
- Live-Bestätigung steht aus. Der Tiefen-Giftslot ist dadurch nicht repariert; dessen konkrete Live-Ursache bleibt offen.
- Vorhandenes `dist/AzerothBuddy-1.0.2.zip` gehört zu einem anderen Stand und bleibt unverändert.

## Giftslot-Anzeige – 1.0.3

- Blizzard aktualisiert im Panel-Refresh Rolle und Kuriositäten, setzt beim Flavor-Slot aber nur die Sichtbarkeit. Ein bereits sichtbarer Giftslot kann deshalb nach einem externen Commit den alten Namen behalten.
- Der bestehende Tiefen-Aktualisierungsablauf liest den sichtbaren Giftslot bei abweichender gespeicherter Auswahl neu ein. Kein simuliertes Klicken, keine erneute Trait-Auswahl, keine neuen eigenen Timer oder Layoutänderungen.
- Combat-, IsForbidden-, Secret- und offene-Entwurf-Prüfungen schützen den Zugriff. Sofortige Commit-Prüfung akzeptiert keine noch vorgemerkte Auswahl als Erfolg.
- Quelle: [Blizzard-UI-Quelltext](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_DelvesCompanionConfiguration/Blizzard_DelvesCompanionConfiguration.lua), Panel Refresh und CompanionFlavorSlot, geprüft 06.11.2026.
- Tests grün; check.sh insgesamt Exit 1 wegen bestehendem abweichendem 1.0.3-ZIP. Ingame-Bestätigung des Giftslots ausstehend; Runenwechsel vom Benutzer bestätigt.

## Projektstand und Prüfung

- **Aktive Basis:** `AzerothBuddy-1.0.3/AzerothBuddy/`.
- **Tests:** `TEMP/AzerothBuddy-1.0.3/tests/` (außerhalb des Addonordners).
- **Prüfung:** von der Projektwurzel `./tools/check.sh` ausführen.
- Am 01.11.2026 meldete der Benutzer: automatisierte Projektprüfung erfolgreich;
  die Tracking-Korrektur funktionierte im WoW-Client vor der Versionsumbenennung.
  Andere Client-Funktionen und eine erneute Prüfung nach Umbenennung sind damit
  nicht pauschal als live getestet bestätigt.
- Kein Release-ZIP der Basisversion erstellt; Installation auch aus dem
  lokal vorhandenen Addonordner möglich.
- Herkunft und Lizenzhinweise: `THIRD_PARTY.md`, `LICENSE-*`.
- Omnium-Datengrundlage: `OMNIUM_PROFILES.md` (historischer Datenstand).

## Historie

Frühere Versionen einschließlich der fehlerhaften Tracking-Implementierung
sind ausschließlich historische Berichte, keine aktuellen Anforderungen:
[README-BUDDY-HISTORIE.md](../../docs/README-BUDDY-HISTORIE.md).

**Regel für neue Änderungen:** Erst `AGENTS.md` lesen. Für Codeänderungen
neue Patch-Version (nächste `1.0.1`) als vollständige Versionskopie erstellen;
1.0.0 unverändert lassen.
