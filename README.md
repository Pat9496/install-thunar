# install-thunar

[![ShellCheck](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-informational?logo=linux&logoColor=white)

A shell script that installs [Thunar](https://docs.xfce.org/xfce/thunar/start), sets it as the default file manager, configures a keyboard shortcut to open it, points its "Open Terminal Here" action at your terminal emulator, and adds a "Copy Location" action to copy a file or folder's path to the clipboard — on any Linux distribution and any desktop environment.

## What it does

1. Detects your package manager and installs Thunar if it isn't already present (including Fedora Atomic variants such as Silverblue, Kinoite, and Bazzite via `rpm-ostree`).
2. Sets Thunar as the default handler for directories (`xdg-mime default thunar.desktop inode/directory`).
3. Detects your desktop environment and configures a keyboard shortcut to launch Thunar.
4. Configures Thunar's "Open Terminal Here" action to use a detected (or explicitly chosen) terminal emulator.
5. Adds a "Copy Location" action to Thunar that copies the full path of the selected file or folder to the clipboard.

## Usage

```bash
./install-thunar.sh
```

The script installs packages with `sudo` only when required; the rest runs as your normal user.

After installing Thunar, if the script is running in an interactive terminal it asks whether to set Thunar as the default file manager and configure the keyboard shortcut (`[Y/n]`, defaults to yes). The configuration of the terminal emulator for "Open Terminal Here" and the "Copy Location" custom action always run, regardless of how you answer this prompt. When run non-interactively (e.g. `curl ... | bash`, or with stdin piped/redirected), it skips the prompt and applies the default (yes) to those two steps, while always running the terminal emulator and Copy Location configuration.

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

### Copy Location

The script also adds a "Copy Location" custom action to Thunar's right-click menu, for both files and folders. It copies the full path (including the filename) to the clipboard as plain text, so it can be pasted elsewhere.

To do this, it picks a clipboard tool, in order: `wl-copy` (if a Wayland session is detected via `$WAYLAND_DISPLAY` and `wl-copy` is on `PATH`), then `xclip`, then `xsel`, then `wl-copy` again as a last resort even without a detected Wayland session. If none of `wl-copy`, `xclip`, or `xsel` are found, this step is skipped entirely and nothing is touched — this script does not install a clipboard tool for you, the same way it doesn't install a terminal emulator for you.

## Supported package managers

`rpm-ostree`, `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `xbps-install`.

## Supported desktop environments (keyboard shortcut)

GNOME, Cinnamon, MATE, XFCE, KDE Plasma (5 and 6, detected via `plasmashell --version`). On other desktop environments, the script still installs Thunar and sets it as the default file manager, but prints manual instructions for binding the shortcut yourself.

On KDE Plasma 5, the shortcut is applied immediately. On KDE Plasma 6, there is no reliable way to reload global shortcuts without a new session, so you'll need to log out and back in (or reboot) before it takes effect.

## chezmoi integration

If [chezmoi](https://www.chezmoi.io/) is installed and already initialized (its source directory is a git repository), the script adds the configuration files it wrote or modified — the KDE shortcut files, the XFCE keyboard-shortcuts XML, Thunar's `uca.xml` (which holds both the "Open Terminal Here" and "Copy Location" custom actions), or the terminal-emulator helper files (`~/.local/share/xfce4/helpers/custom-TerminalEmulator.desktop` and `~/.config/xfce4/helpers.rc`) — to your chezmoi source state. This is skipped entirely if chezmoi isn't installed or hasn't been initialized, and it never touches GNOME/Cinnamon/MATE shortcuts since those live in the dconf database rather than a file.

## Contributing

Issues and pull requests are welcome. `install-thunar.sh` is linted with [ShellCheck](https://www.shellcheck.net/) on every push and pull request via GitHub Actions — please run `shellcheck install-thunar.sh` locally before submitting a change.

## License

[MIT](LICENSE)

## Credits

Maintained by [Pat9496](https://github.com/Pat9496).
