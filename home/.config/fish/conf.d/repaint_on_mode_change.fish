# Since fish_mode_prompt is empty and the mode indicator is baked into
# fish_prompt's second line, fish's normal mode-change repaint path
# (which only refreshes the mode area) doesn't update us. Force a full
# prompt repaint whenever $fish_bind_mode changes.

function __dotfiles_repaint_on_mode --on-variable fish_bind_mode
    commandline -f repaint
end
