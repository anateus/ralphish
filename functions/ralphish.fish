function ralphish --description "Ralph Wiggum Loop dispatcher"
    set -l mode "claude"
    if set -q _ralphish_type
        set mode (string lower -- $_ralphish_type)
    end

    switch $mode
        case codex
            ralphish-codex $argv
        case claude
            ralphish-claude $argv
        case '*'
            echo "Unknown _ralphish_type '$mode'. Expected 'claude' or 'codex'. Falling back to claude." >&2
            ralphish-claude $argv
    end
end
