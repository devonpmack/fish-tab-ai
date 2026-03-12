function _fish_tab_ai_accept --description "Accept full AI suggestion or do normal tab complete"
    if set -q _fish_tab_ai_suggestion; and test -n "$_fish_tab_ai_suggestion"
        commandline -C (string length -- (commandline -b))
        set -e _fish_tab_ai_suggestion
        set -e _fish_tab_ai_original
    else
        commandline -f complete
    end
end
