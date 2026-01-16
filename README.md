# Fresh Linux Bootstrap Script

This script is a **fresh-install bootstrapper** for Linux that installs a curated set of CLI/dev tools and desktop apps, then configures a consistent **Zsh + Starship + NVM** environment.

It’s designed to work best on **Debian/Ubuntu/Pop!_OS (APT)**, with **best-effort support** for **Fedora (DNF)** and **Arch (Pacman)**.

---

## What it does

On every run, the script:

1. Detects your package manager (**apt**, **dnf**, or **pacman**)
2. Installs system packages (required + optional lists)
3. Ensures Flatpak + Flathub exist and installs Flatpak apps
4. Installs **Starship**
5. Installs **NVM** and then installs **Node.js LTS** via NVM (sets it as default)
6. Installs **Cursor** as an AppImage (x86_64 only) and creates a desktop entry
7. Updates `~/.zshrc` by writing a **managed block at the end** (idempotent)
8. Sets **Zsh as your default shell** (`chsh`)

---

## Requirements

- A Linux distro with one of: `apt-get`, `dnf`, or `pacman`
- `sudo` access (needed for system installs)
- Internet access (downloads repos/keys, Starship/NVM install scripts, Flatpaks, Cursor)

---

## How to run

1. Save the script as `bootstrap.sh`
2. Make it executable:
   ```bash
   chmod +x bootstrap.sh
   ```
3. Run it:
   ```bash
   ./bootstrap.sh
   ```

### After it finishes

Open a **new terminal** (or log out/in) so:

- the **default shell** switches to Zsh
- the updated `.zshrc` is loaded
- `nvm`, `node`, `npm`, and Starship are available in your interactive shell

---

## Packages installed

Package names can vary by distro. The script uses:

- **Required list**: installed as a group (expected to exist)
- **Optional list**: installed one-by-one (missing packages are skipped)
- Equivalent best-effort sets for DNF/Pacman

### Core system + dev tooling

Installed (best effort depending on distro):

- Download/signing basics: `curl`, `wget`, `gpg`, `ca-certificates`
- Dev base toolchain:
  - Debian/Ubuntu: `build-essential`, `make`, `cmake`, `pkg-config`
  - Fedora: Development Tools group + `cmake`, `pkgconf-pkg-config`
  - Arch: `base-devel`, `cmake`, `pkgconf`
- SDL2 development headers:
  - Debian/Ubuntu: `libsdl2-dev`, `libsdl2-ttf-dev`, `libsdl2-image-dev`, `libsdl2-mixer-dev`
  - Fedora: `SDL2-devel`, `SDL2_ttf-devel`, `SDL2_image-devel`, `SDL2_mixer-devel`
  - Arch: `sdl2`, `sdl2_ttf`, `sdl2_image`, `sdl2_mixer`
- Debug/perf/build helpers: `gdb`, `valgrind`, `ccache`
- Shell + terminal: `zsh`, `tmux`
- Archives: `zip`, `unzip`, plus `unrar` when available
- Git tooling: `git`, `gh` (GitHub CLI)  
  - On APT, if `gh` isn’t available, the script adds the GitHub CLI repo and retries.

### Modern CLI utilities

Installed where available:

- `eza` (modern `ls`)
- `ripgrep` (`rg`)
- `fzf`
- `zoxide`
- `bat` (or `batcat` on some Debian/Ubuntu variants)

### Zsh plugins

The script tries package installs first:

- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

If those packages are missing on your distro, it **falls back to cloning** into:

- `~/.zsh/plugins/zsh-autosuggestions`
- `~/.zsh/plugins/zsh-syntax-highlighting`

### Fonts

- Debian/Ubuntu: `fonts-firacode`
- Fedora: `fira-code-fonts`
- Arch: `ttf-fira-code`

### Fun / optional terminal apps

Installed as optional when available:

- `cmatrix`, `cbonsai`
- `fortune-mod`, `cowsay`, `lolcat`, `figlet`
- `pipes.sh`, `sl`, `ninvaders`, `nsnake`, `pacman4console`, `moon-buggy`, `bastet`
- `hollywood`
- `fastfetch`, `btop`
- `npm` (system package; note: Node itself is installed via NVM)
- `qdirstat`, `remmina`, `vlc`, `cool-retro-term`

### Browsers (APT only)

On Debian/Ubuntu/Pop!_OS, the script adds official repos and installs:

- **Brave Browser**: `brave-browser`
- **Microsoft Edge**: `microsoft-edge-stable`

On Fedora/Arch, Brave/Edge repo automation is not included (you can install those manually).

### Java (Temurin JDK 25)

- Adds Adoptium’s repo on APT and installs `temurin-25-jdk`
- Falls back to `openjdk-25-jdk` or `openjdk-21-jdk` if Temurin fails
- Best-effort attempt on DNF; not implemented for pacman in this script

---

## Flatpak apps installed (Flathub)

The script ensures Flatpak + Flathub are set up, then installs:

- Discord: `com.discordapp.Discord`
- Visual Studio Code: `com.visualstudio.code`
- Steam: `com.valvesoftware.Steam`
- Lutris: `net.lutris.Lutris`
- Plex Desktop: `tv.plex.PlexDesktop`
- Plexamp: `com.plexamp.Plexamp`
- Prism Launcher: `org.prismlauncher.PrismLauncher`
- KDE Dolphin: `org.kde.dolphin`
- Flatseal: `com.github.tchx84.Flatseal`

---

## Cursor IDE (AppImage)

The script:

- Downloads Cursor as an AppImage into: `~/Applications/cursor.AppImage`
- Creates a desktop entry at: `~/.local/share/applications/cursor.desktop`
- Installs `libfuse2` / `fuse-libs` / `fuse2` as needed (depends on distro)
- **Skips** Cursor installation on non-x86_64 systems

> Note: the Cursor download URL is hard-coded in the script; if Cursor changes it, you may need to update the script.

---

## What it configures

### 1) Default shell → Zsh

The script runs:

- `chsh -s "$(command -v zsh)" "$USER"`

Some environments only apply this after logout/login.

### 2) `~/.zshrc` managed block (idempotent)

At the end of `~/.zshrc`, the script writes a block wrapped in markers:

- `# >>> NAT_BOOTSTRAP_ZSH >>>`
- `# <<< NAT_BOOTSTRAP_ZSH <<<`

If the block already exists, it is **removed and rewritten**, so you won’t get duplicates.

Inside the block it configures:

- `PATH` includes `~/.local/bin` first
- Adds `/usr/lib/ccache` to `PATH` when it exists
- **Starship**:
  ```zsh
  eval "$(starship init zsh)"
  ```
- **NVM** loading:
  ```zsh
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  ```
- **zoxide** init:
  ```zsh
  eval "$(zoxide init zsh)"
  ```
- **fzf** completion + keybindings (sources common distro paths if present)
- **zsh-autosuggestions** (sources system paths or fallback clone)
- **zsh-syntax-highlighting** (must be sourced after other plugins)
- `eza` aliases (`ls`, `ll`) if `eza` exists
- `bat` alias on Debian/Ubuntu if only `batcat` exists
- Interactive-only `fortune | cowsay` with a random `.cow` file

### 3) `bat` command compatibility

On some Debian/Ubuntu variants, `bat` is installed as `batcat`.  
The script creates a user-level shim so `bat` works:

- `~/.local/bin/bat` → points to `batcat`

---

## Node.js installation details

Node is installed via **NVM** (not the distro’s Node packages):

- NVM installed into: `~/.nvm`
- Then the script runs:
  - `nvm install --lts`
  - `nvm alias default 'lts/*'`
  - `corepack enable` (if available)
  - prints `node -v` and `npm -v` during installation

This ensures your default Node is **LTS** and available in new shells.

---

## Verification checklist

After opening a new terminal:

```bash
echo $SHELL
zsh --version
starship --version
nvm --version
node -v
npm -v
rg --version
fzf --version
zoxide --version
eza --version
bat --version || batcat --version
gh --version
flatpak list | head
```

Plugin sanity checks:
- autosuggestions should appear as you type (faint suggestions)
- syntax highlighting should color valid commands

---

## Troubleshooting

### Default shell didn’t change
Some environments only apply shell changes after logout/login.

Try:
```bash
chsh -s "$(command -v zsh)"
```

Then log out/in.

### `nvm` works but `node` is missing
Run:
```bash
nvm install --lts
nvm alias default 'lts/*'
```

### Flatpak apps not showing in menus
Log out/in, or run:
```bash
flatpak update --appstream -y
```

### Cursor AppImage won’t run
You may need FUSE support:
- Debian/Ubuntu: `sudo apt install libfuse2`
- Fedora: `sudo dnf install fuse-libs`
- Arch: `sudo pacman -S fuse2`

---

## Notes & safety

- On APT systems, the script adds 3rd-party repos for **Brave**, **Microsoft Edge**, **GitHub CLI** (fallback), and **Adoptium**.
- Read through the script before running on managed/work devices.

---

## License

Use/modify freely for personal setups. Add an explicit license if you plan to publish.