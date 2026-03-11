function _ralphish_on_install --on-event ralphish_install
    if not status is-interactive
        return
    end

    if set -q _ralphish_type
        return
    end

    echo "ralphish: choose backend for the 'ralphish' command"

    while true
        read -l -P "Use [codex/claude] (default: codex): " choice
        if test -z "$choice"
            set choice codex
        end
        set choice (string lower -- $choice)

        switch $choice
            case codex claude
                set -U _ralphish_type $choice
                echo "ralphish: set _ralphish_type=$_ralphish_type"
                return
            case '*'
                echo "Please enter 'codex' or 'claude'."
        end
    end
end
