# install-thunar

[![ShellCheck](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-informational?logo=linux&logoColor=white)

Ein Shell-Skript, das [Thunar](https://docs.xfce.org/xfce/thunar/start) installiert, es als Standard-Dateiverwaltung festlegt, eine Tastaturkombination zum Öffnen konfiguriert, die Aktion „Open Terminal Here" auf den Terminal-Emulator ausrichtet und eine Aktion „Copy Location Path" hinzufügt, um den Pfad einer Datei oder eines Ordners in die Zwischenablage zu kopieren – auf einer beliebigen Linux-Distribution und einem beliebigen Desktop-Umfeld.

[English](README.md) | **Deutsch**

## Inhaltsverzeichnis

- [Was das Skript tut](#was-das-skript-tut)
- [Verwendung](#verwendung)
  - [Konfiguration zurücksetzen](#konfiguration-zurücksetzen)
  - [Benutzerdefinierte Tastaturkombination](#benutzerdefinierte-tastaturkombination)
  - [Terminal-Emulator für „Open Terminal Here"](#terminal-emulator-für-open-terminal-here)
  - [Copy Location Path](#copy-location-path)
  - [Copy File/Folder Name](#copy-filefolder-name)
  - [Archive extrahieren](#archive-extrahieren)
  - [Archive komprimieren](#archive-komprimieren)
  - [Prüfsummen](#prüfsummen)
  - [Ordnergröße berechnen](#ordnergröße-berechnen)
  - [Create Link](#create-link)
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
5. Fügt eine Aktion „Copy Location Path" zu Thunar hinzu, die den vollständigen Pfad der ausgewählten Datei oder des Ordners in die Zwischenablage kopiert.
6. Fügt eine Aktion „Copy File/Folder Name" zu Thunar hinzu, die den Namen der ausgewählten Datei oder des Ordners (ohne Pfad) in die Zwischenablage kopiert.
7. Fügt Aktionen zur Archivverwaltung zu Thunar hinzu: „Extract Here" und „Extract Here (No Subfolder)" zum Extrahieren sowie „Compress Here" zum Komprimieren.
8. Fügt Aktionen für Prüfsummen hinzu: „Generate Checksum" zum Erstellen von SHA-256-Prüfsummendateien und „Verify Checksum" zum Verifizieren derselben.
9. Fügt eine Aktion „Calculate Folder Size" zu Thunar hinzu, die die rekursive Gesamtgröße ausgewählter Ordner berechnet und anzeigt.
10. Fügt eine Aktion „Create Link" zu Thunar hinzu, um symbolische Links mit Optionen für relative oder absolute Pfade zu erstellen (benötigt ein Dialog-Werkzeug wie `zenity` oder `kdialog`).

## Verwendung

```bash
./install-thunar.sh
```

Das Skript installiert Pakete mit `sudo` nur bei Bedarf; der Rest wird als normaler Benutzer ausgeführt.

Nach der Installation von Thunar fragt das Skript in einem interaktiven Terminal, ob Thunar als Standard-Dateiverwaltung festgelegt und die Tastaturkombination konfiguriert werden sollen (`[Y/n]`, Standard ist Ja). Die Konfiguration des Terminal-Emulators für „Open Terminal Here", die Aktion „Copy Location Path" und die Aktionen zur Archivextraktion laufen immer ab, unabhängig davon, wie diese Eingabe beantwortet wird. Bei nicht-interaktiver Ausführung (z. B. `curl ... | bash` oder mit umgeleiteter/weitergeleiteter Standardeingabe) wird die Eingabeaufforderung übersprungen und die Standardwerte (Ja) für diese zwei Schritte angewendet, während die Konfiguration des Terminal-Emulators, Copy Location und die Archive-Extraktion immer laufen.

### Konfiguration zurücksetzen

Falls die Kontextmenü-Aktionen-Konfiguration von Thunar beschädigt oder defekt wurde, kann das `--resetconfig`-Flag zur Wiederherstellung verwendet werden:

```bash
./install-thunar.sh --resetconfig
```

Dies entfernt die 10 benutzerdefinierten Aktionen, die das Skript verwaltet – „Open Terminal Here", „Copy Location Path", „Copy File/Folder Name", „Extract Here", „Extract Here (No Subfolder)", „Compress Here", „Generate Checksum", „Verify Checksum", „Calculate Folder Size" und „Create Link" – aus `~/.config/Thunar/uca.xml` (falls vorhanden) und führt das Skript dann normal aus, um diese erneut zu erstellen. Es werden nur Aktionen nach Namen entfernt, die dieses Skript verwaltet; weitere selbst hinzugefügte benutzerdefinierte Aktionen werden nicht angerührt. Die Tastaturkombinations-Konfiguration der Desktop-Umgebung wird nicht angerührt.

Das Flag kann gefahrlos verwendet werden, auch wenn `uca.xml` noch nicht existiert oder keine der verwalteten Aktionen vorhanden sind – das Skript wird einfach protokollieren, dass nichts zurückzusetzen ist, und fortfahren.

Das Flag lässt sich normal mit anderen Flags und Umgebungsvariablen kombinieren:

```bash
./install-thunar.sh --resetconfig --terminal alacritty
```

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

### Copy Location Path

Das Skript fügt auch eine benutzerdefinierte Aktion „Copy Location Path" zu Thunars Kontextmenü hinzu, für Dateien und Ordner gleichermaßen. Der vollständige Pfad (einschließlich des Dateinamens) wird als Klartext in die Zwischenablage kopiert, sodass er anderswo eingefügt werden kann.

Dazu wählt es ein Zwischenablage-Tool in dieser Reihenfolge: `wl-copy` (falls eine Wayland-Sitzung über `$WAYLAND_DISPLAY` erkannt wird und `wl-copy` auf `PATH` ist), dann `xclip`, dann `xsel`, dann `wl-copy` nochmals als letzter Ausweg auch ohne erkannte Wayland-Sitzung. Falls keines von `wl-copy`, `xclip` oder `xsel` gefunden wird, wird dieser Schritt ganz übersprungen und nichts verändert – dieses Skript installiert ein Zwischenablage-Tool nicht für Benutzer, genauso wie es einen Terminal-Emulator nicht installiert.

### Copy File/Folder Name

Das Skript fügt auch eine benutzerdefinierte Aktion „Copy File/Folder Name" zu Thunars Kontextmenü hinzu, für Dateien und Ordner gleichermaßen. Der Name der Datei oder des Ordners (ohne Pfad) wird als Klartext in die Zwischenablage kopiert, sodass er anderswo eingefügt werden kann.

Dazu wählt es ein Zwischenablage-Tool in dieser Reihenfolge: `wl-copy` (falls eine Wayland-Sitzung über `$WAYLAND_DISPLAY` erkannt wird und `wl-copy` auf `PATH` ist), dann `xclip`, dann `xsel`, dann `wl-copy` nochmals als letzter Ausweg auch ohne erkannte Wayland-Sitzung. Falls keines von `wl-copy`, `xclip` oder `xsel` gefunden wird, wird dieser Schritt ganz übersprungen und nichts verändert.

### Archive extrahieren

Das Skript fügt auch zwei Aktionen zur Archivextraktion zu Thunars Kontextmenü hinzu: „Extract Here" und „Extract Here (No Subfolder)". Die Aktion „Extract Here" extrahiert ein Archiv in einen neuen Unterordner mit dem Namen des Archivs (z. B. erstellt das Extrahieren von `foo.zip` einen Ordner `./foo/` und extrahiert dessen Inhalte darin), was der sichere Standard ist, der niemals bestehende Dateien überschreibt. Die Aktion „Extract Here (No Subfolder)" extrahiert direkt in das aktuelle Verzeichnis, flacht die Archiv-Inhalte ab, was bestehende Dateien mit denselben Namen überschreiben kann.

Beide Aktionen erscheinen in Thunars Kontextmenü nur für erkannte Archiv-Dateien: `.zip`, `.tar`, `.tar.gz`/`.tgz`, `.tar.bz2`/`.tbz2`, `.tar.xz`/`.txz`, `.tar.zst`, `.7z` und `.rar`.

Das Skript erkennt und nutzt eines der folgenden: `tar`, `unzip`, `7z`, `7za`, `7zr` oder `unrar`, das bereits installiert ist und für das Archiv-Format geeignet ist. Dieses Skript installiert ein Archiv-Tool nicht – es nutzt, welche Extraktions-Tools bereits im System vorhanden sind, die gleiche Philosophie wie der Terminal-Emulator und das Zwischenablage-Tool.

Falls keines dieser Tools gefunden wird, wird dieser Schritt ganz übersprungen und nichts verändert.

### Archive komprimieren

Das Skript fügt auch eine Aktion „Compress Here" zu Thunars Kontextmenü hinzu, um ausgewählte Dateien und Ordner zu komprimieren. Bei genau einem ausgewählten Element wird das Archiv nach diesem Element benannt (z. B. erstellt das Auswählen des Ordners `Photos` eine Datei `Photos.zip`); bei mehreren Elementen wird das Archiv nach dem übergeordneten Ordner benannt.

Das Skript wählt das Archivformat in dieser Reihenfolge: `zip` (erzeugt `.zip`), `tar` (erzeugt `.tar.gz`), `7z`/`7za`/`7zr` (erzeugt `.7z`).

Das Skript überschreibt niemals ein bestehendes Archiv: Existiert der Zielname, werden `name-1.ext`, `name-2.ext` usw. versucht, bis ein freier Name gefunden ist.

Das Skript erkennt und nutzt eines der Archiv-Tools (`tar`, `zip`, `7z`, `7za`, `7zr`), das bereits installiert ist. Dieses Skript installiert ein Kompressions-Werkzeug nicht – es nutzt, welche Tools bereits im System vorhanden sind, die gleiche Philosophie wie die Extract-Aktionen.

Falls keines dieser Tools gefunden wird, wird dieser Schritt übersprungen und nichts verändert.

### Prüfsummen

Das Skript fügt zwei Aktionen zur Verwaltung von SHA-256-Prüfsummen hinzu: „Generate Checksum" und „Verify Checksum".

Die Aktion „Generate Checksum" erstellt eine SHA-256-Prüfsummendatei für ausgewählte Dateien. Bei genau einer ausgewählten Datei wird die Prüfsummendatei nach dieser benannt (z. B. erstellt das Auswählen von `notes.txt` eine Datei `notes.txt.sha256`); bei mehreren ausgewählten Dateien wird sie nach dem übergeordneten Ordner benannt (z. B. `Downloads.sha256`). Das Skript überschreibt niemals eine bestehende Prüfsummendatei: Existiert der Zielname, werden `name-1.sha256`, `name-2.sha256` usw. versucht, bis ein freier Name gefunden ist. Diese Aktion funktioniert nur mit Dateien, nicht mit Ordnern.

Die Aktion „Verify Checksum" überprüft eine ausgewählte `.sha256`-Prüfsummendatei gegen die Dateien, auf die sie sich bezieht. Falls `notify-send` installiert ist, wird das Ergebnis als Desktop-Benachrichtigung angezeigt („Checksum OK" oder „Checksum FAILED" mit Details); ist `notify-send` nicht installiert, wird die Prüfung trotzdem durchgeführt, das Ergebnis kann aber nicht angezeigt werden. Diese Aktion erscheint nur im Kontextmenü für `.sha256`-Dateien.

Beide Aktionen benötigen `sha256sum` (üblicherweise Teil von coreutils). Falls `sha256sum` nicht gefunden wird, werden diese Aktionen ganz übersprungen und nichts verändert.

### Ordnergröße berechnen

Das Skript fügt auch eine Aktion „Calculate Folder Size" zu Thunars Kontextmenü hinzu, um die rekursive Gesamtgröße ausgewählter Ordner zu berechnen und anzuzeigen. Falls `notify-send` installiert ist, wird das Ergebnis als Desktop-Benachrichtigung angezeigt; ist `notify-send` nicht installiert, wird die Berechnung trotzdem durchgeführt, das Ergebnis kann aber nicht angezeigt werden. Diese Aktion erscheint nur im Kontextmenü für Ordner, nicht für Dateien, und funktioniert mit einem oder mehreren ausgewählten Ordnern gleichzeitig.

Diese Aktion benötigt `du` (üblicherweise Teil von coreutils und praktisch immer vorhanden). Falls `du` nicht gefunden wird, wird dieser Schritt übersprungen und nichts verändert.

### Create Link

Das Skript fügt auch eine benutzerdefinierte Aktion „Create Link" zu Thunars Kontextmenü hinzu, um symbolische Links zu erstellen. Die Aktion erscheint nur beim Rechtsklick auf einen Ordner oder auf den leeren Bereich innerhalb eines Ordners (ohne Auswahl einer Datei oder eines Ordners). Sie ergänzt Thunars native „Make Link"/„Paste Link"-Funktion, die stets nur absolute Pfade als symbolische Links erstellt – diese benutzerdefinierte Aktion ermöglicht es, gezielt einen relativen symbolischen Link zu erstellen oder ein beliebiges Ziel zu verlinken, ohne es vorher zu kopieren.

Bei Aufruf werden zwei Dinge abgefragt:
1. Ob ein relativer oder absoluter symbolischer Link erstellt werden soll.
2. Wie das Ziel des Links angegeben wird: Pfad manuell eingeben, nach einer Datei suchen, oder nach einem Ordner suchen.

Der neue Link wird im Zielordner mit dem Namen `link to <Zielname>` erstellt (wobei `<Zielname>` der Name des Linkziels ist). Ist dieser Name bereits vorhanden, werden `link to <Zielname>-1`, `link to <Zielname>-2` usw. versucht, bis ein freier Name gefunden ist.

Bei manueller Pfadeingabe wird ein relativer Pfad relativ zum Zielordner aufgelöst; ein absoluter Pfad wird wie angegeben verwendet. In beiden Fällen wird der Pfad vor der Erstellung zu einem existierenden Ziel aufgelöst – existiert das Ziel nicht, wird kein Link erstellt. Im „Relativ"-Modus wird ein echter relativer Pfad vom Zielordner zum Linkziel berechnet (mittels `realpath --relative-to`), der auf einen beliebigen Ort im Dateisystem verweisen kann.

Das Skript installiert automatisch ein Dialog-Werkzeug, falls weder `zenity` noch `kdialog` vorhanden sind: KDE Plasma erhält `kdialog`, GNOME und andere Desktop-Umgebungen erhalten `zenity`. Die Installation erfolgt unter Verwendung der gleichen Paketmanager-Erkennungskette wie die Thunar-Installation. Auf Fedora-Atomic-Systemen wird das Paket auf das Systemabbild aufgeschichtet und ist erst nach einem Neustart verfügbar – das Skript gibt einen Hinweis am Ende aus, und eine erneute Ausführung nach dem Neustart ist erforderlich. Bei anderen Paketmanagern erfolgt die Installation sofort und sollte im selben Lauf nutzbar sein. Wird kein unterstützter Paketmanager gefunden oder schlägt die Installation fehl, wird diese Aktion übersprungen. Dies ist eine bewusste Ausnahme von der sonstigen Philosophie des Skripts – nur Thunar selbst und dieses Dialog-Werkzeug werden automatisch installiert.

## Unterstützte Paketmanager

`rpm-ostree`, `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `xbps-install`.

## Unterstützte Desktop-Umgebungen (Tastaturkombination)

GNOME, Cinnamon, MATE, XFCE, KDE Plasma (5 und 6, erkannt via `plasmashell --version`). Auf anderen Desktop-Umgebungen installiert das Skript immer noch Thunar und legt es als Standard-Dateiverwaltung fest, gibt aber manuelle Anweisungen zum selbstständigen Binden der Tastaturkombination aus.

Auf KDE Plasma 5 wird die Tastaturkombination sofort angewendet. Auf KDE Plasma 6 gibt es keine zuverlässige Möglichkeit, globale Tastaturkombinationen ohne eine neue Sitzung neu zu laden, daher ist ein Ab- und erneutes Anmelden (oder ein Neustart) erforderlich, bevor sie wirksam werden.

## chezmoi-Integration

Falls [chezmoi](https://www.chezmoi.io/) installiert und bereits initialisiert ist (sein Quellverzeichnis ist ein Git-Repository), fügt das Skript die Konfigurationsdateien, die es geschrieben oder geändert hat – die KDE-Tastaturkombinations-Dateien, die XFCE-Tastaturkombinations-XML, Thunars `uca.xml` (die „Open Terminal Here", „Copy Location Path", „Copy File/Folder Name", „Extract Here", „Extract Here (No Subfolder)", „Compress Here", „Generate Checksum", „Verify Checksum", „Calculate Folder Size" und „Create Link" benutzerdefinierten Aktionen enthält), oder die Terminal-Emulator-Helferdateien (`~/.local/share/xfce4/helpers/custom-TerminalEmulator.desktop` und `~/.config/xfce4/helpers.rc`) – zum chezmoi-Quellzustand hinzu. Dies wird komplett übersprungen, falls chezmoi nicht installiert oder nicht initialisiert ist, und es verändert niemals GNOME/Cinnamon/MATE-Tastaturkombinationen, da diese in der dconf-Datenbank statt in einer Datei leben.

## Beitragen

Issues und Pull Requests sind willkommen. `install-thunar.sh` wird bei jedem Push und Pull Request über GitHub Actions mit [ShellCheck](https://www.shellcheck.net/) überprüft – vor dem Einreichen einer Änderung sollte lokal `shellcheck install-thunar.sh` ausgeführt werden.

## Lizenz

[MIT](LICENSE)

## Urheber

Verwaltet von [Pat9496](https://github.com/Pat9496).
