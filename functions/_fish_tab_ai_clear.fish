function _fish_tab_ai_clear --description "Clear ghost text state"
    if set -q _fish_tab_ai_suggestion
        set -e _fish_tab_ai_suggestion
        set -e _fish_tab_ai_original
        # Prevent stale background process from rendering old ghost text
        printf '' > /tmp/fish_tab_ai_ghost 2>/dev/null
    end
end
