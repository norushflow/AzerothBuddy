# AzerothBuddy

AzerothBuddy ist ein eigenständiges WoW-Addon für WoW Forever. Zentrale, Charaktere, Valeera/Tiefen, Aktionsleisten-Vorlagen, Omnium, Transmog und Meter.

Beginne bei `Core.lua`, `Initialize.lua` und dem betroffenen Verzeichnis in `Modules/`. Der Buddy-Kompass bleibt eigenständig. Das native Blizzard-Tracking gehört zu AzerothBuddyUI.

## Ablauf für Codex und OpenCode

1. Öffne dieses Git-Repository als Projekt. Arbeite pro Aufgabe mit einem Assistenten. Prüfe `git status --short`, die aktuelle Version und Ladereihenfolge in `AzerothBuddy.toc` sowie die relevanten Stellen in der README.
2. Führe `./tools/check.sh` vor und nach Änderungen aus. Bearbeite den aktuellen Git-Arbeitsordner in kleinen Diffs. Bestehende lokale Änderungen erhalten. Für einen separaten Arbeitsstand einen Git-Branch verwenden.
3. Verwende die vorhandenen LuaJIT-Tests in `tests/`. Prüfe bei Änderungen an der WoW-API den Zielclient und belastbare Quellen. Für UI, Kampf und Taint ist ein Test im passenden WoW-Client nötig.
4. Prüfe `git diff --check` und den Inhalt des Diffs. Berichte kurz auf Deutsch unter **Geändert**, **Geprüft** und **Offen**. Wenn das Werkzeug gewechselt wird, im neuen Chat Ziel, betroffene Dateien, Prüfstatus und nächsten Schritt nennen.

## WoW und Releases

- Bestehende SavedVariables, Slash-Befehle und die Unabhängigkeit von den anderen Addons erhalten. Bei Secret Values vorhandene Guards und Typprüfungen nutzen. Geschützte Frames im Kampf unangetastet lassen, verbotene Frames abfangen und vorhandene Cleanup-Guards erhalten.
- Bestehende Ereignisse nutzen. Keine neuen dauerhaften Polling-Schleifen, automatischen CVar-Änderungen beim Login oder Laufzeitabhängigkeiten ohne Auftrag einführen.
- Bei Verhaltensänderungen die README knapp ergänzen. Die Version erst für einen beauftragten Release anpassen. TOC, vorhandene interne Versionsmeldungen und README-Kopf abgleichen. Historische Einträge erhalten.
- `./tools/package.sh` erzeugt auf Auftrag nach grüner Prüfung ein lokales Installations-ZIP unter `dist/`. GitHub-Uploads, Tags und Releases nur im jeweils beauftragten Umfang. Zugangsdaten, SavedVariables-Dateien, Fremd-Addons, ZIPs und Backups bleiben lokal.
