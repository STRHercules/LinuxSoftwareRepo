#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# Fresh Linux bootstrap (Debian/Ubuntu/Pop!_OS best supported)
# Always:
# - install core packages + your tool list
# - install Starship, NVM, and Node.js (LTS) via NVM
# - configure ~/.zshrc (managed block appended at end, idempotent)
# - set Zsh as default shell
# - install Flatpaks + Flatseal
# ------------------------------------------------------------

# ---------- UI (pretty, TTY-aware) ----------
UI_COLOR=0
UI_UNICODE=0
UI_PROGRESS=1
UI_BANNER=1

if [[ -t 1 && "${NO_COLOR:-}" == "" && "${TERM:-}" != "dumb" ]]; then
  UI_COLOR=1
fi
if [[ "${NO_PROGRESS:-}" != "" || ! -t 1 ]]; then
  UI_PROGRESS=0
fi
if [[ "${NO_BANNER:-}" != "" || ! -t 1 || "${TERM:-}" == "dumb" ]]; then
  UI_BANNER=0
fi

_locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
if [[ "$_locale" == *"UTF-8"* || "$_locale" == *"utf8"* ]]; then
  UI_UNICODE=1
fi

if ((UI_COLOR)); then
  c_reset=$'\033[0m'
  c_bold=$'\033[1m'
  c_dim=$'\033[2m'
  c_blue=$'\033[38;5;75m'
  c_green=$'\033[38;5;78m'
  c_yellow=$'\033[38;5;222m'
  c_red=$'\033[38;5;203m'
  c_gray=$'\033[38;5;245m'
else
  c_reset=""
  c_bold=""
  c_dim=""
  c_blue=""
  c_green=""
  c_yellow=""
  c_red=""
  c_gray=""
fi

if ((UI_UNICODE)); then
  i_info="ℹ"
  i_ok="✔"
  i_warn="⚠"
  i_err="✖"
  i_step="▸"
  i_dot="•"
  i_sub="↳"
else
  i_info="i"
  i_ok="OK"
  i_warn="!!"
  i_err="xx"
  i_step=">"
  i_dot="-"
  i_sub="->"
fi

PROGRESS_ACTIVE=0
PROGRESS_TOTAL=0
PROGRESS_CURRENT=0
PROGRESS_LABEL=""

cleanup_cmds=()
add_cleanup() { cleanup_cmds+=("$1"); }
on_exit() {
  local cmd
  for cmd in "${cleanup_cmds[@]}"; do
    eval "$cmd" >/dev/null 2>&1 || true
  done
}
trap on_exit EXIT

repeat_char() {
  local count="$1"
  local ch="$2"
  ((count <= 0)) && return 0
  local spaces
  printf -v spaces '%*s' "$count" ''
  printf '%s' "${spaces// /$ch}"
}

progress_clear_line() {
  ((UI_PROGRESS)) || return 0
  ((PROGRESS_ACTIVE)) || return 0
  printf '\r\033[2K'
}

progress_render() {
  ((UI_PROGRESS)) || return 0
  ((PROGRESS_ACTIVE)) || return 0

  local cols width pct filled empty bar_fill bar_empty
  cols=80
  if have tput; then cols="$(tput cols 2>/dev/null || echo 80)"; fi
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

  # Leave room for " 100% (NN/NN) " + label.
  width=$((cols - 26))
  ((width < 18)) && width=18
  ((width > 48)) && width=48

  pct=$(( PROGRESS_TOTAL > 0 ? (PROGRESS_CURRENT * 100 / PROGRESS_TOTAL) : 0 ))
  filled=$(( PROGRESS_TOTAL > 0 ? (PROGRESS_CURRENT * width / PROGRESS_TOTAL) : 0 ))
  empty=$((width - filled))

  if ((UI_UNICODE)); then
    bar_fill="█"
    bar_empty="░"
  else
    bar_fill="#"
    bar_empty="-"
  fi

  local bar=""
  if ((filled > 0)); then bar+="$(repeat_char "$filled" "$bar_fill")"; fi
  if ((empty > 0)); then bar+="$(repeat_char "$empty" "$bar_empty")"; fi

  local prefix=""
  local suffix=""
  if ((UI_COLOR)); then
    prefix="${c_dim}"
    suffix="${c_reset}"
  fi

  printf '\r%s[%s]%s %3d%% (%d/%d) %s' \
    "$prefix" "$bar" "$suffix" "$pct" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "${PROGRESS_LABEL}"
}

progress_init() {
  ((UI_PROGRESS)) || return 0
  PROGRESS_TOTAL="${1:-0}"
  PROGRESS_CURRENT=0
  PROGRESS_LABEL="${2:-Starting…}"
  PROGRESS_ACTIVE=1
  progress_render
}

progress_advance() {
  ((UI_PROGRESS)) || return 0
  ((PROGRESS_ACTIVE)) || return 0
  PROGRESS_LABEL="${1:-}"
  ((PROGRESS_CURRENT < PROGRESS_TOTAL)) && PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
  progress_render
}

progress_finish() {
  ((UI_PROGRESS)) || return 0
  ((PROGRESS_ACTIVE)) || return 0
  PROGRESS_LABEL="${1:-Done}"
  PROGRESS_CURRENT="$PROGRESS_TOTAL"
  progress_render
  printf '\n'
  PROGRESS_ACTIVE=0
}

banner_draw() {
  ((UI_BANNER)) || return 0

  printf '\033[2J\033[H'

  local black=""
  local blue=""
  if ((UI_COLOR)); then
    black="${c_gray}"
    blue="${c_blue}"
  fi

  printf '%b' "${black}"
  cat <<'EOF'
  ██▓███   ██▓    ▄▄▄       ███▄    █ ▓█████▄▄▄█████▓    ██ ▄█▀▄▄▄       ██▓
  ▓██░  ██▒▓██▒   ▒████▄     ██ ▀█   █ ▓█   ▀▓  ██▒ ▓▒    ██▄█▒▒████▄    ▓██▒
  ▓██░ ██▓▒▒██░   ▒██  ▀█▄  ▓██  ▀█ ██▒▒███  ▒ ▓██░ ▒░   ▓███▄░▒██  ▀█▄  ▒██▒
  ▒██▄█▓▒ ▒▒██░   ░██▄▄▄▄██ ▓██▒  ▐▌██▒▒▓█  ▄░ ▓██▓ ░    ▓██ █▄░██▄▄▄▄██ ░██░
  ▒██▒ ░  ░░██████▒▓█   ▓██▒▒██░   ▓██░░▒████▒ ▒██▒ ░    ▒██▒ █▄▓█   ▓██▒░██░
  ▒▓▒░ ░  ░░ ▒░▓  ░▒▒   ▓▒█░░ ▒░   ▒ ▒ ░░ ▒░ ░ ▒ ░░      ▒ ▒▒ ▓▒▒▒   ▓▒█░░▓  
  ░▒ ░     ░ ░ ▒  ░ ▒   ▒▒ ░░ ░░   ░ ▒░ ░ ░  ░   ░       ░ ░▒ ▒░ ▒   ▒▒ ░ ▒ ░
  ░░         ░ ░    ░   ▒      ░   ░ ░    ░    ░         ░ ░░ ░  ░   ▒    ▒ ░
              ░  ░     ░  ░         ░    ░  ░           ░  ░        ░  ░ ░    
EOF
  printf '%b%s%b\n' "${blue}" "    Sit back while your software is installed." "${c_reset}"
}

banner_enable_scroll_region() {
  ((UI_BANNER)) || return 0

  local header_lines=7
  local rows=24
  if have tput; then rows="$(tput lines 2>/dev/null || echo 24)"; fi
  [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
  if ((rows <= header_lines + 1)); then
    return 0
  fi

  printf '\033[?25l'
  printf '\033[%d;%dr' "$((header_lines + 1))" "$rows"
  printf '\033[%d;1H' "$((header_lines + 1))"
  add_cleanup "printf '\\033[r\\033[?25h'"
}

_msg() {
  progress_clear_line
  printf '%b\n' "$*"
  progress_render
}

_msg_err() {
  progress_clear_line
  printf '%b\n' "$*" >&2
  progress_render
}

title() { _msg "${c_bold}${c_blue}$i_step $*${c_reset}"; }
section() { _msg "${c_bold}${c_gray}$i_step${c_reset} ${c_bold}$*${c_reset}"; }
log() { _msg "${c_blue}${i_info}${c_reset} $*"; }
ok() { _msg "${c_green}${i_ok}${c_reset} $*"; }
warn() { _msg_err "${c_yellow}${i_warn}${c_reset} $*"; }
err() { _msg_err "${c_red}${i_err}${c_reset} $*"; }
die() { err "$*"; exit 1; }

on_err() {
  local exit_code=$?
  local line="${BASH_LINENO[0]:-unknown}"
  local cmd="${BASH_COMMAND:-unknown}"
  err "Command failed (exit ${exit_code}) at line ${line}"
  err "${i_sub} ${cmd}"
  exit "$exit_code"
}
trap on_err ERR

have() { command -v "$1" >/dev/null 2>&1; }

need_sudo() {
  if ! have sudo; then die "sudo is required."; fi
  section "Elevating privileges"
  log "Requesting sudo (you may be prompted)..."
  sudo -v

  # Keep sudo alive while the script runs (avoids re-prompt mid-install).
  # This exits automatically when the main process ends.
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  add_cleanup 'kill "${SUDO_KEEPALIVE_PID:-}" 2>/dev/null || true'
  ok "sudo access granted"
}

detect_pm() {
  if have apt-get; then echo "apt"
  elif have dnf; then echo "dnf"
  elif have pacman; then echo "pacman"
  else die "Unsupported system: couldn't find apt-get, dnf, or pacman."
  fi
}

OS_ID="unknown"
OS_LIKE=""
OS_CODENAME=""
UBUNTU_CODENAME=""
ARCH="$(uname -m)"

read_os_release() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_CODENAME="${VERSION_CODENAME:-}"
    UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
  fi
}

apt_update() { sudo apt-get update -y; }
apt_install_many() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }

apt_install_optional() {
  local failed=()
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then continue; fi
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p"; then
      failed+=("$p")
      warn "Could not install (apt): $p (skipping)"
    fi
  done
  ((${#failed[@]})) && warn "Skipped missing apt packages: ${failed[*]}"
}

dnf_install_optional() {
  local failed=()
  for p in "$@"; do
    if rpm -q "$p" >/dev/null 2>&1; then continue; fi
    if ! sudo dnf install -y "$p"; then
      failed+=("$p")
      warn "Could not install (dnf): $p (skipping)"
    fi
  done
  ((${#failed[@]})) && warn "Skipped missing dnf packages: ${failed[*]}"
}

pacman_install_optional() {
  local failed=()
  for p in "$@"; do
    if pacman -Qi "$p" >/dev/null 2>&1; then continue; fi
    if ! sudo pacman -S --noconfirm --needed "$p"; then
      failed+=("$p")
      warn "Could not install (pacman): $p (skipping)"
    fi
  done
  ((${#failed[@]})) && warn "Skipped missing pacman packages: ${failed[*]}"
}

# ---------- Flatpak ----------
setup_flatpak() {
  if have flatpak; then
    log "Flatpak already installed."
  else
    log "Installing Flatpak..."
    case "$PM" in
      apt)
        apt_update
        apt_install_many flatpak gnome-software-plugin-flatpak || apt_install_many flatpak
        ;;
      dnf) sudo dnf install -y flatpak ;;
      pacman) sudo pacman -Syu --noconfirm --needed flatpak ;;
    esac
  fi
  log "Adding Flathub remote (if needed)..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_flatpaks() {
  log "Installing Flatpak apps..."
  for app in "$@"; do
    if flatpak info "$app" >/dev/null 2>&1; then continue; fi
    if ! flatpak install -y flathub "$app"; then
      warn "Flatpak install failed for: $app (skipping)"
    fi
  done
}

# ---------- Repos (apt only, best-effort) ----------
setup_brave_repo_apt() {
  log "Setting up Brave repo (apt)..."
  sudo install -d -m 0755 /usr/share/keyrings
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
}

setup_edge_repo_apt() {
  log "Setting up Microsoft Edge repo (apt)..."
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null

  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
    | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
}

setup_github_cli_repo_apt() {
  log "Setting up GitHub CLI (gh) repo (apt) as a fallback..."
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  local arch
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
}

setup_adoptium_repo_apt() {
  log "Setting up Adoptium (Temurin) repo (apt)..."
  apt_update
  apt_install_many wget apt-transport-https gpg

  local codename="$OS_CODENAME"
  [[ -z "$codename" && -n "$UBUNTU_CODENAME" ]] && codename="$UBUNTU_CODENAME"
  [[ -z "$codename" ]] && codename="stable"

  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | gpg --dearmor \
    | sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg >/dev/null

  echo "deb https://packages.adoptium.net/artifactory/deb ${codename} main" \
    | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
}

install_temurin_25() {
  log "Installing Temurin JDK 25..."
  if [[ "$PM" == "apt" ]]; then
    apt_update
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y temurin-25-jdk; then
      warn "temurin-25-jdk install failed. Falling back to distro OpenJDK if available..."
      apt_install_optional openjdk-25-jdk openjdk-21-jdk
    fi
  elif [[ "$PM" == "dnf" ]]; then
    sudo dnf install -y temurin-25-jdk || warn "temurin-25-jdk not available via dnf here."
  else
    warn "Temurin automation not implemented for pacman in this script."
  fi
}

# ---------- Shell (Nerd Font + Oh My Zsh) ----------
ensure_zsh_installed() {
  if have zsh; then
    log "zsh already installed."
    return 0
  fi

  log "Installing zsh..."
  case "$PM" in
    apt) apt_install_optional zsh ;;
    dnf) sudo dnf install -y zsh || true ;;
    pacman) sudo pacman -S --noconfirm --needed zsh || true ;;
  esac
}

install_nerd_font() {
  if [[ "${INSTALL_NERD_FONT:-1}" == "0" ]]; then
    log "Nerd Font disabled via INSTALL_NERD_FONT=0 (skipping)."
    return
  fi

  if ! have curl; then
    warn "curl not available; cannot install Nerd Font (skipping)."
    return
  fi

  if ! have unzip; then
    warn "unzip not available; cannot install Nerd Font (skipping)."
    return
  fi

  if ! have fc-cache; then
    case "$PM" in
      apt) apt_install_optional fontconfig ;;
      dnf) sudo dnf install -y fontconfig || true ;;
      pacman) sudo pacman -S --noconfirm --needed fontconfig || true ;;
    esac
  fi

  local font_name="${NERD_FONT_NAME:-FiraCode}"
  local nerd_fonts_ver="${NERD_FONTS_VERSION:-v3.3.0}"
  local url="${NERD_FONT_URL:-https://github.com/ryanoasis/nerd-fonts/releases/download/${nerd_fonts_ver}/${font_name}.zip}"

  if have fc-list && fc-list 2>/dev/null | grep -qiE "${font_name}[[:space:]]+Nerd Font|${font_name}NerdFont"; then
    log "Nerd Font already installed: ${font_name}"
    return
  fi

  section "Nerd Font"
  log "Installing ${font_name} Nerd Font into ~/.local/share/fonts..."
  local tmp_dir zip_path dest_dir
  tmp_dir="$(mktemp -d -t nerd-font.XXXXXX)"
  zip_path="$tmp_dir/${font_name}.zip"
  dest_dir="$HOME/.local/share/fonts/NerdFonts/${font_name}"

  mkdir -p "$dest_dir"
  curl -LfsS -o "$zip_path" "$url" || { warn "Nerd Font download failed (skipping)."; rm -rf "$tmp_dir"; return; }

  unzip -q -o "$zip_path" -d "$tmp_dir/unz" || { warn "Nerd Font unzip failed (skipping)."; rm -rf "$tmp_dir"; return; }
  find "$tmp_dir/unz" -maxdepth 1 -type f -name '*.ttf' -exec cp -f {} "$dest_dir/" \; >/dev/null 2>&1 || true

  if have fc-cache; then
    fc-cache -f "$dest_dir" >/dev/null 2>&1 || true
  fi

  rm -rf "$tmp_dir"
  ok "Nerd Font installed: ${font_name}"
}

install_oh_my_zsh() {
  if [[ "${INSTALL_OH_MY_ZSH:-1}" == "0" ]]; then
    log "Oh My Zsh disabled via INSTALL_OH_MY_ZSH=0 (skipping)."
    return
  fi

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "Oh My Zsh already installed."
    return
  fi

  ensure_zsh_installed

  if ! have zsh; then
    warn "zsh not available; cannot install Oh My Zsh (skipping)."
    return
  fi
  if ! have git; then
    warn "git not available; cannot install Oh My Zsh (skipping)."
    return
  fi
  if ! have curl; then
    warn "curl not available; cannot install Oh My Zsh (skipping)."
    return
  fi

  section "Oh My Zsh"
  log "Installing Oh My Zsh..."

  local keep_zshrc_env=""
  if [[ -f "$HOME/.zshrc" ]]; then
    keep_zshrc_env="KEEP_ZSHRC=yes"
    log "Detected existing ~/.zshrc; keeping it as-is."
  fi

  RUNZSH=no CHSH=no ${keep_zshrc_env} sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    || warn "Oh My Zsh install failed (skipping)."
}

# ---------- Starship ----------
install_starship() {
  if have starship; then
    log "Starship already installed."
    return
  fi
  log "Installing Starship..."
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
}

# ---------- NVM + Node.js (LTS) ----------
install_nvm() {
  local nvm_dir="$HOME/.nvm"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    log "NVM already installed at $nvm_dir"
    return
  fi

  log "Installing NVM into $nvm_dir (without editing shell rc files)..."
  local nvm_ver="${NVM_VERSION:-v0.40.3}"

  mkdir -p "$nvm_dir"
  NVM_DIR="$nvm_dir" PROFILE=/dev/null bash -c \
    "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_ver}/install.sh | bash" || {
      warn "Pinned NVM install failed; trying master install script as fallback..."
      NVM_DIR="$nvm_dir" PROFILE=/dev/null bash -c \
        "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash" || {
          warn "NVM installation failed."
          return
        }
    }
}

install_node_lts_via_nvm() {
  local nvm_dir="$HOME/.nvm"
  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    warn "NVM not installed; cannot install Node via NVM."
    return
  fi

  log "Installing Node.js LTS via NVM and setting it as default..."
  bash -lc "
    set -e
    export NVM_DIR=\"$nvm_dir\"
    . \"$nvm_dir/nvm.sh\"
    nvm install --lts
    nvm alias default 'lts/*'
    # Enable Corepack (ships with modern Node) so pnpm/yarn are easy later
    command -v corepack >/dev/null 2>&1 && corepack enable || true
    node -v
    npm -v
  " || warn "Node install via NVM failed (open a new terminal and try: nvm install --lts)."
}

# ---------- Cursor AppImage ----------
install_cursor_appimage() {
  log "Installing Cursor (AppImage) into ~/Applications..."
  mkdir -p "$HOME/Applications"
  local dest="$HOME/Applications/cursor.AppImage"

  if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
    warn "Cursor AppImage automation assumes x86_64. You are: $ARCH (skipping Cursor)."
    return
  fi

  curl -LfsS -o "$dest" "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/2.3" || {
    warn "Cursor download failed (skipping)."
    return
  }
  chmod +x "$dest"

  case "$PM" in
    apt) apt_install_optional libfuse2 ;;
    dnf) dnf_install_optional fuse-libs ;;
    pacman) pacman_install_optional fuse2 ;;
  esac

  mkdir -p "$HOME/.local/share/applications"
  cat > "$HOME/.local/share/applications/cursor.desktop" <<EOF
[Desktop Entry]
Name=Cursor
Exec=$dest
Terminal=false
Type=Application
Categories=Development;IDE;
EOF
}

apt_install_deb_from_url() {
  local label="$1"
  local dpkg_name="$2"
  local url="$3"
  local arch_desc="${4:-}"

  if [[ "$PM" != "apt" ]]; then
    warn "${label} install is currently implemented for apt (.deb) only (skipping)."
    return 0
  fi

  if [[ -n "$arch_desc" && "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
    warn "${label} .deb is ${arch_desc}; you are: $ARCH (skipping)."
    return 0
  fi

  if dpkg -s "$dpkg_name" >/dev/null 2>&1; then
    log "${label} already installed."
    return 0
  fi

  section "$label"
  log "Downloading ${label} (.deb)..."
  local tmp_deb
  tmp_deb="$(mktemp -t "${dpkg_name}".XXXXXX.deb)"
  curl -LfsS -o "$tmp_deb" "$url" || { warn "${label} download failed (skipping)."; rm -f "$tmp_deb"; return 0; }

  log "Installing ${label}..."
  if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp_deb"; then
    ok "${label} installed"
  else
    warn "${label} install failed (skipping)."
  fi
  rm -f "$tmp_deb"
}

# ---------- GitHub Desktop (shiftkey .deb) ----------
install_github_desktop_deb() {
  local url="${GITHUB_DESKTOP_DEB_URL:-https://github.com/shiftkey/desktop/releases/download/release-3.4.13-linux1/GitHubDesktop-linux-amd64-3.4.13-linux1.deb}"
  apt_install_deb_from_url "GitHub Desktop" "github-desktop" "$url" "amd64"
}

# ---------- Deskflow (.deb) ----------
install_deskflow_deb() {
  local url="${DESKFLOW_DEB_URL:-https://github.com/deskflow/deskflow/releases/download/v1.25.0/deskflow-1.25.0-ubuntu-questing-x86_64.deb}"

  if [[ "${INSTALL_DESKFLOW:-1}" == "0" ]]; then
    log "Deskflow disabled via INSTALL_DESKFLOW=0 (skipping)."
    return
  fi
  apt_install_deb_from_url "Deskflow" "deskflow" "$url" "x86_64"
}

# ---------- Wallpapers (repo -> ~/Pictures/Wallpapers + GNOME slideshow) ----------
xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "$s"
}

copy_wallpapers_to_pictures() {
  if [[ "${INSTALL_WALLPAPERS:-1}" == "0" ]]; then
    log "Wallpapers disabled via INSTALL_WALLPAPERS=0 (skipping)."
    return
  fi

  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    warn "SCRIPT_DIR not set; cannot locate repo Wallpapers directory (skipping)."
    return
  fi

  local src="${SCRIPT_DIR}/Wallpapers"
  if [[ ! -d "$src" ]]; then
    warn "No Wallpapers directory found next to bootstrap.sh at: $src (skipping)."
    return
  fi

  local dest="$HOME/Pictures/Wallpapers"
  section "Wallpapers"
  log "Copying repo wallpapers into: $dest"
  mkdir -p "$dest"

  local overwrite="${WALLPAPERS_OVERWRITE:-0}"
  if have rsync; then
    if [[ "$overwrite" == "1" ]]; then
      rsync -a --delete "$src/." "$dest/" || warn "rsync copy failed (skipping)."
    else
      rsync -a --ignore-existing "$src/." "$dest/" || warn "rsync copy failed (skipping)."
    fi
  else
    if [[ "$overwrite" == "1" ]]; then
      cp -a "$src/." "$dest/" 2>/dev/null || warn "cp copy failed (skipping)."
    else
      cp -an "$src/." "$dest/" 2>/dev/null || cp -a "$src/." "$dest/" 2>/dev/null || warn "cp copy failed (skipping)."
    fi
  fi

  local count
  count="$(find "$dest" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  ok "Wallpapers ready (${count} files)"
}

generate_gnome_slideshow_xml() {
  local images_dir="$1"
  local out_xml="$2"
  local static_seconds="${WALLPAPER_STATIC_SECONDS:-300}"
  local transition_seconds="${WALLPAPER_TRANSITION_SECONDS:-5}"

  mapfile -t images < <(
    find "$images_dir" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      -printf '%p\n' 2>/dev/null | sort
  )

  if ((${#images[@]} < 2)); then
    warn "Need at least 2 wallpapers to generate a slideshow XML (found ${#images[@]})."
    return 1
  fi

  mkdir -p "$(dirname "$out_xml")"
  local tmp_xml
  tmp_xml="$(mktemp -t planetkai-slideshow.XXXXXX.xml)"

  local year month day hour minute second
  year="$(date +%Y)"; month="$(date +%m)"; day="$(date +%d)"
  hour="$(date +%H)"; minute="$(date +%M)"; second="$(date +%S)"

  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE wallpaper SYSTEM "gnome-wp-list.dtd">'
    printf '%s\n' '<background>'
    printf '%s\n' '  <starttime>'
    printf '    <year>%s</year>\n' "$(xml_escape "$year")"
    printf '    <month>%s</month>\n' "$(xml_escape "$month")"
    printf '    <day>%s</day>\n' "$(xml_escape "$day")"
    printf '    <hour>%s</hour>\n' "$(xml_escape "$hour")"
    printf '    <minute>%s</minute>\n' "$(xml_escape "$minute")"
    printf '    <second>%s</second>\n' "$(xml_escape "$second")"
    printf '%s\n' '  </starttime>'

    local i from to
    for ((i = 0; i < ${#images[@]}; i++)); do
      from="${images[$i]}"
      to="${images[$(( (i + 1) % ${#images[@]} ))]}"
      printf '%s\n' '  <static>'
      printf '    <duration>%s.0</duration>\n' "$(xml_escape "$static_seconds")"
      printf '    <file>%s</file>\n' "$(xml_escape "$from")"
      printf '%s\n' '  </static>'
      printf '%s\n' '  <transition>'
      printf '    <duration>%s.0</duration>\n' "$(xml_escape "$transition_seconds")"
      printf '    <from>%s</from>\n' "$(xml_escape "$from")"
      printf '    <to>%s</to>\n' "$(xml_escape "$to")"
      printf '%s\n' '  </transition>'
    done
    printf '%s\n' '</background>'
  } >"$tmp_xml"

  mv -f "$tmp_xml" "$out_xml"
  ok "Generated GNOME slideshow: $out_xml"
}

set_gnome_wallpaper_to_slideshow() {
  if [[ "${INSTALL_GNOME_WALLPAPER_SLIDESHOW:-1}" == "0" ]]; then
    log "GNOME slideshow disabled via INSTALL_GNOME_WALLPAPER_SLIDESHOW=0 (skipping)."
    return
  fi

  local images_dir="$HOME/Pictures/Wallpapers"
  if [[ ! -d "$images_dir" ]]; then
    warn "Wallpapers folder not found at $images_dir (skipping slideshow)."
    return
  fi

  if ! have gsettings; then
    warn "gsettings not available; skipping GNOME wallpaper slideshow."
    return
  fi
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    warn "No desktop session detected (DBUS_SESSION_BUS_ADDRESS missing); skipping GNOME wallpaper slideshow."
    return
  fi

  section "GNOME wallpaper"
  local xml_path="$HOME/.local/share/backgrounds/planetkai-wallpapers.xml"
  generate_gnome_slideshow_xml "$images_dir" "$xml_path" || return

  local uri="file://${xml_path}"
  log "Setting GNOME background to slideshow XML..."
  gsettings set org.gnome.desktop.background picture-uri "$uri" || warn "Could not set org.gnome.desktop.background picture-uri"
  gsettings set org.gnome.desktop.background picture-uri-dark "$uri" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.background picture-options "zoom" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.screensaver picture-uri "$uri" >/dev/null 2>&1 || true
  ok "GNOME wallpaper slideshow configured"
}

# ---------- GNOME Extensions (extensions.gnome.org) ----------
ego_info_json() {
  local uuid="$1"
  local shell_ver="$2"
  curl -fsSL -A "Mozilla/5.0" "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_ver}" 2>/dev/null || true
}

ego_extract_field() {
  local field="$1"
  if have jq; then
    jq -r ".${field} // empty" 2>/dev/null | head -n 1
    return 0
  fi
  sed -nE "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\\1/p" | head -n 1
}

ego_download_url() {
  local uuid="$1"
  local shell_ver_full="$2"
  local shell_ver_major="$3"

  local json download_path
  if [[ -n "$shell_ver_full" ]]; then
    json="$(ego_info_json "$uuid" "$shell_ver_full")"
    download_path="$(printf '%s' "$json" | ego_extract_field download_url)"
    [[ -n "$download_path" ]] && printf 'https://extensions.gnome.org%s\n' "$download_path" && return 0
  fi

  if [[ -n "$shell_ver_major" ]]; then
    json="$(ego_info_json "$uuid" "$shell_ver_major")"
    download_path="$(printf '%s' "$json" | ego_extract_field download_url)"
    [[ -n "$download_path" ]] && printf 'https://extensions.gnome.org%s\n' "$download_path" && return 0
  fi

  return 1
}

install_gnome_extensions() {
  local uuids=("$@")

  if ! have gnome-shell; then
    warn "GNOME Shell not detected; skipping GNOME extensions."
    return
  fi

  if ! have gnome-extensions; then
    if [[ "$PM" == "apt" ]]; then
      log "Installing gnome-extensions tooling (best-effort)..."
      apt_install_optional gnome-shell-extension-prefs gnome-shell-extensions
    fi
  fi

  if ! have gnome-extensions; then
    warn "gnome-extensions command not available; skipping GNOME extensions."
    return
  fi

  section "GNOME extensions"

  local shell_ver_raw shell_ver_full shell_ver_major
  shell_ver_raw="$(gnome-shell --version 2>/dev/null || true)"
  shell_ver_full="$(printf '%s' "$shell_ver_raw" | sed -nE 's/.* ([0-9]+\\.[0-9]+).*/\\1/p' | head -n 1)"
  shell_ver_major="$(printf '%s' "$shell_ver_raw" | sed -nE 's/.* ([0-9]+).*/\\1/p' | head -n 1)"

  if [[ -z "$shell_ver_full" && -z "$shell_ver_major" ]]; then
    warn "Could not determine GNOME Shell version; skipping GNOME extensions."
    return
  fi

  log "GNOME Shell version: ${shell_ver_full:-$shell_ver_major}"

  local installed=""
  installed="$(gnome-extensions list 2>/dev/null || true)"

  local uuid
  for uuid in "${uuids[@]}"; do
    if printf '%s\n' "$installed" | grep -Fxq "$uuid"; then
      ok "Extension already installed: $uuid"
      continue
    fi

    log "Installing extension: $uuid"
    local url tmp_zip
    if ! url="$(ego_download_url "$uuid" "$shell_ver_full" "$shell_ver_major")"; then
      warn "No compatible download found on extensions.gnome.org for: $uuid (skipping)"
      continue
    fi

    tmp_zip="$(mktemp -t gnome-ext.XXXXXX.zip)"
    if ! curl -LfsS -A "Mozilla/5.0" -o "$tmp_zip" "$url"; then
      warn "Download failed for: $uuid (skipping)"
      rm -f "$tmp_zip"
      continue
    fi

    if gnome-extensions install --force "$tmp_zip" >/dev/null 2>&1 || gnome-extensions install -f "$tmp_zip" >/dev/null 2>&1; then
      ok "Installed: $uuid"
      installed+=$'\n'"$uuid"
    else
      warn "Install failed for: $uuid (skipping)"
      rm -f "$tmp_zip"
      continue
    fi
    rm -f "$tmp_zip"

    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      if gnome-extensions enable "$uuid" >/dev/null 2>&1; then
        ok "Enabled: $uuid"
      else
        warn "Installed but could not enable (try enabling in Extensions app): $uuid"
      fi
    else
      warn "Installed but not enabling (no desktop session detected): $uuid"
    fi
  done
}

# ---------- ckb-next (Corsair keyboards/mice on Linux) ----------
install_ckb_next() {
  if [[ "${INSTALL_CKB_NEXT:-1}" == "0" ]]; then
    log "ckb-next disabled via INSTALL_CKB_NEXT=0 (skipping)."
    return
  fi

  if have ckb-next-daemon || have ckb-next; then
    log "ckb-next already installed."
    return
  fi

  if ! have git; then
    warn "git not available; cannot install ckb-next (skipping)."
    return
  fi

  section "ckb-next"
  warn "Installing ckb-next by running upstream ./quickinstall (may install build deps + services)."

  local repo_url="${CKB_NEXT_REPO_URL:-https://github.com/ckb-next/ckb-next.git}"
  local repo_ref="${CKB_NEXT_REF:-}"

  local tmp_dir repo_dir
  tmp_dir="$(mktemp -d -t ckb-next.XXXXXX)"
  repo_dir="$tmp_dir/ckb-next"

  log "Cloning: $repo_url"
  if ! git clone --depth=1 "$repo_url" "$repo_dir" >/dev/null 2>&1; then
    warn "ckb-next clone failed (skipping)."
    rm -rf "$tmp_dir"
    return
  fi

  if [[ -n "$repo_ref" ]]; then
    log "Checking out ref: $repo_ref"
    ( cd "$repo_dir" && git fetch --depth=1 origin "$repo_ref" >/dev/null 2>&1 && git checkout -q "$repo_ref" ) || {
      warn "Could not checkout CKB_NEXT_REF=$repo_ref (continuing with default)."
    }
  fi

  log "Running ./quickinstall..."
  ( cd "$repo_dir" && chmod +x ./quickinstall && ./quickinstall ) || {
    warn "ckb-next quickinstall failed (skipping)."
    rm -rf "$tmp_dir"
    return
  }

  rm -rf "$tmp_dir"
  ok "ckb-next install attempted"
  warn "If udev rules/services were added, you may need to log out/in or reboot."
}

# ---------- Zsh plugins fallback ----------
install_zsh_plugins_fallback() {
  local base="$HOME/.zsh/plugins"
  mkdir -p "$base"

  # Prefer distro packages when available (faster updates), but keep git clone fallback.
  case "$PM" in
    apt) apt_install_optional zsh-autosuggestions zsh-syntax-highlighting ;;
    dnf) dnf_install_optional zsh-autosuggestions zsh-syntax-highlighting ;;
    pacman) pacman_install_optional zsh-autosuggestions zsh-syntax-highlighting ;;
  esac

  if ! have git; then
    warn "git not found; can't clone zsh plugins fallback."
    return
  fi

  local a_dir="$base/zsh-autosuggestions"
  local s_dir="$base/zsh-syntax-highlighting"

  if [[ ! -d "$a_dir" ]]; then
    log "Ensuring zsh-autosuggestions (fallback clone if needed)..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$a_dir" >/dev/null 2>&1 || true
  fi
  if [[ ! -d "$s_dir" ]]; then
    log "Ensuring zsh-syntax-highlighting (fallback clone if needed)..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$s_dir" >/dev/null 2>&1 || true
  fi
}

ensure_bat_command() {
  mkdir -p "$HOME/.local/bin"
  if have bat; then return; fi
  if have batcat; then
    log "Creating ~/.local/bin/bat shim -> batcat"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
}

ensure_zsh_default() {
  if ! have zsh; then
    warn "zsh not installed yet; cannot set default shell."
    return
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log "Default shell already set to zsh."
    return
  fi

  log "Setting zsh as default shell for user '$USER'..."
  chsh -s "$zsh_path" "$USER" || warn "chsh failed. You may need to run: chsh -s $zsh_path"
}

append_managed_zshrc_block() {
  local zshrc="$HOME/.zshrc"
  touch "$zshrc"

  local start="# >>> NAT_BOOTSTRAP_ZSH >>>"
  local end="# <<< NAT_BOOTSTRAP_ZSH <<<"

  if grep -qF "$start" "$zshrc"; then
    log "Updating existing managed block in ~/.zshrc..."
    awk -v s="$start" -v e="$end" '
      $0==s {inblk=1; next}
      $0==e {inblk=0; next}
      !inblk {print}
    ' "$zshrc" > "${zshrc}.tmp"
    mv "${zshrc}.tmp" "$zshrc"
  else
    log "Appending managed block to end of ~/.zshrc..."
  fi

  cat >> "$zshrc" <<'EOF'

# >>> NAT_BOOTSTRAP_ZSH >>>
# Make sure user-local bin comes first
export PATH="$HOME/.local/bin:$PATH"

# Enable ccache compiler wrappers if present
if [[ -d /usr/lib/ccache ]]; then
  export PATH="/usr/lib/ccache:$PATH"
fi

# Starship prompt (as requested)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# zoxide (better cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# fzf keybindings + completion (common distro paths)
for f in \
  /usr/share/fzf/key-bindings.zsh \
  /usr/share/fzf/completion.zsh \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/doc/fzf/examples/completion.zsh
do
  [[ -r "$f" ]] && source "$f"
done

# zsh-autosuggestions (system path OR fallback clone)
for f in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
do
  [[ -r "$f" ]] && source "$f" && break
done

# zsh-syntax-highlighting (must be sourced AFTER other plugins)
for f in \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
do
  [[ -r "$f" ]] && source "$f" && break
done

# eza aliases
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --color=auto'
  alias ll='eza -lah --group-directories-first --color=auto'
fi

# Debian/Ubuntu sometimes provides bat as batcat; we also create a shim in ~/.local/bin
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  alias bat='batcat'
fi

# Only run in interactive shells: fortune | cowsay with random cowfile
if [[ $- == *i* ]]; then
  if command -v fortune >/dev/null && command -v cowsay >/dev/null; then
    cowfile="$(ls /usr/share/cowsay/cows/*.cow 2>/dev/null | shuf -n 1)"
    if [[ -n $cowfile ]]; then
      fortune | cowsay -f "$cowfile"
    else
      fortune | cowsay
    fi
  fi
fi
# <<< NAT_BOOTSTRAP_ZSH <<<
EOF
}

# ===================== main =====================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PM="$(detect_pm)"
read_os_release

banner_draw
banner_enable_scroll_region

title "Linux bootstrap"
log "Package manager: ${c_bold}${PM}${c_reset}"
log "Distro: ${c_bold}${OS_ID}${c_reset} (like: ${OS_LIKE:-n/a})"
log "Arch: ${c_bold}${ARCH}${c_reset}"

# Total progress steps (roughly: big phases + key tooling).
progress_init 25 "Initializing"
need_sudo
progress_advance "sudo ready"

APT_REQUIRED=(
  curl wget gpg ca-certificates git
  build-essential make cmake pkg-config
  libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-mixer-dev
  tmux zip unzip
  gdb valgrind ccache
  ripgrep fzf zoxide
  fonts-firacode
)

APT_OPTIONAL=(
  eza
  gh
  bat
  unrar unrar-free
  cmatrix cbonsai fortune-mod cowsay lolcat figlet
  pipes.sh sl ninvaders nsnake pacman4console moon-buggy bastet
  hollywood fastfetch btop npm qdirstat remmina vlc cool-retro-term
)

FLATPAKS=(
  dev.vencord.Vesktop
  com.visualstudio.code
  com.valvesoftware.Steam
  net.lutris.Lutris
  tv.plex.PlexDesktop
  com.plexamp.Plexamp
  org.prismlauncher.PrismLauncher
  org.kde.dolphin
  com.github.tchx84.Flatseal
)

case "$PM" in
  apt)
    section "Packages (apt)"
    log "Updating apt + installing required packages..."
    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || true
    sudo add-apt-repository -y universe >/dev/null 2>&1 || true
    sudo add-apt-repository -y multiverse >/dev/null 2>&1 || true

    apt_install_many "${APT_REQUIRED[@]}"
    ok "Required packages installed"
    progress_advance "Required packages"

    log "Installing optional apt packages (skips anything missing)..."
    apt_install_optional "${APT_OPTIONAL[@]}"
    progress_advance "Optional packages"

    if ! command -v gh >/dev/null 2>&1; then
      setup_github_cli_repo_apt || true
      apt_update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh || warn "gh install still failed; install manually if needed."
    fi
    progress_advance "GitHub CLI"

    setup_brave_repo_apt || warn "Brave repo setup failed (skipping Brave)."
    setup_edge_repo_apt  || warn "Edge repo setup failed (skipping Edge)."

    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser || warn "Brave install failed."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y microsoft-edge-stable || warn "Edge install failed."
    progress_advance "Browsers (Brave/Edge)"

    setup_adoptium_repo_apt || warn "Adoptium repo setup failed (skipping Temurin JDK 25)."
    install_temurin_25
    progress_advance "Java (Temurin)"
    ;;
  dnf)
    section "Packages (dnf)"
    log "Installing packages via dnf (best-effort)..."
    sudo dnf install -y curl wget gpg ca-certificates git || true
    sudo dnf groupinstall -y "Development Tools" || true

    dnf_install_optional cmake pkgconf-pkg-config SDL2-devel SDL2_ttf-devel SDL2_image-devel SDL2_mixer-devel
    dnf_install_optional tmux zip unzip unrar
    dnf_install_optional gdb valgrind ccache
    dnf_install_optional ripgrep fzf zoxide
    dnf_install_optional eza gh bat
    dnf_install_optional fira-code-fonts
    dnf_install_optional cmatrix fortune-mod cowsay lolcat figlet sl ninvaders hollywood fastfetch btop qdirstat remmina vlc cool-retro-term npm

    warn "Brave/Edge repo automation is apt-focused; install those manually on Fedora if desired."
    progress_advance "Required packages"
    progress_advance "Optional packages"
    progress_advance "GitHub CLI"
    progress_advance "Browsers (skipped)"
    progress_advance "Java (Temurin)"
    ;;
  pacman)
    section "Packages (pacman)"
    log "Installing packages via pacman (best-effort)..."
    sudo pacman -Syu --noconfirm --needed \
      curl wget gnupg ca-certificates git base-devel cmake pkgconf \
      sdl2 sdl2_ttf sdl2_image sdl2_mixer \
      tmux zip unzip || true

    pacman_install_optional unrar
    pacman_install_optional gdb valgrind ccache
    pacman_install_optional ripgrep fzf zoxide
    pacman_install_optional eza bat
    pacman_install_optional github-cli # provides "gh"
    pacman_install_optional ttf-fira-code
    pacman_install_optional cmatrix fortune-mod cowsay lolcat figlet sl ninvaders hollywood fastfetch btop qdirstat remmina vlc npm

    warn "Brave/Edge/Temurin repo automation not implemented for pacman here (AUR is distro-specific)."
    progress_advance "Required packages"
    progress_advance "Optional packages"
    progress_advance "GitHub CLI"
    progress_advance "Browsers (skipped)"
    progress_advance "Java (skipped)"
    ;;
esac

# Flatpaks
section "Flatpak"
setup_flatpak
progress_advance "Flatpak setup"
install_flatpaks "${FLATPAKS[@]}"
ok "Flatpak apps processed"
progress_advance "Flatpak apps"

# Wallpapers + slideshow
copy_wallpapers_to_pictures
progress_advance "Wallpapers"
set_gnome_wallpaper_to_slideshow
progress_advance "Wallpaper slideshow"

# GNOME extensions
GNOME_EXTENSIONS=(
  add-to-desktop@tommimon.github.com
  appindicatorsupport@rgcjonas.gmail.com
  azwallpaper@azwallpaper.gitlab.com
  blur-my-shell@aunetx
  burn-my-windows@schneegans.github.com
  clipboard-indicator@tudmotu.com
  compiz-alike-magic-lamp-effect@hermes83.github.com
  compiz-windows-effect@hermes83.github.com
  CoverflowAltTab@palatis.blogspot.com
  custom-accent-colors@demiskp
  dash2dock-lite@icedman.github.com
  dash-to-dock@micxgx.gmail.com
  desktop-cube@schneegans.github.com
  dynamic-panel@velhlkj.com
  grand-theft-focus@zalckos.github.com
  lockscreen-extension@pratap.fastmail.fm
  monitor@astraext.github.io
  notifications-alert-on-user-menu@hackedbellini.gmail.com
  runcat@kolesnikov.se
  simple-weather@romanlefler.com
  transparent-top-bar@ftpix.com
  user-theme@gnome-shell-extensions.gcampax.github.com
)
install_gnome_extensions "${GNOME_EXTENSIONS[@]}"
progress_advance "GNOME extensions"

# Shell setup (ordered)
section "Shell"
install_nerd_font
progress_advance "Nerd Font"
ensure_zsh_installed
progress_advance "Zsh"
install_oh_my_zsh
progress_advance "Oh My Zsh"
install_starship
progress_advance "Starship"

# Tooling + shell extras
section "Tooling"
install_nvm
progress_advance "NVM"
install_node_lts_via_nvm
progress_advance "Node.js (LTS)"
install_github_desktop_deb
progress_advance "GitHub Desktop"
install_deskflow_deb
progress_advance "Deskflow"
install_ckb_next
progress_advance "ckb-next"
install_zsh_plugins_fallback
progress_advance "Zsh plugins"
ensure_bat_command
progress_advance "bat shim"
install_cursor_appimage
progress_advance "Cursor"
append_managed_zshrc_block
progress_advance "~/.zshrc"
ensure_zsh_default
progress_advance "Default shell"

ok "All done"
warn "Open a new terminal for default shell changes + zshrc updates to fully apply."
warn "Node is installed via NVM (LTS) and set as default."

progress_finish "Complete"
