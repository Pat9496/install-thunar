# install-thunar

[![ShellCheck](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-informational?logo=linux&logoColor=white)

A shell script that installs [Thunar](https://docs.xfce.org/xfce/thunar/start), sets it as the default file manager, configures a keyboard shortcut to open it, points its "Open Terminal Here" action at your terminal emulator, and adds a "Copy Location Path" action to copy a file or folder's path to the clipboard — on any Linux distribution and any desktop environment.

**English** | [Deutsch](README.de.md)

## Why Thunar

Thunar is the default file manager of the [Xfce](https://www.xfce.org/) desktop, but it runs perfectly well as a standalone GTK application on any desktop environment, without pulling in the rest of Xfce. Compared to heavier alternatives like GNOME Files (Nautilus) or Dolphin, it starts fast and stays light on memory, while still covering the essentials: tabs, split view, bulk rename, thumbnails, and a built-in [custom actions](https://docs.xfce.org/xfce/thunar/custom-actions) system that lets you add arbitrary right-click commands — exactly the mechanism this script uses to add its terminal, clipboard, archive, checksum, and symlink actions. If you want a file manager that's quick to open, easy on resources, and scriptable without needing a whole desktop environment around it, Thunar is a solid choice regardless of which DE you actually use.

The name comes from *Thunar*, the Old Saxon name for [Thor](https://en.wikipedia.org/wiki/Thor), the Germanic god of thunder — fittingly, its icon is Thor's hammer, Mjölnir.

## Table of Contents

- [Why Thunar](#why-thunar)
- [What it does](#what-it-does)
- [Usage](#usage)
  - [Resetting custom actions](#resetting-custom-actions)
  - [Custom shortcut](#custom-shortcut)
  - [Terminal emulator for "Open Terminal Here"](#terminal-emulator-for-open-terminal-here)
  - [Copy Location Path](#copy-location-path)
  - [Extract archives](#extract-archives)
  - [Compress files](#compress-files)
  - [Copy File/Folder Name](#copy-filefolder-name)
  - [Checksums](#checksums)
  - [Calculate Folder Size](#calculate-folder-size)
  - [Create Link](#create-link)
- [Supported package managers](#supported-package-managers)
- [Supported desktop environments (keyboard shortcut)](#supported-desktop-environments-keyboard-shortcut)
- [chezmoi integration](#chezmoi-integration)
- [Contributing](#contributing)
- [License](#license)
- [Credits](#credits)

## What it does

See [Why Thunar](#why-thunar) if you're wondering why this script targets Thunar specifically.

1. Detects your package manager and installs Thunar if it isn't already present (including Fedora Atomic variants such as Silverblue, Kinoite, and Bazzite via `rpm-ostree`).
2. Sets Thunar as the default handler for directories (`xdg-mime default thunar.desktop inode/directory`).
3. Detects your desktop environment and configures a keyboard shortcut to launch Thunar.
4. Configures Thunar's "Open Terminal Here" action to use a detected (or explicitly chosen) terminal emulator.
5. Adds a "Copy Location Path" action to Thunar that copies the full path of the selected file or folder to the clipboard.
6. Adds "Extract Here", "Extract Here (No Subfolder)", and "Compress Here" actions to Thunar for extracting archives safely, extracting in place, or compressing files and folders into a new archive.
7. Adds a "Copy File/Folder Name" action to Thunar that copies the file or folder name (without the path) to the clipboard.
8. Adds "Generate Checksum" and "Verify Checksum" actions to Thunar for creating and verifying SHA-256 checksums of files.
9. Adds a "Calculate Folder Size" action to Thunar to display the total recursive size of selected folders.
10. Adds a "Create Link" action to Thunar that creates a symbolic link in a folder pointing to a file or folder you choose, with options for relative or absolute symlink paths.

## Usage

```bash
./install-thunar.sh
```

The script installs packages with `sudo` only when required; the rest runs as your normal user.

After installing Thunar, if the script is running in an interactive terminal it asks whether to set Thunar as the default file manager and configure the keyboard shortcut (`[Y/n]`, defaults to yes). The configuration of the terminal emulator for "Open Terminal Here", the "Copy Location Path" custom action, and the archive extraction actions always run, regardless of how you answer this prompt. When run non-interactively (e.g. `curl ... | bash`, or with stdin piped/redirected), it skips the prompt and applies the default (yes) to those two steps, while always running the terminal emulator, Copy Location Path, and archive extraction configuration.

### Resetting custom actions

If Thunar's custom actions configuration has become corrupted or broken, use the `--resetconfig` flag to recover:

```bash
./install-thunar.sh --resetconfig
```

This removes the 10 custom actions that the script manages — "Open Terminal Here", "Copy Location Path", "Copy File/Folder Name", "Extract Here", "Extract Here (No Subfolder)", "Compress Here", "Generate Checksum", "Verify Checksum", "Calculate Folder Size", and "Create Link" — from `~/.config/Thunar/uca.xml` (if they are present), then runs the script normally to recreate them fresh. It only removes actions by name that this script manages; any custom actions you have added yourself are left untouched. The keyboard shortcut configuration for your desktop environment is not affected.

This flag is safe to use even if `uca.xml` doesn't exist yet or none of the managed actions are present — it will simply note that there's nothing to reset and continue.

It combines with other flags and environment variables normally:

```bash
./install-thunar.sh --resetconfig --terminal alacritty
```

If you'd rather wipe *every* custom action in `uca.xml` — including ones you added yourself or that came from somewhere else, not just the ones this script manages — use `--reset-all-actions` instead:

```bash
./install-thunar.sh --reset-all-actions
```

This deletes every `<action>` entry in `~/.config/Thunar/uca.xml`, then runs the script normally so its own 10 actions are recreated fresh. Nothing else is touched — your keyboard shortcut, default file manager setting, and terminal helper files are all left exactly as they are. Like `--resetconfig`, it's safe to use even if `uca.xml` doesn't exist yet, and it combines normally with other flags (e.g. `./install-thunar.sh --reset-all-actions --terminal alacritty`).

### Custom shortcut

By default the script binds `Super+E` to open Thunar. Override it with:

```bash
THUNAR_SHORTCUT="<Super>f" ./install-thunar.sh
```

### Terminal emulator for "Open Terminal Here"

The script picks a terminal emulator, in order: the `--terminal` command-line flag if given, then `$THUNAR_TERMINAL` if set, then `$TERMINAL` (if it resolves to a command on `PATH`), then `x-terminal-emulator` (Debian/Ubuntu's `update-alternatives` symlink), then the first of `alacritty`, `kitty`, `wezterm`, `foot`, `konsole`, `gnome-terminal`, `xfce4-terminal`, `terminator`, `tilix`, `urxvt`, `xterm` found on `PATH`. `--terminal` takes precedence over everything else, including `THUNAR_TERMINAL`. Override it explicitly with either:

```bash
./install-thunar.sh --terminal alacritty
```

```bash
THUNAR_TERMINAL="alacritty" ./install-thunar.sh
```

Run `./install-thunar.sh --help` for full usage.

The script edits Thunar's own `~/.config/Thunar/uca.xml` directly, pointing the "Open Terminal Here" custom action straight at the chosen terminal (e.g. `alacritty --working-directory %f`) instead of routing through `exo-open --launch TerminalEmulator`. That indirection is Thunar's own default, but it depends on Xfce's `exo` "preferred applications" framework, which in practice often fails outside a full XFCE install with a "Could not find fallback TerminalEmulator application" error — even when its config is written correctly — so this script bypasses it for reliability. It still also writes the `exo` helper config (`~/.config/xfce4/helpers.rc` and a custom helper `.desktop`) as a best-effort secondary layer, in case other tools rely on it.

This direct rewrite is only done for terminals with a known "start in this directory" flag (the ones listed above, minus `x-terminal-emulator` and `xterm`, which don't have one this script can rely on). For anything else, only the `exo` helper config is written, and Thunar's custom action is left as-is.

If no terminal emulator can be found, this step is skipped entirely and nothing is touched.

### Copy Location Path

The script also adds a "Copy Location Path" custom action to Thunar's right-click menu, for both files and folders. It copies the full path (including the filename) to the clipboard as plain text, so it can be pasted elsewhere.

To do this, it picks a clipboard tool, in order: `wl-copy` (if a Wayland session is detected via `$WAYLAND_DISPLAY` and `wl-copy` is on `PATH`), then `xclip`, then `xsel`, then `wl-copy` again as a last resort even without a detected Wayland session. If none of `wl-copy`, `xclip`, or `xsel` are found, this step is skipped entirely and nothing is touched — this script does not install a clipboard tool for you, the same way it doesn't install a terminal emulator for you.

### Extract archives

The script also adds two archive extraction actions to Thunar's right-click menu: "Extract Here" and "Extract Here (No Subfolder)". The "Extract Here" action extracts an archive into a new subfolder named after the archive (e.g. extracting `foo.zip` creates `./foo/` and extracts its contents into it), which is the safe default that never overwrites existing files. The "Extract Here (No Subfolder)" action extracts directly into the current directory, flattening the archive's contents in place, which can overwrite existing files with the same names.

Both actions appear in Thunar's right-click menu only for recognized archive files: `.zip`, `.tar`, `.tar.gz`/`.tgz`, `.tar.bz2`/`.tbz2`, `.tar.xz`/`.txz`, `.tar.zst`, `.7z`, and `.rar`.

The script detects and uses whichever of `tar`, `unzip`, `7z`, `7za`, `7zr`, or `unrar` is already installed and appropriate for the archive's format. This script does not install any archive tool for you — it uses whatever extraction tools are already on your system, the same philosophy as the terminal emulator and clipboard tool.

If none of those tools are found, this step is skipped entirely and nothing is touched.

### Compress files

The script also adds a "Compress Here" custom action to Thunar's right-click menu for compressing files and folders into new archives. The action description in Thunar reads "Compress the selected files or folders into a new archive".

When you right-click one or more files or folders and select "Compress Here", the script compresses them into a single archive in the same directory. If exactly one item is selected, the archive is named after that item (for example, selecting a folder named `Photos` creates `Photos.zip` next to it; selecting a file named `notes.txt` creates `notes.txt.zip`). If multiple items are selected, the archive is named after the containing folder.

The script chooses the archive format based on whichever compression tool is available, in priority order: `zip` (produces `.zip`), `tar` (produces `.tar.gz`), or one of `7z`, `7za`, `7zr` (produces `.7z`). If none of these tools are found, this action is not added.

The script never overwrites an existing archive. If the target name already exists, it tries `name-1.ext`, `name-2.ext`, and so on until it finds a free name.

The "Compress Here" action is gated by the same tool detection as the extract actions (see [Extract archives](#extract-archives) above): if none of the required tools are found, none of the three archive actions — "Extract Here", "Extract Here (No Subfolder)", or "Compress Here" — are configured, and nothing is touched.

### Copy File/Folder Name

The script also adds a "Copy File/Folder Name" custom action to Thunar's right-click menu for both files and folders. It copies the file or folder name (without the path) to the clipboard as plain text, so it can be pasted elsewhere.

Like the "Copy Location Path" action, it uses the same clipboard tool detection: `wl-copy` (if a Wayland session is detected), then `xclip`, then `xsel`, then `wl-copy` again as a last resort. If none of these tools are found, this step is skipped entirely.

### Checksums

The script also adds two checksum actions to Thunar's right-click menu: "Generate Checksum" and "Verify Checksum". Both work with SHA-256 checksums.

The "Generate Checksum" action hashes one or more files into a single checksum file in the same directory. If exactly one file is selected, the checksum file is named after that file (for example, selecting `notes.txt` creates `notes.txt.sha256`). If multiple files are selected, the checksum file is named after the containing folder. The script never overwrites an existing checksum file; if the target name already exists, it tries `name-1.sha256`, `name-2.sha256`, and so on until it finds a free name. This action is only available if `sha256sum` is installed.

The "Verify Checksum" action appears in Thunar's right-click menu only for `.sha256` files. It verifies the selected checksum file using `sha256sum -c`. If `notify-send` is installed, the result ("Checksum OK" or "Checksum FAILED" with details) is shown as a desktop notification; otherwise the verification runs but has no way to display the result. Requires `sha256sum`.

If `sha256sum` is not found, neither of these actions is added.

### Calculate Folder Size

The script also adds a "Calculate Folder Size" custom action to Thunar's right-click menu for folders. It displays the total recursive size of one or more selected folders using `du -sch`. If `notify-send` is installed, the result is shown as a desktop notification; otherwise the size is calculated but has no way to be displayed. Requires `du` (part of coreutils, virtually always present).

If `du` is not found, this action is not added.

### Create Link

The script also adds a "Create Link" custom action to Thunar's right-click menu for folders. It creates a symbolic link in the folder (or the empty space of the folder you right-click in) pointing to a file or folder you choose. The action description in Thunar reads "Create a symbolic link in this folder pointing to a file or folder you choose".

When you right-click a folder (or empty space within a folder) and select "Create Link", the script prompts you twice, using whichever of `zenity` or `kdialog` is available:

1. Whether to create a relative or an absolute symlink. A relative symlink works from within that folder and uses a path relative to it; an absolute symlink includes the full filesystem path and works from anywhere.
2. How to specify the link's target: type a path manually, or browse for a file, or browse for a folder.

If you type a path, relative paths are resolved relative to the destination folder (the one you right-clicked in); absolute paths are used as-is. Either way, the target path must exist before the symlink is created. Relative mode computes a genuine relative path from the destination folder to the target using `realpath --relative-to`, which can point anywhere in the filesystem.

The symlink is created with the name `link to <target-name>` (matching Thunar's own native "Make Link" naming convention). If that name is already taken, the script tries `link to <target-name>-1`, `link to <target-name>-2`, and so on until it finds a free name.

This action complements Thunar's own native "Make Link" and "Paste Link" features (right-click → Make Link, or Copy then Paste Link), which only ever create absolute-path symlinks. Use this custom action when you specifically want a relative-path symlink or want to link to a target without first copying it.

If neither `zenity` nor `kdialog` is found, the script automatically installs one (`kdialog` on KDE Plasma, `zenity` on others) using the same package-manager detection as the Thunar install. On Fedora Atomic systems (detected via `rpm-ostree`), this layers the package and requires a reboot; re-run the script after rebooting to add the action. On other package managers, the install happens immediately. If the install fails or no supported package manager is found, this step is skipped gracefully and nothing is touched.

## Supported package managers

`rpm-ostree`, `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `xbps-install`.

## Supported desktop environments (keyboard shortcut)

GNOME, Cinnamon, MATE, XFCE, KDE Plasma (5 and 6, detected via `plasmashell --version`). On other desktop environments, the script still installs Thunar and sets it as the default file manager, but prints manual instructions for binding the shortcut yourself.

On KDE Plasma 5, the shortcut is applied immediately. On KDE Plasma 6, there is no reliable way to reload global shortcuts without a new session, so you'll need to log out and back in (or reboot) before it takes effect.

## chezmoi integration

If [chezmoi](https://www.chezmoi.io/) is installed and already initialized (its source directory is a git repository), the script adds the configuration files it wrote or modified — the KDE shortcut files, the XFCE keyboard-shortcuts XML, Thunar's `uca.xml` (which holds the "Open Terminal Here", "Copy Location Path", "Extract Here", "Extract Here (No Subfolder)", "Compress Here", "Copy File/Folder Name", "Generate Checksum", "Verify Checksum", "Calculate Folder Size", and "Create Link" custom actions), or the terminal-emulator helper files (`~/.local/share/xfce4/helpers/custom-TerminalEmulator.desktop` and `~/.config/xfce4/helpers.rc`) — to your chezmoi source state. This is skipped entirely if chezmoi isn't installed or hasn't been initialized, and it never touches GNOME/Cinnamon/MATE shortcuts since those live in the dconf database rather than a file.

## Contributing

Issues and pull requests are welcome. `install-thunar.sh` is linted with [ShellCheck](https://www.shellcheck.net/) on every push and pull request via GitHub Actions — please run `shellcheck install-thunar.sh` locally before submitting a change.

## License

[MIT](LICENSE)

## Credits

Maintained by [Pat9496](https://github.com/Pat9496).
