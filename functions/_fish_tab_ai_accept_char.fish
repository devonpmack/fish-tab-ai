function _fish_tab_ai_accept_char --description "Accept one character of AI suggestion or move forward"
    if set -q _fish_tab_ai_suggestion; and test -n "$_fish_tab_ai_suggestion"
        commandline -i -- (string sub -l 1 -- "$_fish_tab_ai_suggestion")
        set -g _fish_tab_ai_suggestion (string sub -s 2 -- "$_fish_tab_ai_suggestion")
        if test -z "$_fish_tab_ai_suggestion"
            set -e _fish_tab_ai_suggestion
            set -e _fish_tab_ai_original
            printf '' > /tmp/fish_tab_ai_ghost 2>/dev/null
        else
            # Schedule dimmed ghost text for remaining suggestion
            printf '%s' "$_fish_tab_ai_suggestion" > /tmp/fish_tab_ai_ghost
            commandline -f suppress-autosuggestion
            command sh -c 'sleep 0.015; g=$(cat /tmp/fish_tab_ai_ghost 2>/dev/null); [ -n "$g" ] && printf "\0337\033[K\033[90m%s\033[0m\0338" "$g" > /dev/tty' &
            disown $last_pid 2>/dev/null
        end
    else
        commandline -f forward-char
    end
end
