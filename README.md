# install-thunar

[![ShellCheck](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Pat9496/install-thunar/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-informational?logo=linux&logoColor=white)

A shell script that installs [Thunar](https://docs.xfce.org/xfce/thunar/start), sets it as the default file manager, and configures a keyboard shortcut to open it — on any Linux distribution and any desktop environment.

## What it does

1. Detects your package manager and installs Thunar if it isn't already present (including Fedora Atomic variants such as Silverblue, Kinoite, and Bazzite via `rpm-ostree`).
2. Sets Thunar as the default handler for directories (`xdg-mime default thunar.desktop inode/directory`).
3. Detects your desktop environment and configures a keyboard shortcut to launch Thunar.

## Usage

```bash
./install-thunar.sh
```

The script installs packages with `sudo` only when required; the rest runs as your normal user.

### Custom shortcut

By default the script binds `Super+E` to open Thunar. Override it with:

```bash
THUNAR_SHORTCUT="<Super>f" ./install-thunar.sh
```

## Supported package managers

`rpm-ostree`, `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `xbps-install`.

## Supported desktop environments (keyboard shortcut)

GNOME, Cinnamon, MATE, XFCE, KDE Plasma. On other desktop environments, the script still installs Thunar and sets it as the default file manager, but prints manual instructions for binding the shortcut yourself.

## Contributing

Issues and pull requests are welcome. `install-thunar.sh` is linted with [ShellCheck](https://www.shellcheck.net/) on every push and pull request via GitHub Actions — please run `shellcheck install-thunar.sh` locally before submitting a change.

## License

[MIT](LICENSE)

## Credits

Maintained by [Pat9496](https://github.com/Pat9496).
