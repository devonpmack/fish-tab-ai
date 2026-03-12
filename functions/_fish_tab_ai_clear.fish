function _fish_tab_ai_clear --description "Clear ghost text from display and state"
    if set -q _fish_tab_ai_suggestion
        # Erase the dimmed ghost text from the terminal
        printf '\e7\e[K\e8'
        set -e _fish_tab_ai_suggestion
        set -e _fish_tab_ai_original
        printf '' > /tmp/fish_tab_ai_ghost 2>/dev/null
    end
end
