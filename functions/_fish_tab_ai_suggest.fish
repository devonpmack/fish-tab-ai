function _fish_tab_ai_suggest --description "Write current buffer to daemon for AI completion"
    set -l buffer (commandline -b)

    if test (string length -- "$buffer") -lt 2
        return
    end

    if not set -q _fish_tab_ai_active
        return
    end

    printf '%s\t%s\t%s' "$buffer" "$PWD" "$fish_pid" >/tmp/fish_tab_ai_buffer 2>/dev/null
end
