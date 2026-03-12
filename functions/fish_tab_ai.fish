function fish_tab_ai --description "Manage fish-tab-ai (start|stop|restart|status)"
    set -l cmd $argv[1]
    set -l pid_file ~/.local/state/fish-tab-ai/daemon.pid
    set -l port 62019
    # Resolve daemon dir relative to this function file
    set -l func_dir (status dirname)
    set -l daemon_dir "$func_dir/../daemon"
    if not test -d "$daemon_dir"
        set daemon_dir ~/.local/share/fish-tab-ai/daemon
    end

    switch "$cmd"
        case start
            set -l model "qwen2.5-coder:1.5b"
            if set -q argv[2]
                set model $argv[2]
            end

            if _fish_tab_ai_daemon_alive
                echo "fish-tab-ai daemon already running"
                if not set -q _fish_tab_ai_active
                    set -g _fish_tab_ai_active 1
                    _fish_tab_ai_bind
                    echo "Key bindings activated"
                end
                return 0
            end

            if not test -f "$daemon_dir/server.py"
                echo "Error: daemon not found at $daemon_dir"
                echo "Run install.sh first"
                return 1
            end

            # Start Ollama if not running
            if not command curl -s --connect-timeout 0.1 --max-time 0.2 http://localhost:11434/api/tags >/dev/null 2>&1
                echo "Starting Ollama..."
                command ollama serve &>/dev/null &
                disown $last_pid 2>/dev/null
                sleep 2
            end

            echo "Starting daemon (model: $model)..."
            python3 "$daemon_dir/server.py" $port $model &
            disown $last_pid

            for i in (seq 1 20)
                if _fish_tab_ai_daemon_alive
                    set -g _fish_tab_ai_active 1
                    _fish_tab_ai_bind
                    echo "Daemon started (pid "(cat $pid_file)")"
                    command sh -c "curl -s --max-time 30 'http://localhost:$port/complete?buffer=git%20st&cwd=/tmp' >/dev/null 2>&1" &
                    disown $last_pid 2>/dev/null
                    echo "Warming up model..."
                    return 0
                end
                sleep 0.5
            end
            echo "Failed to start daemon"
            return 1

        case stop
            _fish_tab_ai_unbind
            set -e _fish_tab_ai_active
            command rm -f /tmp/fish_tab_ai_buffer /tmp/fish_tab_ai_result /tmp/fish_tab_ai_result.tmp /tmp/fish_tab_ai_ghost /tmp/fish_tab_ai_recent 2>/dev/null

            _fish_tab_ai_kill_daemon

        case restart
            set -l model "qwen2.5-coder:1.5b"
            if set -q argv[2]
                set model $argv[2]
            end

            _fish_tab_ai_unbind
            set -e _fish_tab_ai_active
            command rm -f /tmp/fish_tab_ai_buffer /tmp/fish_tab_ai_result /tmp/fish_tab_ai_result.tmp /tmp/fish_tab_ai_ghost /tmp/fish_tab_ai_recent 2>/dev/null
            _fish_tab_ai_kill_daemon
            sleep 1

            fish_tab_ai start $model

        case status
            if _fish_tab_ai_daemon_alive
                echo "fish-tab-ai: running (pid "(cat $pid_file)")"
                if set -q _fish_tab_ai_active
                    echo "Key bindings: active"
                else
                    echo "Key bindings: inactive (run: fish_tab_ai start)"
                end
            else
                echo "fish-tab-ai: not running"
            end

        case '*'
            echo "Usage: fish_tab_ai (start [model]|stop|restart|status)"
    end
end

function _fish_tab_ai_daemon_alive
    command curl -s --connect-timeout 0.05 --max-time 0.1 http://localhost:62019/health >/dev/null 2>&1
end

function _fish_tab_ai_kill_daemon --description "Kill daemon process and anything on its port"
    set -l pid_file ~/.local/state/fish-tab-ai/daemon.pid
    set -l port 62019

    if test -f $pid_file
        set -l pid (cat $pid_file)
        kill $pid 2>/dev/null
        echo "Sent SIGTERM to daemon (pid $pid)"
    end

    # Also kill anything still holding the port
    for stale_pid in (command lsof -ti :$port 2>/dev/null)
        kill -9 $stale_pid 2>/dev/null
    end

    command rm -f $pid_file
end
