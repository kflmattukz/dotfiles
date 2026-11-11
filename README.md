# dotfiles

Fedora + GNOME configs, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level folder is a stow package that mirrors `$HOME`.

## New machine

```sh
sudo dnf install -y git
git clone <this repo> ~/code/dotfiles
cd ~/code/dotfiles
./install.sh          # repos, dnf, flatpaks, tools, stow, dconf, systemd
```

Re-link only: `./install.sh stow`. Single package: `stow mpv`.

## Packages

| Package | Target |
|---|---|
| `zsh`, `bash` | `~/.zshrc`, `~/.bashrc`, `~/.bashrc.d/`, `~/.profile`, `~/.bash_profile` |
| `git` | `~/.gitconfig` (includes untracked `~/.gitconfig.local`) |
| `ghostty`, `starship`, `nvim`, `zed`, `vscode` | under `~/.config/` |
| `claude` | `~/.claude/settings.json`, `~/.claude/skills/`, `~/.agents/` |
| `gtk`, `mimeapps`, `systemd` | under `~/.config/` |
| `mpv`, `mini-eq`, `obsidian` | flatpak config under `~/.var/app/<app-id>/config/` |

Not stowed:

- `dconf/`: GNOME settings. Restore with `./install.sh stow`. Re-export with `dconf/dump.sh`, which strips gsconnect pairing and tokens.
- `packages.txt`, `flatpaks.txt`: lists that `install.sh` installs from. Refresh flatpaks with `flatpak list --app --columns=application > flatpaks.txt`.

## Kept out on purpose (public repo)

- `~/.ssh/` (keys and config)
- `~/.gitconfig.local`, `~/.gitconfig_bgn`, `~/.gitconfig_jasindo`: work identities. Recreate them by hand. `.gitconfig.local` holds the `includeIf` blocks.
- Browser and Electron app profiles (Chrome, Helium, Teams, Claude Desktop), Spotify prefs (they hold login credentials)
- Fonts in `~/.local/share/fonts`, wallpapers

## Notes

- Clone to `~/code/dotfiles`: the mini-eq flatpak override grants exactly that path.
- `.stowrc` sets `--no-folding`. New files an app creates inside a stowed dir are **not** tracked automatically. Move them in and re-stow.
- Some apps save by replacing the file, which turns the symlink back into a regular file (watch `mimeapps.list`). Check with `git status`. Fix with `stow --adopt <pkg>`, then review `git diff`.
