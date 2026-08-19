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

detect_plasma_major_version() {
  if ! command -v plasmashell >/dev/null 2>&1; then
    return
  fi
  local version_output
  version_output=$(plasmashell --version 2>/dev/null || echo "")
  printf '%s\n' "${version_output}" | grep -oE '[0-9]+' | head -n1 || true
}

convert_shortcut_to_kde() {
  local rest="$1"
  local mods=""
  local mod
  while [[ "${rest}" =~ ^\<([A-Za-z0-9]+)\>(.*)$ ]]; do
    mod="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    case "${mod,,}" in
      super | mod4) mods+="Meta+" ;;
      control | ctrl | primary) mods+="Ctrl+" ;;
      alt) mods+="Alt+" ;;
      shift) mods+="Shift+" ;;
      *) mods+="${mod}+" ;;
    esac
  done

  local key="${rest}"
  local key_lower="${key,,}"
  case "${key_lower}" in
    f1 | f2 | f3 | f4 | f5 | f6 | f7 | f8 | f9 | f10 | f11 | f12) key="${key^^}" ;;
    tab) key="Tab" ;;
    space) key="Space" ;;
    return | enter) key="Return" ;;
    escape | esc) key="Escape" ;;
    home) key="Home" ;;
    end) key="End" ;;
    insert) key="Insert" ;;
    delete) key="Delete" ;;
    up) key="Up" ;;
    down) key="Down" ;;
    left) key="Left" ;;
    right) key="Right" ;;
    page_up | prior) key="PgUp" ;;
    page_down | next) key="PgDown" ;;
    *)
      if [[ "${#key}" -eq 1 ]]; then
        key="${key^^}"
      fi
      ;;
  esac

  echo "${mods}${key}"
}

chezmoi_track() {
  local file="$1"
  if ! command -v chezmoi >/dev/null 2>&1; then
    return
  fi
  if [[ ! -f "${file}" ]]; then
    return
  fi
  local source_path
  source_path=$(chezmoi source-path 2>/dev/null || echo "")
  if [[ -z "${source_path}" || ! -d "${source_path}/.git" ]]; then
    return
  fi
  if chezmoi add "${file}" >/dev/null 2>&1; then
    log "Tracked ${file} in chezmoi."
  else
    log "Could not add ${file} to chezmoi."
  fi
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

  chezmoi_track "${XDG_CONFIG_HOME:-${HOME}/.config}/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"
}

configure_kde() {
  local major="$1"
  local kwriteconfig="kwriteconfig${major}"
  local kreadconfig="kreadconfig${major}"

  if ! command -v "${kwriteconfig}" >/dev/null 2>&1 || ! command -v "${kreadconfig}" >/dev/null 2>&1; then
    print_manual_instructions "KDE Plasma ${major}" "'${kwriteconfig}' was not found on this system."
    return
  fi

  local data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
  local apps_dir="${data_home}/applications"
  local desktop_name="install-thunar-shortcut.desktop"
  local desktop_file="${apps_dir}/${desktop_name}"
  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local shortcuts_file="${config_home}/kglobalshortcutsrc"
  local accel_file="${config_home}/kglobalaccelrc"

  mkdir -p "${apps_dir}"
  cat > "${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=Thunar
NoDisplay=true
StartupNotify=false
Exec=thunar
X-KDE-GlobalAccel-CommandShortcut=true
EOF

  local kde_shortcut
  kde_shortcut=$(convert_shortcut_to_kde "${SHORTCUT}")

  "${kwriteconfig}" --file "${shortcuts_file}" --group "${desktop_name}" --key "_k_friendly_name" "Thunar"
  "${kwriteconfig}" --file "${shortcuts_file}" --group "${desktop_name}" --key "_launch" "${kde_shortcut},none,Thunar"

  local accel_file_modified=0
  if [[ -f "${accel_file}" ]]; then
    local allow_list
    allow_list=$("${kreadconfig}" --file "${accel_file}" --group "General" --key "useAllowList" 2>/dev/null || echo "")
    if [[ "${allow_list,,}" == "true" ]]; then
      local existing_allowed
      existing_allowed=$("${kreadconfig}" --file "${accel_file}" --group "AllowedShortcuts" --key "${desktop_name}" 2>/dev/null || echo "")
      if [[ "${existing_allowed}" != *"_launch"* ]]; then
        local new_allowed="_launch"
        [[ -n "${existing_allowed}" ]] && new_allowed="${existing_allowed},_launch"
        "${kwriteconfig}" --file "${accel_file}" --group "AllowedShortcuts" --key "${desktop_name}" "${new_allowed}"
        log "Added Thunar shortcut to the KDE global shortcuts allow list."
        accel_file_modified=1
      fi
    fi
  fi

  log "KDE Plasma ${major} shortcut configured: ${SHORTCUT} (${kde_shortcut}) -> thunar"

  if [[ "${major}" == "5" ]]; then
    if command -v kglobalaccel5 >/dev/null 2>&1 && command -v pkill >/dev/null 2>&1; then
      pkill -x kglobalaccel5 >/dev/null 2>&1 || true
      sleep 1
      kglobalaccel5 >/dev/null 2>&1 &
      disown
      log "Restarted kglobalaccel5 to apply the new shortcut."
    else
      log "Could not automatically restart kglobalaccel5 (missing 'kglobalaccel5' or 'pkill')."
      log "Log out and back in for the ${SHORTCUT} shortcut to take effect."
    fi
  else
    log "Plasma 6 has no reliable way to reload global shortcuts without a new session."
    log "Log out and back in (or reboot) for the ${SHORTCUT} shortcut to take effect."
  fi

  chezmoi_track "${desktop_file}"
  chezmoi_track "${shortcuts_file}"
  if [[ "${accel_file_modified}" -eq 1 ]]; then
    chezmoi_track "${accel_file}"
  fi
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
    local plasma_major
    plasma_major=$(detect_plasma_major_version)
    if [[ "${plasma_major}" == "5" || "${plasma_major}" == "6" ]]; then
      configure_kde "${plasma_major}"
    else
      print_manual_instructions "KDE Plasma" "Could not detect the Plasma major version ('plasmashell --version' did not return a usable result)."
    fi
  elif [[ "${de_lower}" == *gnome* ]]; then
    configure_gnome
  else
    print_manual_instructions "${de}" "This desktop environment is not recognized by this script."
  fi
}

confirm_configure_extras() {
  if [[ ! -t 0 ]]; then
    return 0
  fi

  local reply
  read -r -p "[install-thunar] Set Thunar as the default file manager and configure a keyboard shortcut to open it? [Y/n] " reply
  case "${reply,,}" in
    n | no) return 1 ;;
    *) return 0 ;;
  esac
}

detect_terminal_emulator() {
  if [[ -n "${THUNAR_TERMINAL:-}" ]]; then
    echo "${THUNAR_TERMINAL}"
    return
  fi

  if [[ -n "${TERMINAL:-}" ]] && command -v "${TERMINAL}" >/dev/null 2>&1; then
    echo "${TERMINAL}"
    return
  fi

  if command -v x-terminal-emulator >/dev/null 2>&1; then
    echo "x-terminal-emulator"
    return
  fi

  local -a candidates=(alacritty kitty wezterm foot konsole gnome-terminal xfce4-terminal terminator tilix urxvt xterm)
  local c
  for c in "${candidates[@]}"; do
    if command -v "${c}" >/dev/null 2>&1; then
      echo "${c}"
      return
    fi
  done
}

detect_clipboard_tool() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    echo "wl-copy"
    return
  fi

  if command -v xclip >/dev/null 2>&1; then
    echo "xclip"
    return
  fi

  if command -v xsel >/dev/null 2>&1; then
    echo "xsel"
    return
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    echo "wl-copy"
    return
  fi
}

detect_archive_tools() {
  local -a tools=(tar unzip 7z 7za 7zr unrar)
  local t
  for t in "${tools[@]}"; do
    if command -v "${t}" >/dev/null 2>&1; then
      echo "found"
      return
    fi
  done
}

escape_xml() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  echo "${s}"
}

build_terminal_command() {
  local terminal="$1"
  case "${terminal}" in
    alacritty | foot) echo "${terminal} --working-directory %f" ;;
    kitty) echo "${terminal} --directory %f" ;;
    wezterm) echo "${terminal} start --cwd %f" ;;
    konsole) echo "${terminal} --workdir %f" ;;
    gnome-terminal | xfce4-terminal | terminator | tilix) echo "${terminal} --working-directory=%f" ;;
    urxvt) echo "${terminal} -cd %f" ;;
    *) echo "" ;;
  esac
}

build_clipboard_command() {
  local tool="$1"
  case "${tool}" in
    xclip) echo "xclip -selection clipboard -in" ;;
    xsel) echo "xsel --clipboard --input" ;;
    wl-copy) echo "wl-copy" ;;
    *) echo "" ;;
  esac
}

configure_uca_terminal() {
  local terminal="$1"
  local command="$2"

  if [[ -z "${command}" ]]; then
    log "Don't know the working-directory flag for '${terminal}'; leaving Thunar's 'Open Terminal Here' action untouched."
    return
  fi

  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local uca_dir="${config_home}/Thunar"
  local uca_file="${uca_dir}/uca.xml"
  local escaped_command
  escaped_command=$(escape_xml "${command}")

  mkdir -p "${uca_dir}"

  local action_xml
  action_xml=$(cat <<EOF
<action>
	<icon>utilities-terminal</icon>
	<name>Open Terminal Here</name>
	<submenu></submenu>
	<unique-id>$(date +%s%N)-1</unique-id>
	<command>${escaped_command}</command>
	<description>Open a terminal in the current directory</description>
	<range></range>
	<patterns>*</patterns>
	<startup-notify/>
	<directories/>
</action>
EOF
  )

  if [[ ! -f "${uca_file}" ]]; then
    cat > "${uca_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
${action_xml}
</actions>
EOF
    log "Created ${uca_file} with an 'Open Terminal Here' action using: ${command}"
    chezmoi_track "${uca_file}"
    return
  fi

  local tmpfile
  tmpfile=$(mktemp)
  if awk -v newcmd="${escaped_command}" '
      /<action>/ { in_action = 1 }
      in_action && /<name>Open Terminal Here<\/name>/ { found_name = 1 }
      in_action && found_name && /<command>/ && !replaced {
        sub(/<command>.*<\/command>/, "<command>" newcmd "</command>")
        replaced = 1
      }
      { print }
      /<\/action>/ { in_action = 0; found_name = 0 }
      END { if (replaced) exit 0; else exit 1 }
    ' "${uca_file}" > "${tmpfile}"; then
    mv "${tmpfile}" "${uca_file}"
    log "Updated Thunar's existing 'Open Terminal Here' action to use: ${command}"
    chezmoi_track "${uca_file}"
    return
  fi

  rm -f "${tmpfile}"
  if grep -q '</actions>' "${uca_file}"; then
    local tmpfile2
    tmpfile2=$(mktemp)
    awk -v action="${action_xml}" '/<\/actions>/ { print action } { print }' "${uca_file}" > "${tmpfile2}"
    mv "${tmpfile2}" "${uca_file}"
    log "Added a new 'Open Terminal Here' action to Thunar using: ${command}"
    chezmoi_track "${uca_file}"
  else
    log "${uca_file} exists but has no '</actions>' closing tag; leaving it untouched."
  fi
}

configure_uca_copy_location() {
  local tool="$1"
  local command="$2"

  if [[ -z "${command}" ]]; then
    log "No clipboard tool found (install xclip, xsel, or wl-clipboard); leaving Thunar's 'Copy Location' action untouched."
    return
  fi

  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local uca_dir="${config_home}/Thunar"
  local uca_file="${uca_dir}/uca.xml"
  local escaped_command
  escaped_command=$(escape_xml "${command}")

  mkdir -p "${uca_dir}"

  local action_xml
  action_xml=$(cat <<EOF
<action>
	<icon>edit-copy</icon>
	<name>Copy Location</name>
	<submenu></submenu>
	<unique-id>$(date +%s%N)-2</unique-id>
	<command>${escaped_command}</command>
	<description>Copy the full path to the clipboard as plain text</description>
	<range></range>
	<patterns>*</patterns>
	<directories/>
	<audio-files/>
	<image-files/>
	<other-files/>
	<text-files/>
	<video-files/>
</action>
EOF
  )

  if [[ ! -f "${uca_file}" ]]; then
    cat > "${uca_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
${action_xml}
</actions>
EOF
    log "Created ${uca_file} with a 'Copy Location' action using: ${tool}"
    chezmoi_track "${uca_file}"
    return
  fi

  local tmpfile
  tmpfile=$(mktemp)
  if awk -v newcmd="${escaped_command}" '
      /<action>/ { in_action = 1; found_name = 0; has_filetypes = 0; indent = "\t" }
      in_action && /<name>Copy Location<\/name>/ { found_name = 1 }
      in_action && found_name && /<command>/ && !replaced {
        sub(/<command>.*<\/command>/, "<command>" newcmd "</command>")
        replaced = 1
      }
      in_action && found_name && /<directories\/>/ {
        indent = $0
        sub(/<directories\/>.*/, "", indent)
      }
      in_action && found_name && /<(audio-files|image-files|other-files|text-files|video-files)\/>/ {
        has_filetypes = 1
      }
      in_action && found_name && /<\/action>/ && !has_filetypes {
        print indent "<audio-files/>"
        print indent "<image-files/>"
        print indent "<other-files/>"
        print indent "<text-files/>"
        print indent "<video-files/>"
      }
      { print }
      /<\/action>/ { in_action = 0; found_name = 0 }
      END { if (replaced) exit 0; else exit 1 }
    ' "${uca_file}" > "${tmpfile}"; then
    mv "${tmpfile}" "${uca_file}"
    log "Updated Thunar's existing 'Copy Location' action to use: ${tool}"
    chezmoi_track "${uca_file}"
    return
  fi

  rm -f "${tmpfile}"
  if grep -q '</actions>' "${uca_file}"; then
    local tmpfile2
    tmpfile2=$(mktemp)
    awk -v action="${action_xml}" '/<\/actions>/ { print action } { print }' "${uca_file}" > "${tmpfile2}"
    mv "${tmpfile2}" "${uca_file}"
    log "Added a new 'Copy Location' action to Thunar using: ${tool}"
    chezmoi_track "${uca_file}"
  else
    log "${uca_file} exists but has no '</actions>' closing tag; leaving it untouched."
  fi
}

configure_uca_extract_here() {
  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local uca_dir="${config_home}/Thunar"
  local uca_file="${uca_dir}/uca.xml"

  local script
  script='f="$1"; dir=$(dirname "$f"); base=$(basename "$f"); cd "$dir" || exit 1; case "$base" in *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst) name="${base%.*}"; name="${name%.*}"; command -v tar >/dev/null 2>&1 || exit 1; mkdir -p "$name" && tar -xf "$base" -C "$name" ;; *.tar) name="${base%.tar}"; command -v tar >/dev/null 2>&1 || exit 1; mkdir -p "$name" && tar -xf "$base" -C "$name" ;; *.zip) name="${base%.zip}"; command -v unzip >/dev/null 2>&1 || exit 1; mkdir -p "$name" && unzip -o "$base" -d "$name" ;; *.7z) name="${base%.7z}"; sevenzip=""; for c in 7z 7za 7zr; do if command -v "$c" >/dev/null 2>&1; then sevenzip="$c"; break; fi; done; [ -n "$sevenzip" ] || exit 1; mkdir -p "$name" && "$sevenzip" x "$base" -o"$name" -y ;; *.rar) name="${base%.rar}"; command -v unrar >/dev/null 2>&1 || exit 1; mkdir -p "$name" && unrar x -y "$base" "$name/" ;; *) exit 1 ;; esac'
  local command="bash -c '${script}' -- %f"
  local escaped_command
  escaped_command=$(escape_xml "${command}")

  mkdir -p "${uca_dir}"

  local action_xml
  action_xml=$(cat <<EOF
<action>
	<icon>archive-extract</icon>
	<name>Extract Here</name>
	<submenu></submenu>
	<unique-id>$(date +%s%N)-3</unique-id>
	<command>${escaped_command}</command>
	<description>Extract the archive into a new folder named after it</description>
	<range></range>
	<patterns>*.zip;*.tar;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.tar.zst;*.7z;*.rar</patterns>
	<audio-files/>
	<image-files/>
	<other-files/>
	<text-files/>
	<video-files/>
</action>
EOF
  )

  if [[ ! -f "${uca_file}" ]]; then
    cat > "${uca_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
${action_xml}
</actions>
EOF
    log "Created ${uca_file} with an 'Extract Here' action."
    chezmoi_track "${uca_file}"
    return
  fi

  local tmpfile
  tmpfile=$(mktemp)
  if awk -v newcmd="${escaped_command}" '
      /<action>/ { in_action = 1 }
      in_action && /<name>Extract Here<\/name>/ { found_name = 1 }
      in_action && found_name && /<command>/ && !replaced {
        sub(/<command>.*<\/command>/, "<command>" newcmd "</command>")
        replaced = 1
      }
      { print }
      /<\/action>/ { in_action = 0; found_name = 0 }
      END { if (replaced) exit 0; else exit 1 }
    ' "${uca_file}" > "${tmpfile}"; then
    mv "${tmpfile}" "${uca_file}"
    log "Updated Thunar's existing 'Extract Here' action."
    chezmoi_track "${uca_file}"
    return
  fi

  rm -f "${tmpfile}"
  if grep -q '</actions>' "${uca_file}"; then
    local tmpfile2
    tmpfile2=$(mktemp)
    awk -v action="${action_xml}" '/<\/actions>/ { print action } { print }' "${uca_file}" > "${tmpfile2}"
    mv "${tmpfile2}" "${uca_file}"
    log "Added a new 'Extract Here' action to Thunar."
    chezmoi_track "${uca_file}"
  else
    log "${uca_file} exists but has no '</actions>' closing tag; leaving it untouched."
  fi
}

configure_uca_extract_flatten() {
  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local uca_dir="${config_home}/Thunar"
  local uca_file="${uca_dir}/uca.xml"

  local script
  script='f="$1"; dir=$(dirname "$f"); base=$(basename "$f"); cd "$dir" || exit 1; case "$base" in *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst|*.tar) command -v tar >/dev/null 2>&1 || exit 1; tar -xf "$base" ;; *.zip) command -v unzip >/dev/null 2>&1 || exit 1; unzip -o "$base" ;; *.7z) sevenzip=""; for c in 7z 7za 7zr; do if command -v "$c" >/dev/null 2>&1; then sevenzip="$c"; break; fi; done; [ -n "$sevenzip" ] || exit 1; "$sevenzip" x "$base" -y ;; *.rar) command -v unrar >/dev/null 2>&1 || exit 1; unrar x -y "$base" ;; *) exit 1 ;; esac'
  local command="bash -c '${script}' -- %f"
  local escaped_command
  escaped_command=$(escape_xml "${command}")

  mkdir -p "${uca_dir}"

  local action_xml
  action_xml=$(cat <<EOF
<action>
	<icon>archive-extract</icon>
	<name>Extract Here (No Subfolder)</name>
	<submenu></submenu>
	<unique-id>$(date +%s%N)-4</unique-id>
	<command>${escaped_command}</command>
	<description>Extract the archive directly into the current directory</description>
	<range></range>
	<patterns>*.zip;*.tar;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.tar.zst;*.7z;*.rar</patterns>
	<audio-files/>
	<image-files/>
	<other-files/>
	<text-files/>
	<video-files/>
</action>
EOF
  )

  if [[ ! -f "${uca_file}" ]]; then
    cat > "${uca_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
${action_xml}
</actions>
EOF
    log "Created ${uca_file} with an 'Extract Here (No Subfolder)' action."
    chezmoi_track "${uca_file}"
    return
  fi

  local tmpfile
  tmpfile=$(mktemp)
  if awk -v newcmd="${escaped_command}" '
      /<action>/ { in_action = 1 }
      in_action && /<name>Extract Here \(No Subfolder\)<\/name>/ { found_name = 1 }
      in_action && found_name && /<command>/ && !replaced {
        sub(/<command>.*<\/command>/, "<command>" newcmd "</command>")
        replaced = 1
      }
      { print }
      /<\/action>/ { in_action = 0; found_name = 0 }
      END { if (replaced) exit 0; else exit 1 }
    ' "${uca_file}" > "${tmpfile}"; then
    mv "${tmpfile}" "${uca_file}"
    log "Updated Thunar's existing 'Extract Here (No Subfolder)' action."
    chezmoi_track "${uca_file}"
    return
  fi

  rm -f "${tmpfile}"
  if grep -q '</actions>' "${uca_file}"; then
    local tmpfile2
    tmpfile2=$(mktemp)
    awk -v action="${action_xml}" '/<\/actions>/ { print action } { print }' "${uca_file}" > "${tmpfile2}"
    mv "${tmpfile2}" "${uca_file}"
    log "Added a new 'Extract Here (No Subfolder)' action to Thunar."
    chezmoi_track "${uca_file}"
  else
    log "${uca_file} exists but has no '</actions>' closing tag; leaving it untouched."
  fi
}

configure_terminal() {
  local terminal
  terminal=$(detect_terminal_emulator)

  if [[ -z "${terminal}" ]]; then
    log "Could not detect a terminal emulator (set THUNAR_TERMINAL to override)."
    log "Skipping 'Open Terminal Here' configuration."
    return
  fi

  if ! command -v "${terminal}" >/dev/null 2>&1; then
    log "Terminal emulator '${terminal}' (from THUNAR_TERMINAL) is not on PATH."
    log "Skipping 'Open Terminal Here' configuration."
    return
  fi

  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
  local helpers_dir="${data_home}/xfce4/helpers"
  local helper_id="custom-TerminalEmulator"
  local helper_file="${helpers_dir}/${helper_id}.desktop"
  local helpers_rc="${config_home}/xfce4/helpers.rc"

  mkdir -p "${helpers_dir}"
  cat > "${helper_file}" <<EOF
[Desktop Entry]
NoDisplay=true
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Category=TerminalEmulator
X-XFCE-Commands=${terminal}
X-XFCE-CommandsWithParameter=${terminal} -e %s
Icon=utilities-terminal
Name=${terminal}
EOF

  mkdir -p "${config_home}/xfce4"
  touch "${helpers_rc}"
  if grep -q '^TerminalEmulator=' "${helpers_rc}"; then
    sed -i "s|^TerminalEmulator=.*|TerminalEmulator=${helper_id}|" "${helpers_rc}"
  else
    printf 'TerminalEmulator=%s\n' "${helper_id}" >> "${helpers_rc}"
  fi
  if grep -q '^TerminalEmulatorDismissed=' "${helpers_rc}"; then
    sed -i "s|^TerminalEmulatorDismissed=.*|TerminalEmulatorDismissed=true|" "${helpers_rc}"
  else
    printf 'TerminalEmulatorDismissed=true\n' >> "${helpers_rc}"
  fi

  log "exo preferred TerminalEmulator set to: ${terminal} (best-effort; not all exo builds resolve custom helpers reliably)"

  chezmoi_track "${helper_file}"
  chezmoi_track "${helpers_rc}"

  local terminal_command
  terminal_command=$(build_terminal_command "${terminal}")
  configure_uca_terminal "${terminal}" "${terminal_command}"
}

configure_copy_location() {
  local tool
  tool=$(detect_clipboard_tool)

  if [[ -z "${tool}" ]]; then
    log "No clipboard tool found (install xclip, xsel, or wl-clipboard)."
    log "Skipping 'Copy Location' configuration."
    return
  fi

  local clipboard_tail
  clipboard_tail=$(build_clipboard_command "${tool}")

  local copy_command
  copy_command="bash -c 'printf %s \"\$1\" | ${clipboard_tail}' -- %f"

  configure_uca_copy_location "${tool}" "${copy_command}"
}

configure_extract_actions() {
  local found
  found=$(detect_archive_tools)

  if [[ -z "${found}" ]]; then
    log "No archive extraction tool found (install tar, unzip, 7z, or unrar)."
    log "Skipping 'Extract Here' actions."
    return
  fi

  configure_uca_extract_here
  configure_uca_extract_flatten
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs Thunar, sets it as the default file manager, configures a
keyboard shortcut to open it, points its "Open Terminal Here"
action at a terminal emulator, adds a "Copy Location" action
that copies a file or directory's full path to the clipboard, and
adds "Extract Here" and "Extract Here (No Subfolder)" actions for
extracting archives.

Options:
  --terminal <name>   Explicitly select the terminal emulator to use for
                       Thunar's "Open Terminal Here" action (e.g. alacritty,
                       kitty, konsole). Takes precedence over THUNAR_TERMINAL.
  -h, --help           Show this help message and exit.

Environment variables:
  THUNAR_SHORTCUT   Keyboard shortcut to bind to Thunar (default: <Super>e).
  THUNAR_TERMINAL   Terminal emulator to use for "Open Terminal Here".
                     Overridden by --terminal if both are given.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --terminal)
        if [[ $# -lt 2 ]]; then
          err "--terminal requires an argument."
          exit 1
        fi
        THUNAR_TERMINAL="$2"
        shift 2
        ;;
      --terminal=*)
        THUNAR_TERMINAL="${1#--terminal=}"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  log "Starting Thunar installation and configuration."

  install_thunar

  if [[ "${REBOOT_REQUIRED}" -eq 1 ]]; then
    log "Reboot before continuing: Thunar was layered via rpm-ostree and is not usable yet."
    log "After rebooting, re-run this script to finish setting the default file manager and keyboard shortcut."
    exit 0
  fi

  if confirm_configure_extras; then
    set_default_file_manager
    configure_shortcut
  else
    log "Skipping default file manager and keyboard shortcut configuration at your request."
  fi

  configure_terminal
  configure_copy_location
  configure_extract_actions

  log "Done."
}

main "$@"
