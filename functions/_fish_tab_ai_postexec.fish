function _fish_tab_ai_postexec --description "Track recent commands and trigger next-command prediction"
    set -l exit_code $status

    if not set -q _fish_tab_ai_active
        return
    end

    set -l cmd $argv[1]
    if test -z "$cmd"
        return
    end

    if not set -q _fish_tab_ai_recent
        set -g _fish_tab_ai_recent
    end

    if test $exit_code -ne 0
        set -a _fish_tab_ai_recent "$cmd [FAILED: exit $exit_code]"
    else
        set -a _fish_tab_ai_recent "$cmd"
    end
    if test (count $_fish_tab_ai_recent) -gt 5
        set -e _fish_tab_ai_recent[1]
    end

    printf '%s\n' $_fish_tab_ai_recent > /tmp/fish_tab_ai_recent 2>/dev/null
    printf '\t%s\t%s' "$PWD" "$fish_pid" >/tmp/fish_tab_ai_buffer 2>/dev/null
end
