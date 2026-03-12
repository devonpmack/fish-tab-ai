function _fish_tab_ai_suggest --description "Check cache for suggestion + write buffer for daemon"
    set -l buffer (commandline -b)

    if test (string length -- "$buffer") -lt 2
        return
    end

    if not set -q _fish_tab_ai_active
        return
    end

    set -l buf_len (string length -- "$buffer")

    # Client-side prefix cache
    if set -q _fish_tab_ai_cache_buf; and set -q _fish_tab_ai_cache_sug
        set -l full "$_fish_tab_ai_cache_buf$_fish_tab_ai_cache_sug"
        set -l cache_len (string length -- "$_fish_tab_ai_cache_buf")
        if string match -q "$buffer*" -- "$full"; and test $buf_len -ge $cache_len
            set -l remaining (string sub -s (math $buf_len + 1) -- "$full")
            if test -n "$remaining"
                set -g _fish_tab_ai_suggestion "$remaining"
                set -g _fish_tab_ai_original "$buffer"
                # Suppress Fish's native autosuggestion so it doesn't overlap
                commandline -f suppress-autosuggestion
                # Schedule dimmed ghost text after Fish redraws (~15ms)
                printf '%s' "$remaining" > /tmp/fish_tab_ai_ghost
                command sh -c 'sleep 0.015; g=$(cat /tmp/fish_tab_ai_ghost 2>/dev/null); [ -n "$g" ] && printf "\0337\033[K\033[90m%s\033[0m\0338" "$g" > /dev/tty' &
                disown $last_pid 2>/dev/null
            end
        end
    end

    # Write current buffer for daemon file watcher
    printf '%s\t%s\t%s' "$buffer" "$PWD" "$fish_pid" >/tmp/fish_tab_ai_buffer 2>/dev/null
end
