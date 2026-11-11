# ---------- History ----------
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT INTERACTIVE_COMMENTS
bindkey -e

# ---------- Toolchains (shared with bash) ----------
# PATH for Rust, Go, fnm/Node, pnpm, SDKMAN/Java
source ~/.bashrc.d/10-devtools.sh

# ---------- fzf (Ctrl+T files, Alt+C dirs, Ctrl+R history) ----------
export FZF_DEFAULT_OPTS="--height=60% --layout=reverse --border=rounded --info=inline \
  --color=bg+:#283457,bg:-1,spinner:#7dcfff,hl:#f7768e,fg:#c0caf5,header:#7aa2f7 \
  --color=info:#bb9af7,pointer:#7dcfff,marker:#9ece6a,fg+:#c0caf5,prompt:#7aa2f7,hl+:#f7768e \
  --bind=ctrl-/:toggle-preview"
if command -v fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons --group-directories-first {}'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"

# ---------- zinit ----------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# Completions must load before compinit
zinit light zsh-users/zsh-completions

# Oh-My-Zsh snippets (no full OMZ install)
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git                  # git aliases: gst, gco, gp, glog...
zinit snippet OMZP::sudo                 # press Esc twice to prefix sudo
zinit snippet OMZP::command-not-found
zinit snippet OMZP::extract              # `extract file.tar.gz`
zinit snippet OMZP::copypath             # copy current dir path to clipboard

# Init completion system once, then replay zinit's queued compdefs
autoload -Uz compinit && compinit
zinit cdreplay -q

# fzf-tab: after compinit, before plugins that wrap widgets
zinit light Aloxaf/fzf-tab

# Deferred (turbo) for fast startup
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
YSU_IGNORED_ALIASES=(ls)   # eza aliases (l, ll, la...) all start with `ls`'s value
zinit wait lucid for \
  atload'_zsh_autosuggest_start' \
    zsh-users/zsh-autosuggestions \
  zdharma-continuum/fast-syntax-highlighting \
  atload'bindkey "^[[A" history-substring-search-up; bindkey "^[[B" history-substring-search-down;
         bindkey "^p" history-substring-search-up; bindkey "^n" history-substring-search-down' \
    zsh-users/zsh-history-substring-search \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use

# ---------- Completion styling ----------
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# ---------- fzf-tab previews ----------
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
# Directory -> eza listing, file -> bat with syntax highlight
zstyle ':fzf-tab:complete:*:*' fzf-preview \
  '[[ -d $realpath ]] && eza -1 --color=always --icons --group-directories-first --git $realpath \
   || { [[ -f $realpath ]] && bat --color=always --style=numbers --line-range=:200 $realpath; }'
zstyle ':fzf-tab:complete:(cd|__zoxide_z|__zoxide_zi):*' fzf-preview \
  'eza --tree --level=2 --color=always --icons --group-directories-first $realpath'
# Processes for kill
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
# Git: show the diff / log of what you are completing
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always $word'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
  'git log --color=always --oneline --graph -20 $word 2>/dev/null'
# Env vars: show the value
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
  fzf-preview 'echo ${(P)word}'

# ---------- Keybindings ----------
# Up/Down history search: bound in the zinit atload above (widget must exist first)
bindkey '^ ' autosuggest-accept           # Ctrl+Space accepts the hint
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3~' delete-char
bindkey '^H' backward-kill-word           # Ctrl+Backspace

# ---------- Tools ----------
command -v fzf    >/dev/null && source <(fzf --zsh)

# ---------- Aliases ----------
if command -v eza >/dev/null; then
  _eza='eza --icons=auto --group-directories-first'
  alias ls="$_eza"
  alias l="$_eza -l --git --no-user --no-permissions --time-style=relative"
  alias ll="$_eza -lh --git --time-style=long-iso"
  alias la="$_eza -lah --git --time-style=long-iso"
  alias lt="$_eza --tree --level=2 --git-ignore"
  alias ltt="$_eza --tree --level=3 --git-ignore -l --git --no-user --no-permissions"
  alias tree="$_eza --tree"
  alias lg="$_eza -l --git --git-repos --no-user --no-permissions"   # dirs: show repo status
else
  alias ll='ls -lah --color=auto --group-directories-first'
fi
command -v bat >/dev/null && alias cat='bat --paging=never' && export MANPAGER="sh -c 'col -bx | bat -l man -p'" MANROFFOPT='-c'
alias ..='cd ..' ...='cd ../..' ....='cd ../../..'
alias g='git' gs='git status -sb' gd='git diff' gl='git log --oneline --graph --decorate'
alias p='pnpm' px='pnpm dlx'
alias reload='exec zsh'
alias v='nvim'
alias warp-on='warp-cli connect && sleep 2 && warp-cli status'   # Cloudflare WARP: route around ISP blocks
alias warp-off='warp-cli disconnect && warp-cli status'

# ---------- Prompt ----------
eval "$(starship init zsh)"

# zoxide must stay last (it hooks the prompt)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"   # `z foo` jumps, `z foo<Space><Tab>` picks; plain `cd` is builtin

# pnpm
export PNPM_HOME='/home/mattukz/.local/share/pnpm'
case ":$PATH:" in
  ":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
