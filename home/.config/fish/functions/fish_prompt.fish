function fish_prompt --description 'Two-line prompt: identity/path/git on top, mode + > on bottom'
    set -l last_status $status

    # Blank line above each prompt — visually separates previous output from
    # the next prompt. (Counterpart: conf.d/blank_line_before_output.fish
    # injects a blank line between the typed command and its output.)
    echo

    # ── Identity (auto-shrink) ────────────────────────────────────────────
    set -l host (string split -- '.' (prompt_hostname))[1]
    set -l user_full $USER
    set -l host_full $host

    # Compute a worst-case line-1 length with full names. If it'd push past
    # 60% of the terminal width, truncate user→4 chars and host→6 chars.
    set -l pwd_str (prompt_pwd)
    set -l vcs_str (fish_vcs_prompt)
    set -l worst "$user_full@$host_full $pwd_str$vcs_str"
    set -l budget (math --scale=0 "$COLUMNS * 0.6")
    set -l user_show $user_full
    set -l host_show $host_full
    if test (string length -- $worst) -gt $budget
        set user_show (string sub -l 4 -- $user_full)
        set host_show (string sub -l 6 -- $host_full)
    end

    # ── Line 1: user@host  pwd  (git status)  [exit] ──────────────────────
    set_color normal
    echo -n -s $user_show '@' $host_show ' '
    set_color $fish_color_cwd
    echo -n -s $pwd_str
    set_color normal
    echo -n -s $vcs_str
    if test $last_status -ne 0
        set_color $fish_color_status
        echo -n -s ' ['$last_status']'
        set_color normal
    end

    # ── Line 2: [mode] > ──────────────────────────────────────────────────
    echo
    switch $fish_bind_mode
        case insert
            set_color brcyan
            echo -n '[I]'
        case default
            set_color bryellow
            echo -n '[N]'
        case replace replace_one
            set_color brred
            echo -n '[R]'
        case visual
            set_color brmagenta
            echo -n '[V]'
        case '*'
            echo -n '['$fish_bind_mode']'
    end
    set_color normal
    echo -n ' > '
end
