function _fish_tab_ai_suggest --description "Check cache for suggestion + write buffer for daemon"
    set -l buffer (commandline -b)

    if test (string length -- "$buffer") -lt 2
        return
    end

    if not set -q _fish_tab_ai_active
        return
    end

    set -l buf_len (string length -- "$buffer")

    # Client-side prefix cache: if daemon already returned a longer suggestion, extend it
    if set -q _fish_tab_ai_cache_buf; and set -q _fish_tab_ai_cache_sug
        set -l full "$_fish_tab_ai_cache_buf$_fish_tab_ai_cache_sug"
        set -l cache_len (string length -- "$_fish_tab_ai_cache_buf")
        if string match -q "$buffer*" -- "$full"; and test $buf_len -ge $cache_len
            set -l remaining (string sub -s (math $buf_len + 1) -- "$full")
            if test -n "$remaining"
                set -g _fish_tab_ai_suggestion "$remaining"
                set -g _fish_tab_ai_original "$buffer"
                commandline -r -- "$buffer$remaining"
                commandline -C $buf_len
            end
        end
    end

    # Write current buffer for daemon file watcher
    printf '%s\t%s\t%s' "$buffer" "$PWD" "$fish_pid" >/tmp/fish_tab_ai_buffer 2>/dev/null
end
