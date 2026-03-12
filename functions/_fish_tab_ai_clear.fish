function _fish_tab_ai_clear --description "Clear inline ghost text from commandline"
    if set -q _fish_tab_ai_suggestion
        commandline -r -- "$_fish_tab_ai_original"
        set -e _fish_tab_ai_suggestion
        set -e _fish_tab_ai_original
    end
end
