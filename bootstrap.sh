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

c_reset="\033[0m"
c_blue="\033[1;34m"
c_yellow="\033[1;33m"
c_red="\033[1;31m"

log()  { echo -e "${c_blue}==>${c_reset} $*"; }
warn() { echo -e "${c_yellow}!!${c_reset} $*" >&2; }
die()  { echo -e "${c_red}xx${c_reset} $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

need_sudo() {
  if ! have sudo; then die "sudo is required."; fi
  sudo -v
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
    sudo apt-get update -y
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

# ---------- Zsh plugins fallback ----------
install_zsh_plugins_fallback() {
  local base="$HOME/.zsh/plugins"
  mkdir -p "$base"

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
need_sudo
PM="$(detect_pm)"
read_os_release

log "Detected package manager: $PM (distro: $OS_ID, like: $OS_LIKE, arch: $ARCH)"

APT_REQUIRED=(
  curl wget gpg ca-certificates git
  build-essential make cmake pkg-config
  libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-mixer-dev
  zsh tmux zip unzip
  gdb valgrind ccache
  ripgrep fzf zoxide
  fonts-firacode
  zsh-autosuggestions zsh-syntax-highlighting
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
  com.discordapp.Discord
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
    log "Updating apt + installing required packages..."
    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common >/dev/null 2>&1 || true
    sudo add-apt-repository -y universe >/dev/null 2>&1 || true
    sudo add-apt-repository -y multiverse >/dev/null 2>&1 || true

    apt_install_many "${APT_REQUIRED[@]}"

    log "Installing optional apt packages (skips anything missing)..."
    apt_install_optional "${APT_OPTIONAL[@]}"

    if ! command -v gh >/dev/null 2>&1; then
      setup_github_cli_repo_apt || true
      apt_update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh || warn "gh install still failed; install manually if needed."
    fi

    setup_brave_repo_apt || warn "Brave repo setup failed (skipping Brave)."
    setup_edge_repo_apt  || warn "Edge repo setup failed (skipping Edge)."

    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser || warn "Brave install failed."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y microsoft-edge-stable || warn "Edge install failed."

    setup_adoptium_repo_apt || warn "Adoptium repo setup failed (skipping Temurin JDK 25)."
    install_temurin_25
    ;;
  dnf)
    log "Installing packages via dnf (best-effort)..."
    sudo dnf install -y curl wget gpg ca-certificates git || true
    sudo dnf groupinstall -y "Development Tools" || true

    dnf_install_optional cmake pkgconf-pkg-config SDL2-devel SDL2_ttf-devel SDL2_image-devel SDL2_mixer-devel
    dnf_install_optional zsh tmux zip unzip unrar
    dnf_install_optional gdb valgrind ccache
    dnf_install_optional ripgrep fzf zoxide
    dnf_install_optional zsh-autosuggestions zsh-syntax-highlighting
    dnf_install_optional eza gh bat
    dnf_install_optional fira-code-fonts
    dnf_install_optional cmatrix fortune-mod cowsay lolcat figlet sl ninvaders hollywood fastfetch btop qdirstat remmina vlc cool-retro-term npm

    warn "Brave/Edge repo automation is apt-focused; install those manually on Fedora if desired."
    ;;
  pacman)
    log "Installing packages via pacman (best-effort)..."
    sudo pacman -Syu --noconfirm --needed \
      curl wget gnupg ca-certificates git base-devel cmake pkgconf \
      sdl2 sdl2_ttf sdl2_image sdl2_mixer \
      zsh tmux zip unzip || true

    pacman_install_optional unrar
    pacman_install_optional gdb valgrind ccache
    pacman_install_optional ripgrep fzf zoxide
    pacman_install_optional zsh-autosuggestions zsh-syntax-highlighting
    pacman_install_optional eza bat
    pacman_install_optional github-cli # provides "gh"
    pacman_install_optional ttf-fira-code
    pacman_install_optional cmatrix fortune-mod cowsay lolcat figlet sl ninvaders hollywood fastfetch btop qdirstat remmina vlc npm

    warn "Brave/Edge/Temurin repo automation not implemented for pacman here (AUR is distro-specific)."
    ;;
esac

# Flatpaks
setup_flatpak
install_flatpaks "${FLATPAKS[@]}"

# Tooling + shell setup
install_starship
install_nvm
install_node_lts_via_nvm
install_zsh_plugins_fallback
ensure_bat_command
install_cursor_appimage
append_managed_zshrc_block
ensure_zsh_default

log "All done."
warn "Open a new terminal for default shell changes + zshrc updates to fully apply."
warn "Node is installed via NVM (LTS) and set as default."