function pj --description 'Jump to a git project picked with fzf, optionally as a tmux session'
    argparse t/tmux h/help -- $argv
    or return 2
    if set -q _flag_help
        echo 'usage: pj [-t|--tmux] [query]'
        echo 'Searches $PJ_ROOTS, or ~/code ~/projects ~/src ~/work, for git repositories.'
        return 0
    end
    if not command -q fd; or not command -q fzf
        echo 'pj: needs fd and fzf' >&2
        return 1
    end

    set -l candidates ~/code ~/projects ~/src ~/work
    set -q PJ_ROOTS[1]; and set candidates $PJ_ROOTS
    set -l roots
    for dir in $candidates
        test -d $dir; and set -a roots $dir
    end
    if not set -q roots[1]
        echo "pj: none of $candidates exists; set PJ_ROOTS" >&2
        return 1
    end

    set -l project (fd --hidden --type d --max-depth 4 --prune --exclude node_modules --exclude .venv '^\.git$' $roots 2>/dev/null \
        | string replace -r '/\.git/?$' '' \
        | sort -u \
        | fzf --query "$argv" --select-1 --exit-0 --prompt 'project> ' \
            --preview 'git -C {} log --oneline --color=always -15 2>/dev/null')
    or return 1

    if not set -q _flag_tmux
        cd $project
        return
    end

    set -l session (string replace -ra '[^[:alnum:]_-]' '_' -- (path basename $project))
    if not tmux has-session -t "=$session" 2>/dev/null
        tmux new-session -d -s $session -c $project
    end
    if set -q TMUX
        tmux switch-client -t "=$session"
    else
        tmux attach-session -t "=$session"
    end
end
