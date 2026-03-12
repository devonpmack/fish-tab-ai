function _fish_tab_ai_on_result --description "Handle SIGUSR1 - show dimmed inline suggestion"
    if not set -q _fish_tab_ai_active
        return
    end

    set -l result_file /tmp/fish_tab_ai_result
    if not test -f $result_file
        return
    end

    set -l line ""
    read -l line < $result_file

    if test -z "$line"
        return
    end

    set -l parts (string split \t -- $line)
    set -l orig_buf ""
    set -l suggestion ""

    if test (count $parts) -ge 2
        set orig_buf $parts[1]
        set suggestion $parts[2]
    else if test (count $parts) -eq 1
        set suggestion $parts[1]
    end

    if test -z "$suggestion"
        return
    end

    set -l buffer (commandline -b)
    set -l buf_len (string length -- "$buffer")

    set -l full "$orig_buf$suggestion"

    if test $buf_len -gt 0
        if not string match -q "$buffer*" -- "$full"
            return
        end
    end

    set -l remaining (string sub -s (math $buf_len + 1) -- "$full")
    if test -z "$remaining"
        return
    end

    set -g _fish_tab_ai_suggestion "$remaining"
    set -g _fish_tab_ai_original "$buffer"

    if test $buf_len -eq 0
        # Empty prompt: schedule ghost text after Fish finishes redrawing
        printf '%s' "$remaining" > /tmp/fish_tab_ai_ghost
        command sh -c 'sleep 0.1; g=$(cat /tmp/fish_tab_ai_ghost 2>/dev/null); [ -n "$g" ] && printf "\0337\033[K\033[90m%s\033[0m\0338" "$g" > /dev/tty' &
        disown $last_pid 2>/dev/null
    else
        commandline -f suppress-autosuggestion
        printf '\e7\e[K\e[90m%s\e[0m\e8' "$remaining"
    end
end
