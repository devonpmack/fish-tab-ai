# fish-tab-ai: AI-powered inline tab completions
# Auto-activates if daemon is already running, otherwise run `fish_tab_ai start`.

function _fish_tab_ai_bind --description "Activate inline ghost text key bindings"
    # Each key: clear existing ghost text → insert char → check for new suggestion
    set -l prefix '_fish_tab_ai_clear; commandline -i'
    set -l suffix '; _fish_tab_ai_suggest'

    for c in a b c d e f g h i j k l m n o p q r s t u v w x y z
        bind $c "$prefix $c$suffix"
    end
    for c in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
        bind $c "$prefix $c$suffix"
    end
    for c in 0 1 2 3 4 5 6 7 8 9
        bind $c "$prefix $c$suffix"
    end

    bind '.' "$prefix '.'$suffix"
    bind '/' "$prefix '/'$suffix"
    bind '_' "$prefix '_'$suffix"
    bind '=' "$prefix '='$suffix"
    bind '+' "$prefix '+'$suffix"
    bind '~' "$prefix '~'$suffix"
    bind '!' "$prefix '!'$suffix"
    bind '@' "$prefix '@'$suffix"
    bind '#' "$prefix '#'$suffix"
    bind '%' "$prefix '%'$suffix"
    bind '^' "$prefix '^'$suffix"
    bind '&' "$prefix '&'$suffix"
    bind '*' "$prefix '*'$suffix"
    bind '(' "$prefix '('$suffix"
    bind ')' "$prefix ')'$suffix"
    bind '[' "$prefix '['$suffix"
    bind ']' "$prefix ']'$suffix"
    bind '{' "$prefix '{'$suffix"
    bind '}' "$prefix '}'$suffix"
    bind '|' "$prefix '|'$suffix"
    bind ':' "$prefix ':'$suffix"
    bind ';' "$prefix ';'$suffix"
    bind '<' "$prefix '<'$suffix"
    bind '>' "$prefix '>'$suffix"
    bind '?' "$prefix '?'$suffix"
    bind '`' "$prefix '`'$suffix"

    bind space "$prefix ' '$suffix"
    bind minus "$prefix '-'$suffix"
    bind comma "$prefix ','$suffix"
    bind '"' "$prefix '\"'$suffix"
    bind "'" "$prefix \"'\"$suffix"
    bind '$' "$prefix '\$'$suffix"
    bind '\\' "$prefix '\\\\'$suffix"

    bind backspace '_fish_tab_ai_clear; commandline -f backward-delete-char; _fish_tab_ai_suggest'
    bind delete '_fish_tab_ai_clear; commandline -f delete-char; _fish_tab_ai_suggest'

    bind tab _fish_tab_ai_accept
    bind right _fish_tab_ai_accept_char
    bind ctrl-f _fish_tab_ai_accept_char
    bind ctrl-e _fish_tab_ai_accept_all

    bind enter '_fish_tab_ai_clear; commandline -f execute'
    bind up '_fish_tab_ai_clear; commandline -f up-or-search'
    bind down '_fish_tab_ai_clear; commandline -f down-or-search'
    bind left '_fish_tab_ai_clear; commandline -f backward-char'
    bind ctrl-a '_fish_tab_ai_clear; commandline -f beginning-of-line'
    bind ctrl-k '_fish_tab_ai_clear; commandline -f kill-line'
    bind ctrl-u '_fish_tab_ai_clear; commandline -f backward-kill-line'
    bind ctrl-w '_fish_tab_ai_clear; commandline -f backward-kill-word'
    bind ctrl-c '_fish_tab_ai_clear; commandline -f cancel-commandline'
    bind ctrl-d '_fish_tab_ai_clear; commandline -f delete-or-exit'

    function _fish_tab_ai_signal_handler --on-signal SIGUSR1
        _fish_tab_ai_on_result
    end

end

function _fish_tab_ai_unbind --description "Restore default key bindings"
    for c in a b c d e f g h i j k l m n o p q r s t u v w x y z \
             A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
             0 1 2 3 4 5 6 7 8 9
        bind --erase $c
    end
    for c in '.' '/' '_' '=' '+' '~' '!' '@' '#' '$' '%' '^' '&' '*' \
             '(' ')' '[' ']' '{' '}' '|' ':' ';' '<' '>' '?' '`' '\\'
        bind --erase -- $c
    end
    bind --erase space
    bind --erase minus
    bind --erase comma
    bind --erase '"'
    bind --erase "'"
    bind --erase '$'
    bind --erase backspace
    bind --erase delete
    bind --erase tab
    bind --erase right
    bind --erase ctrl-f
    bind --erase ctrl-e
    bind --erase enter
    bind --erase up
    bind --erase down
    bind --erase left
    bind --erase ctrl-a
    bind --erase ctrl-k
    bind --erase ctrl-u
    bind --erase ctrl-w
    bind --erase ctrl-c
    bind --erase ctrl-d

    functions --erase _fish_tab_ai_signal_handler 2>/dev/null
end

# Register postexec handler at top level (must be outside functions for event to fire)
function _fish_tab_ai_postexec_handler --on-event fish_postexec
    _fish_tab_ai_postexec $argv
end

# Auto-install daemon if missing (supports Fisher install)
function _fish_tab_ai_ensure_daemon
    set -l daemon_dir ~/.local/share/fish-tab-ai/daemon
    if test -f "$daemon_dir/server.py"
        return 0
    end

    # Find source daemon dir relative to this conf.d file
    set -l conf_dir (status dirname)
    set -l source_dir "$conf_dir/../daemon"
    if not test -d "$source_dir"
        # Fisher stores repos in ~/.local/share/fisher or data dir
        for d in (find ~/.local/share/fish/vendor_conf.d/.. -name daemon -path "*/fish-tab-ai/*" 2>/dev/null) \
                 (find ~/.config/fish/.. -name daemon -path "*/fish-tab-ai/*" 2>/dev/null)
            if test -f "$d/server.py"
                set source_dir "$d"
                break
            end
        end
    end

    if test -f "$source_dir/server.py"
        mkdir -p (dirname "$daemon_dir")
        cp -r "$source_dir" "$daemon_dir"
        mkdir -p ~/.local/state/fish-tab-ai
        return 0
    end
    return 1
end

# Auto-activate on interactive shell startup
if status is-interactive
    if command curl -s --connect-timeout 0.05 --max-time 0.1 http://localhost:62019/health >/dev/null 2>&1
        set -g _fish_tab_ai_active 1
        _fish_tab_ai_bind
    else if _fish_tab_ai_ensure_daemon
        set -l _daemon_dir ~/.local/share/fish-tab-ai/daemon

        # Start Ollama if not running
        if not command curl -s --connect-timeout 0.1 --max-time 0.2 http://localhost:11434/api/tags >/dev/null 2>&1
            command ollama serve &>/dev/null &
            disown $last_pid 2>/dev/null
            command sleep 1
        end

        # Pull model if needed
        if command -v ollama >/dev/null 2>&1
            if not ollama list 2>/dev/null | string match -q "*qwen2.5-coder*"
                ollama pull qwen2.5-coder:1.5b &>/dev/null &
                disown $last_pid 2>/dev/null
            end
        end

        python3 "$_daemon_dir/server.py" 62019 "qwen2.5-coder:1.5b" &>/dev/null &
        disown $last_pid 2>/dev/null
        for _i in (seq 1 10)
            if command curl -s --connect-timeout 0.05 --max-time 0.1 http://localhost:62019/health >/dev/null 2>&1
                set -g _fish_tab_ai_active 1
                _fish_tab_ai_bind
                break
            end
            command sleep 0.2
        end
    end
end
