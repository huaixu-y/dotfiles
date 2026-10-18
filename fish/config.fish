# starship (skip when not installed so startup never fails)
if command -q starship
    starship init fish | source
end

# alias
alias ft=fastfetch
alias vim=nvim

# no welcome message on startup
set -g fish_greeting

# default editor (only when installed, so tools keep their own fallback)
if command -q nvim
    set -gx EDITOR nvim
end
