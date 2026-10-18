# starship (skip when not installed so startup never fails)
if command -q starship
    starship init fish | source
end

# alias
alias ft=fastfetch
alias vim=nvim

# default editor (only when installed, so tools keep their own fallback)
if command -q nvim
    set -gx EDITOR nvim
end
