#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[install-thunar] $*"
}

err() {
  echo "[install-thunar] ERROR: $*" >&2
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    if ! command -v sudo >/dev/null 2>&1; then
      err "This step requires root privileges but 'sudo' is not available. Re-run this script as root."
      exit 1
    fi
    sudo "$@"
  fi
}

REBOOT_REQUIRED=0

SHORTCUT="${THUNAR_SHORTCUT:-<Super>e}"
if [[ -z "${SHORTCUT}" ]]; then
  err "THUNAR_SHORTCUT is set but empty."
  exit 1
fi

parse_gsettings_list() {
  local raw="$1"
  raw="${raw#*[}"
  raw="${raw%]*}"
  local -a items=()
  if [[ -n "${raw}" ]]; then
    local part
    local IFS=','
    for part in ${raw}; do
      part="${part//\'/}"
      part="${part// /}"
      [[ -n "${part}" ]] && items+=("${part}")
    done
  fi
  if [[ ${#items[@]} -gt 0 ]]; then
    printf '%s\n' "${items[@]}"
  fi
}

build_gsettings_list() {
  local -a items=("$@")
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  local joined=""
  local p
  for p in "${items[@]}"; do
    if [[ -n "${joined}" ]]; then
      joined+=", "
    fi
    joined+="'${p}'"
  done
  echo "[${joined}]"
}

find_free_path() {
  local base_path="$1"
  shift
  local -a existing=("$@")
  local i=0
  local candidate
  local found
  local p
  while true; do
    candidate="${base_path}custom${i}/"
    found=0
    for p in "${existing[@]}"; do
      if [[ "${p}" == "${candidate}" ]]; then
        found=1
        break
      fi
    done
    if [[ ${found} -eq 0 ]]; then
      echo "${candidate}"
      return
    fi
    i=$((i + 1))
  done
}

find_free_suffix() {
  local -a existing=("$@")
  local i=0
  local candidate
  local found
  local s
  while true; do
    candidate="custom${i}"
    found=0
    for s in "${existing[@]}"; do
      if [[ "${s}" == "${candidate}" ]]; then
        found=1
        break
      fi
    done
    if [[ ${found} -eq 0 ]]; then
      echo "${candidate}"
      return
    fi
    i=$((i + 1))
  done
}

print_manual_instructions() {
  local name="$1"
  local reason="$2"
  log "Skipping automatic keyboard shortcut configuration for ${name}."
  log "Reason: ${reason}"
  log "To finish manually: open your desktop environment's keyboard shortcut settings and bind the command 'thunar' to ${SHORTCUT}."
}

install_thunar() {
  if command -v thunar >/dev/null 2>&1; then
    log "Thunar is already installed."
    return
  fi

  log "Thunar not found. Detecting package manager..."

  if command -v rpm-ostree >/dev/null 2>&1; then
    log "Detected rpm-ostree (Fedora Atomic / Silverblue / Kinoite / Bazzite). Layering thunar package."
    run_as_root rpm-ostree install -y thunar
    log "Thunar has been layered onto the system image."
    log "A REBOOT IS REQUIRED before Thunar will be usable."
    REBOOT_REQUIRED=1
    return
  elif command -v apt-get >/dev/null 2>&1; then
    log "Detected apt-get (Debian/Ubuntu). Installing thunar."
    run_as_root apt-get update
    run_as_root apt-get install -y thunar
  elif command -v dnf >/dev/null 2>&1; then
    log "Detected dnf (Fedora/RHEL/CentOS). Installing thunar."
    run_as_root dnf install -y thunar
  elif command -v yum >/dev/null 2>&1; then
    log "Detected yum (RHEL/CentOS). Installing thunar."
    run_as_root yum install -y thunar
  elif command -v pacman >/dev/null 2>&1; then
    log "Detected pacman (Arch). Installing thunar."
    run_as_root pacman -Syu --noconfirm thunar
  elif command -v zypper >/dev/null 2>&1; then
    log "Detected zypper (openSUSE). Installing thunar."
    run_as_root zypper --non-interactive install thunar
  elif command -v apk >/dev/null 2>&1; then
    log "Detected apk (Alpine). Installing thunar."
    run_as_root apk add thunar
  elif command -v xbps-install >/dev/null 2>&1; then
    log "Detected xbps-install (Void). Installing thunar."
    run_as_root xbps-install -Sy thunar
  else
    err "No supported package manager was found (rpm-ostree, apt-get, dnf, yum, pacman, zypper, apk, xbps-install)."
    err "This distribution is not supported by this script. Please install Thunar manually."
    exit 1
  fi

  if ! command -v thunar >/dev/null 2>&1; then
    err "Thunar installation appears to have failed: 'thunar' is still not on PATH."
    exit 1
  fi

  log "Thunar installed successfully."
}

set_default_file_manager() {
  log "Configuring Thunar as the default file manager..."

  if ! command -v xdg-mime >/dev/null 2>&1; then
    err "'xdg-mime' was not found. Install the 'xdg-utils' package and re-run this script."
    exit 1
  fi

  local -a xdg_dirs=()
  local -a data_dirs=()
  IFS=':' read -ra xdg_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  data_dirs+=("${XDG_DATA_HOME:-${HOME}/.local/share}" "${xdg_dirs[@]}" "/usr/local/share" "/usr/share")

  local desktop_file=""
  local dir
  for dir in "${data_dirs[@]}"; do
    if [[ -f "${dir}/applications/thunar.desktop" ]]; then
      desktop_file="${dir}/applications/thunar.desktop"
      break
    fi
  done

  if [[ -z "${desktop_file}" ]]; then
    err "thunar.desktop was not found in any XDG application directory."
    err "Thunar may not be fully installed. Aborting."
    exit 1
  fi

  log "Found desktop entry: ${desktop_file}"
  xdg-mime default thunar.desktop inode/directory

  local current_default
  current_default=$(xdg-mime query default inode/directory 2>/dev/null || echo "")
  if [[ "${current_default}" == "thunar.desktop" ]]; then
    log "Thunar is now the default file manager for inode/directory."
  else
    err "Failed to verify thunar.desktop as the default handler for inode/directory (got: '${current_default}')."
    exit 1
  fi
}

configure_gnome() {
  if ! command -v gsettings >/dev/null 2>&1; then
    print_manual_instructions "GNOME" "'gsettings' was not found on this system."
    return
  fi

  local schema="org.gnome.settings-daemon.plugins.media-keys"
  local item_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  local base_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

  local raw
  if ! raw=$(gsettings get "${schema}" custom-keybindings 2>/dev/null); then
    print_manual_instructions "GNOME" "Could not read the 'custom-keybindings' setting via gsettings."
    return
  fi

  local -a existing=()
  mapfile -t existing < <(parse_gsettings_list "${raw}")

  local target_path=""
  local p
  local cmd
  for p in "${existing[@]}"; do
    cmd=$(gsettings get "${item_schema}:${p}" command 2>/dev/null || echo "")
    if [[ "${cmd}" == "'thunar'" ]]; then
      target_path="${p}"
      break
    fi
  done

  if [[ -z "${target_path}" ]]; then
    target_path=$(find_free_path "${base_path}" "${existing[@]}")
    existing+=("${target_path}")
    gsettings set "${schema}" custom-keybindings "$(build_gsettings_list "${existing[@]}")"
    log "Added new GNOME custom keybinding entry at ${target_path}."
  else
    log "Existing GNOME Thunar keybinding found at ${target_path}. Updating it."
  fi

  gsettings set "${item_schema}:${target_path}" name "Thunar"
  gsettings set "${item_schema}:${target_path}" command "thunar"
  gsettings set "${item_schema}:${target_path}" binding "${SHORTCUT}"
  log "GNOME shortcut configured: ${SHORTCUT} -> thunar"
}

configure_cinnamon() {
  if ! command -v gsettings >/dev/null 2>&1; then
    print_manual_instructions "Cinnamon" "'gsettings' was not found on this system."
    return
  fi

  local schema="org.cinnamon.desktop.keybindings"
  local item_schema="org.cinnamon.desktop.keybindings.custom-keybinding"
  local base_path="/org/cinnamon/desktop/keybindings/custom-keybindings/"

  local raw
  if ! raw=$(gsettings get "${schema}" custom-list 2>/dev/null); then
    print_manual_instructions "Cinnamon" "Could not read the 'custom-list' setting via gsettings."
    return
  fi

  local -a existing=()
  mapfile -t existing < <(parse_gsettings_list "${raw}")

  local target_suffix=""
  local s
  local cmd
  for s in "${existing[@]}"; do
    cmd=$(gsettings get "${item_schema}:${base_path}${s}/" command 2>/dev/null || echo "")
    if [[ "${cmd}" == "'thunar'" ]]; then
      target_suffix="${s}"
      break
    fi
  done

  if [[ -z "${target_suffix}" ]]; then
    target_suffix=$(find_free_suffix "${existing[@]}")
    existing+=("${target_suffix}")
    gsettings set "${schema}" custom-list "$(build_gsettings_list "${existing[@]}")"
    log "Added new Cinnamon custom keybinding entry ${target_suffix}."
  else
    log "Existing Cinnamon Thunar keybinding found at ${target_suffix}. Updating it."
  fi

  local target_path="${base_path}${target_suffix}/"
  gsettings set "${item_schema}:${target_path}" name "Thunar"
  gsettings set "${item_schema}:${target_path}" command "thunar"
  gsettings set "${item_schema}:${target_path}" binding "['${SHORTCUT}']"
  log "Cinnamon shortcut configured: ${SHORTCUT} -> thunar"
}

configure_mate() {
  if ! command -v gsettings >/dev/null 2>&1; then
    print_manual_instructions "MATE" "'gsettings' was not found on this system."
    return
  fi

  local schema="org.mate.SettingsDaemon.plugins.media-keys"
  local item_schema="org.mate.SettingsDaemon.plugins.media-keys.custom-keybinding"
  local base_path="/org/mate/desktop/keybindings/"

  local raw
  if ! raw=$(gsettings get "${schema}" custom-keybindings 2>/dev/null); then
    print_manual_instructions "MATE" "Could not read the 'custom-keybindings' setting via gsettings."
    return
  fi

  local -a existing=()
  mapfile -t existing < <(parse_gsettings_list "${raw}")

  local target_path=""
  local p
  local act
  for p in "${existing[@]}"; do
    act=$(gsettings get "${item_schema}:${p}" action 2>/dev/null || echo "")
    if [[ "${act}" == "'thunar'" ]]; then
      target_path="${p}"
      break
    fi
  done

  if [[ -z "${target_path}" ]]; then
    target_path=$(find_free_path "${base_path}" "${existing[@]}")
    existing+=("${target_path}")
    gsettings set "${schema}" custom-keybindings "$(build_gsettings_list "${existing[@]}")"
    log "Added new MATE custom keybinding entry at ${target_path}."
  else
    log "Existing MATE Thunar keybinding found at ${target_path}. Updating it."
  fi

  gsettings set "${item_schema}:${target_path}" name "Thunar"
  gsettings set "${item_schema}:${target_path}" action "thunar"
  gsettings set "${item_schema}:${target_path}" binding "${SHORTCUT}"
  log "MATE shortcut configured: ${SHORTCUT} -> thunar"
}

configure_xfce() {
  if ! command -v xfconf-query >/dev/null 2>&1; then
    print_manual_instructions "XFCE" "'xfconf-query' was not found on this system."
    return
  fi

  local channel="xfce4-keyboard-shortcuts"
  local property="/commands/custom/${SHORTCUT}"

  if xfconf-query -c "${channel}" -p "${property}" >/dev/null 2>&1; then
    xfconf-query -c "${channel}" -p "${property}" -s "thunar"
    log "Updated existing XFCE shortcut property ${property}."
  else
    xfconf-query -c "${channel}" -p "${property}" -n -t string -s "thunar"
    log "Created new XFCE shortcut property ${property}."
  fi

  log "XFCE shortcut configured: ${SHORTCUT} -> thunar"
}

configure_shortcut() {
  log "Configuring keyboard shortcut for Thunar..."

  local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  if [[ -z "${de}" ]]; then
    log "Could not detect a desktop environment (XDG_CURRENT_DESKTOP and DESKTOP_SESSION are both unset)."
    log "To finish manually: open your desktop environment's keyboard shortcut settings and bind the command 'thunar' to ${SHORTCUT}."
    return
  fi

  local de_lower="${de,,}"

  if [[ "${de_lower}" == *budgie* ]]; then
    print_manual_instructions "Budgie" "Budgie does not use a GNOME-compatible custom keybinding mechanism for this purpose."
  elif [[ "${de_lower}" == *cinnamon* ]]; then
    configure_cinnamon
  elif [[ "${de_lower}" == *mate* ]]; then
    configure_mate
  elif [[ "${de_lower}" == *xfce* ]]; then
    configure_xfce
  elif [[ "${de_lower}" == *kde* || "${de_lower}" == *plasma* ]]; then
    print_manual_instructions "KDE Plasma" "KDE Plasma's global shortcut configuration format is not consistent enough across Plasma 5 and 6 to be safely automated here."
  elif [[ "${de_lower}" == *gnome* ]]; then
    configure_gnome
  else
    print_manual_instructions "${de}" "This desktop environment is not recognized by this script."
  fi
}

main() {
  log "Starting Thunar installation and configuration."

  install_thunar

  if [[ "${REBOOT_REQUIRED}" -eq 1 ]]; then
    log "Reboot before continuing: Thunar was layered via rpm-ostree and is not usable yet."
    log "After rebooting, re-run this script to finish setting the default file manager and keyboard shortcut."
    exit 0
  fi

  set_default_file_manager
  configure_shortcut

  log "Done."
}

main "$@"
