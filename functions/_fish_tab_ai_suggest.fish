function _fish_tab_ai_suggest --description "Check for AI suggestion + write buffer for daemon"
    set -l buffer (commandline -b)

    if test (string length -- "$buffer") -lt 2
        return
    end

    if not set -q _fish_tab_ai_active
        return
    end

    set -l buf_len (string length -- "$buffer")
    set -l found 0

    # 1. Client-side prefix cache
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
                set found 1
            end
        end
    end

    # 2. Check daemon result file
    if test $found -eq 0
        set -l result_file /tmp/fish_tab_ai_result
        if test -f $result_file
            set -l line ""
            read -l line < $result_file

            if test -n "$line"
                set -l parts (string split \t -- $line)
                if test (count $parts) -ge 2
                    set -l orig_buf $parts[1]
                    set -l suggestion $parts[2]

                    set -g _fish_tab_ai_cache_buf "$orig_buf"
                    set -g _fish_tab_ai_cache_sug "$suggestion"

                    set -l full "$orig_buf$suggestion"
                    if string match -q "$buffer*" -- "$full"
                        set -l remaining (string sub -s (math $buf_len + 1) -- "$full")
                        if test -n "$remaining"
                            set -g _fish_tab_ai_suggestion "$remaining"
                            set -g _fish_tab_ai_original "$buffer"
                            commandline -r -- "$buffer$remaining"
                            commandline -C $buf_len
                            set found 1
                        end
                    end
                end
            end
        end
    end

    # 3. Write current buffer for daemon file watcher
    printf '%s\t%s\t%s' "$buffer" "$PWD" "$fish_pid" >/tmp/fish_tab_ai_buffer 2>/dev/null
end
