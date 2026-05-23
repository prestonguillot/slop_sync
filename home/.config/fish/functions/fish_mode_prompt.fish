function fish_mode_prompt --description 'Empty — mode indicator lives on line 2 of fish_prompt'
    # Intentionally empty. We embed the vi-mode indicator inside fish_prompt
    # so it sits on line 2 next to the `>` instead of being prepended to line 1.
    # See conf.d/repaint_on_mode_change.fish for the trigger that keeps it live.
end
