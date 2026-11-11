#!/usr/bin/env bash
# Bootstrap a fresh Fedora machine from this repo. Safe to re-run.
# Usage: ./install.sh            everything
#        ./install.sh stow       only (re)link configs + load dconf
set -euo pipefail
cd "$(dirname "$0")"
DOTFILES=$PWD
has() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n==> %s\n' "$*"; }

repos() {
  step "dnf repos"
  if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' |
      sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
  fi
  [ -f /etc/yum.repos.d/cloudflare-warp.repo ] ||
    curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo |
      sudo tee /etc/yum.repos.d/cloudflare-warp.repo >/dev/null
}

packages() {
  step "dnf packages"
  grep -vE '^\s*(#|$)' packages.txt | xargs sudo dnf install -y
}

flatpaks() {
  step "flatpaks"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  xargs flatpak install --user -y --noninteractive flathub < flatpaks.txt
}

tools() {
  step "tools outside dnf"
  mkdir -p ~/.local/bin
  has starship || curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin
  has zed      || curl -fsSL https://zed.dev/install.sh | sh
  has claude   || curl -fsSL https://claude.ai/install.sh | bash
  [ -x ~/.cargo/bin/rustup ] ||
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # --skip-shell / rcupdate=false: shell setup already lives in bash/.bashrc.d/10-devtools.sh
  if [ ! -x ~/.local/share/fnm/fnm ]; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir ~/.local/share/fnm
    ~/.local/share/fnm/fnm install --lts   # pnpm comes from corepack (enabled in 10-devtools.sh)
  fi
  [ -d ~/.sdkman ] || curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash
  # zinit + zsh plugins self-install on first zsh start (see zsh/.zshrc)
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo usermod -s "$(command -v zsh)" "$USER"
}

link() {
  step "stow"
  # .stowrc sets --target=~ --no-folding. No folding matters: otherwise a missing
  # ~/.claude or ~/.var/app/<id> becomes one symlink into the repo and app state lands in git.
  local pkgs=()
  for d in */; do d=${d%/}; [ "$d" = dconf ] || pkgs+=("$d"); done
  stow --restow "${pkgs[@]}"

  step "dconf"
  dconf load /org/gnome/desktop/ < dconf/desktop.ini
  dconf load /org/gnome/shell/ < dconf/shell.ini
  [ -s dconf/media-keys.ini ] && dconf load /org/gnome/settings-daemon/plugins/media-keys/ < dconf/media-keys.ini
  true
}

services() {
  step "systemd user units"
  systemctl --user daemon-reload
  systemctl --user enable --now podman.socket
  systemctl --user list-unit-files warp-desktop-svc.service >/dev/null 2>&1 &&
    systemctl --user enable warp-desktop-svc.service
  true
}

case "${1:-all}" in
  stow) link ;;
  all)  repos; packages; flatpaks; tools; link; services
        step "done. Create ~/.gitconfig.local for work identities (see README), then log out/in." ;;
  *)    echo "usage: $0 [all|stow]" >&2; exit 1 ;;
esac
echo "dotfiles: $DOTFILES"
