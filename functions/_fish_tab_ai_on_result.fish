function _fish_tab_ai_on_result --description "Handle SIGUSR1 - show inline suggestion"
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
    if test (count $parts) -lt 2
        return
    end

    set -l orig_buf $parts[1]
    set -l suggestion $parts[2]

    set -g _fish_tab_ai_cache_buf "$orig_buf"
    set -g _fish_tab_ai_cache_sug "$suggestion"

    # Get actual user buffer (strip existing suggestion if showing)
    set -l buffer (commandline -b)
    if set -q _fish_tab_ai_original
        set buffer "$_fish_tab_ai_original"
    end

    set -l buf_len (string length -- "$buffer")
    if test $buf_len -lt 2
        return
    end

    set -l full "$orig_buf$suggestion"
    if not string match -q "$buffer*" -- "$full"
        return
    end

    if test "$full" = "$buffer"
        return
    end

    set -l remaining (string sub -s (math $buf_len + 1) -- "$full")
    if test -z "$remaining"
        return
    end

    set -g _fish_tab_ai_suggestion "$remaining"
    set -g _fish_tab_ai_original "$buffer"
    commandline -r -- "$buffer$remaining"
    commandline -C $buf_len
end
