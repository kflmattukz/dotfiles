# Dev toolchains (managed by ~/.bashrc.d/10-devtools.sh)
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim VISUAL=nvim

# Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# fnm (Node): auto-switch on cd when .nvmrc/.node-version exists
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --shell "$([ -n "$ZSH_VERSION" ] && echo zsh || echo bash)")"
fi

# pnpm global bin
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in *":$PNPM_HOME/bin:"*) ;; *) export PATH="$PNPM_HOME/bin:$PATH" ;; esac

# Podman: Docker API for compose, Dev Containers, Testcontainers
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"

# SDKMAN (must stay last)
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
