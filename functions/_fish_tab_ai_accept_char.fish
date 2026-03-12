function _fish_tab_ai_accept_char --description "Accept one character of AI suggestion or move forward"
    if set -q _fish_tab_ai_suggestion; and test -n "$_fish_tab_ai_suggestion"
        set -l pos (commandline -C)
        commandline -C (math $pos + 1)
        set -g _fish_tab_ai_original (string sub -l (math $pos + 1) -- (commandline -b))
        set -g _fish_tab_ai_suggestion (string sub -s 2 -- "$_fish_tab_ai_suggestion")
        if test -z "$_fish_tab_ai_suggestion"
            set -e _fish_tab_ai_suggestion
            set -e _fish_tab_ai_original
        end
    else
        commandline -f forward-char
    end
end
