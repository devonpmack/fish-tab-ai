function _fish_tab_ai_accept_or_forward --description "Accept full AI suggestion or move cursor forward"
    if set -q _fish_tab_ai_suggestion; and test -n "$_fish_tab_ai_suggestion"
        commandline -i -- "$_fish_tab_ai_suggestion"
        set -e _fish_tab_ai_suggestion
        set -e _fish_tab_ai_original
        printf '' > /tmp/fish_tab_ai_ghost 2>/dev/null
    else
        commandline -f forward-char
    end
end
