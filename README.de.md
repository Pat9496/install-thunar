# install-thunar

[![ShellCheck](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-informational?logo=linux&logoColor=white)

Ein Shell-Skript, das [Thunar](https://docs.xfce.org/xfce/thunar/start) installiert, es als Standard-Dateiverwaltung festlegt, eine Tastaturkombination zum Öffnen konfiguriert, die Aktion „Open Terminal Here" auf den Terminal-Emulator ausrichtet und eine Aktion „Copy Location" hinzufügt, um den Pfad einer Datei oder eines Ordners in die Zwischenablage zu kopieren – auf einer beliebigen Linux-Distribution und einem beliebigen Desktop-Umfeld.

[English](README.md) | **Deutsch**

## Inhaltsverzeichnis

- [Was das Skript tut](#was-das-skript-tut)
- [Verwendung](#verwendung)
  - [Benutzerdefinierte Tastaturkombination](#benutzerdefinierte-tastaturkombination)
  - [Terminal-Emulator für „Open Terminal Here"](#terminal-emulator-für-open-terminal-here)
  - [Copy Location](#copy-location)
  - [Archive extrahieren](#archive-extrahieren)
- [Unterstützte Paketmanager](#unterstützte-paketmanager)
- [Unterstützte Desktop-Umgebungen (Tastaturkombination)](#unterstützte-desktop-umgebungen-tastaturkombination)
- [chezmoi-Integration](#chezmoi-integration)
- [Beitragen](#beitragen)
- [Lizenz](#lizenz)
- [Urheber](#urheber)

## Was das Skript tut

1. Erkennt den Paketmanager und installiert Thunar, falls noch nicht vorhanden (einschließlich Fedora Atomic-Varianten wie Silverblue, Kinoite und Bazzite über `rpm-ostree`).
2. Legt Thunar als Standard-Handler für Verzeichnisse fest (`xdg-mime default thunar.desktop inode/directory`).
3. Erkennt die Desktop-Umgebung und konfiguriert eine Tastaturkombination zum Starten von Thunar.
4. Konfiguriert die Aktion „Open Terminal Here" von Thunar für die Verwendung eines erkannten oder explizit gewählten Terminal-Emulators.
5. Fügt eine Aktion „Copy Location" zu Thunar hinzu, die den vollständigen Pfad der ausgewählten Datei oder des Ordners in die Zwischenablage kopiert.
6. Fügt die Aktionen „Extract Here" und „Extract Here (No Subfolder)" zu Thunar hinzu, um Archive sicher oder direkt zu extrahieren.

## Verwendung

```bash
./install-thunar.sh
```

Das Skript installiert Pakete mit `sudo` nur bei Bedarf; der Rest wird als normaler Benutzer ausgeführt.

Nach der Installation von Thunar fragt das Skript in einem interaktiven Terminal, ob Thunar als Standard-Dateiverwaltung festgelegt und die Tastaturkombination konfiguriert werden sollen (`[Y/n]`, Standard ist Ja). Die Konfiguration des Terminal-Emulators für „Open Terminal Here", die Aktion „Copy Location" und die Aktionen zur Archivextraktion laufen immer ab, unabhängig davon, wie diese Eingabe beantwortet wird. Bei nicht-interaktiver Ausführung (z. B. `curl ... | bash` oder mit umgeleiteter/weitergeleiteter Standardeingabe) wird die Eingabeaufforderung übersprungen und die Standardwerte (Ja) für diese zwei Schritte angewendet, während die Konfiguration des Terminal-Emulators, Copy Location und die Archive-Extraktion immer laufen.

### Benutzerdefinierte Tastaturkombination

Standardmäßig bindet das Skript `Super+E` an das Öffnen von Thunar. Dies kann mit folgendem überschrieben werden:

```bash
THUNAR_SHORTCUT="<Super>f" ./install-thunar.sh
```

### Terminal-Emulator für „Open Terminal Here"

Das Skript wählt einen Terminal-Emulator in dieser Reihenfolge: das Kommandozeilen-Flag `--terminal` (falls angegeben), dann `$THUNAR_TERMINAL` (falls gesetzt), dann `$TERMINAL` (falls es ein Kommando auf `PATH` auflöst), dann `x-terminal-emulator` (Debianscher/Ubuntus `update-alternatives`-Symlink), dann der erste von `alacritty`, `kitty`, `wezterm`, `foot`, `konsole`, `gnome-terminal`, `xfce4-terminal`, `terminator`, `tilix`, `urxvt`, `xterm`, der auf `PATH` gefunden wird. `--terminal` hat Vorrang vor allem anderen, einschließlich `THUNAR_TERMINAL`. Die explizite Überschreibung erfolgt mit einem der folgenden:

```bash
./install-thunar.sh --terminal alacritty
```

```bash
THUNAR_TERMINAL="alacritty" ./install-thunar.sh
```

`./install-thunar.sh --help` führt die komplette Verwendung auf.

Das Skript bearbeitet direkt Thunars `~/.config/Thunar/uca.xml`, um die Aktion „Open Terminal Here" direkt auf den gewählten Terminal auszurichten (z. B. `alacritty --working-directory %f`) statt über `exo-open --launch TerminalEmulator` umzuleiten. Diese Umleitung ist Thunars Standard, aber sie hängt von Xfces `exo`-Framework für bevorzugte Anwendungen ab, das in der Praxis außerhalb einer vollständigen XFCE-Installation oft mit einem Fehler „Could not find fallback TerminalEmulator application" fehlschlägt – sogar wenn die Konfiguration korrekt geschrieben ist – daher umgeht dieses Skript dies für Zuverlässigkeit. Es schreibt auch noch die `exo`-Helferkonfiguration (`~/.config/xfce4/helpers.rc` und eine benutzerdefinierte Helper-`.desktop`) als zusätzliche Sicherheitsebene, falls andere Tools sich darauf verlassen.

Diese direkte Umschreibung erfolgt nur für Terminal-Emulatoren mit einem bekannten Flag zum „Starten in diesem Verzeichnis" (die oben aufgelisteten, außer `x-terminal-emulator` und `xterm`, für die dieses Skript kein zuverlässiges Flag hat). Für alles andere wird nur die `exo`-Helferkonfiguration geschrieben, und Thunars benutzerdefinierte Aktion bleibt unverändert.

Falls kein Terminal-Emulator gefunden werden kann, wird dieser Schritt ganz übersprungen und nichts verändert.

### Copy Location

Das Skript fügt auch eine benutzerdefinierte Aktion „Copy Location" zu Thunars Kontextmenü hinzu, für Dateien und Ordner gleichermaßen. Der vollständige Pfad (einschließlich des Dateinamens) wird als Klartext in die Zwischenablage kopiert, sodass er anderswo eingefügt werden kann.

Dazu wählt es ein Zwischenablage-Tool in dieser Reihenfolge: `wl-copy` (falls eine Wayland-Sitzung über `$WAYLAND_DISPLAY` erkannt wird und `wl-copy` auf `PATH` ist), dann `xclip`, dann `xsel`, dann `wl-copy` nochmals als letzter Ausweg auch ohne erkannte Wayland-Sitzung. Falls keines von `wl-copy`, `xclip` oder `xsel` gefunden wird, wird dieser Schritt ganz übersprungen und nichts verändert – dieses Skript installiert ein Zwischenablage-Tool nicht für Benutzer, genauso wie es einen Terminal-Emulator nicht installiert.

### Archive extrahieren

Das Skript fügt auch zwei Aktionen zur Archivextraktion zu Thunars Kontextmenü hinzu: „Extract Here" und „Extract Here (No Subfolder)". Die Aktion „Extract Here" extrahiert ein Archiv in einen neuen Unterordner mit dem Namen des Archivs (z. B. erstellt das Extrahieren von `foo.zip` einen Ordner `./foo/` und extrahiert dessen Inhalte darin), was der sichere Standard ist, der niemals bestehende Dateien überschreibt. Die Aktion „Extract Here (No Subfolder)" extrahiert direkt in das aktuelle Verzeichnis, flacht die Archiv-Inhalte ab, was bestehende Dateien mit denselben Namen überschreiben kann.

Beide Aktionen erscheinen in Thunars Kontextmenü nur für erkannte Archiv-Dateien: `.zip`, `.tar`, `.tar.gz`/`.tgz`, `.tar.bz2`/`.tbz2`, `.tar.xz`/`.txz`, `.tar.zst`, `.7z` und `.rar`.

Das Skript erkennt und nutzt eines der folgenden: `tar`, `unzip`, `7z`, `7za`, `7zr` oder `unrar`, das bereits installiert ist und für das Archiv-Format geeignet ist. Dieses Skript installiert ein Archiv-Tool nicht – es nutzt, welche Extraktions-Tools bereits im System vorhanden sind, die gleiche Philosophie wie der Terminal-Emulator und das Zwischenablage-Tool.

Falls keines dieser Tools gefunden wird, wird dieser Schritt ganz übersprungen und nichts verändert.

## Unterstützte Paketmanager

`rpm-ostree`, `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `xbps-install`.

## Unterstützte Desktop-Umgebungen (Tastaturkombination)

GNOME, Cinnamon, MATE, XFCE, KDE Plasma (5 und 6, erkannt via `plasmashell --version`). Auf anderen Desktop-Umgebungen installiert das Skript immer noch Thunar und legt es als Standard-Dateiverwaltung fest, gibt aber manuelle Anweisungen zum selbstständigen Binden der Tastaturkombination aus.

Auf KDE Plasma 5 wird die Tastaturkombination sofort angewendet. Auf KDE Plasma 6 gibt es keine zuverlässige Möglichkeit, globale Tastaturkombinationen ohne eine neue Sitzung neu zu laden, daher ist ein Ab- und erneutes Anmelden (oder ein Neustart) erforderlich, bevor sie wirksam werden.

## chezmoi-Integration

Falls [chezmoi](https://www.chezmoi.io/) installiert und bereits initialisiert ist (sein Quellverzeichnis ist ein Git-Repository), fügt das Skript die Konfigurationsdateien, die es geschrieben oder geändert hat – die KDE-Tastaturkombinations-Dateien, die XFCE-Tastaturkombinations-XML, Thunars `uca.xml` (die „Open Terminal Here", „Copy Location", „Extract Here" und „Extract Here (No Subfolder)" benutzerdefinierte Aktionen enthält), oder die Terminal-Emulator-Helferdateien (`~/.local/share/xfce4/helpers/custom-TerminalEmulator.desktop` und `~/.config/xfce4/helpers.rc`) – zum chezmoi-Quellzustand hinzu. Dies wird komplett übersprungen, falls chezmoi nicht installiert oder nicht initialisiert ist, und es verändert niemals GNOME/Cinnamon/MATE-Tastaturkombinationen, da diese in der dconf-Datenbank statt in einer Datei leben.

## Beitragen

Issues und Pull Requests sind willkommen. `install-thunar.sh` wird bei jedem Push und Pull Request über GitHub Actions mit [ShellCheck](https://www.shellcheck.net/) überprüft – vor dem Einreichen einer Änderung sollte lokal `shellcheck install-thunar.sh` ausgeführt werden.

## Lizenz

[MIT](LICENSE)

## Urheber

Verwaltet von [Pat9496](https://github.com/Pat9496).
