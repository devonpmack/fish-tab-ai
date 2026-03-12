function _fish_tab_ai_on_keypress --description "Wrap keypress: clear ghost, do action, maybe suggest"
    _fish_tab_ai_clear
    commandline -f $argv[1]

    switch $argv[1]
        case self-insert backward-delete-char delete-char
            _fish_tab_ai_suggest
    end
end
