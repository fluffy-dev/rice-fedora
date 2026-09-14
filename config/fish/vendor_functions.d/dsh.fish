function dsh --description 'Open a shell in a running container, picked with fzf when not named'
    set -l container $argv[1]
    if test -z "$container"
        set container (docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' \
            | fzf --delimiter \t --select-1 --exit-0 --prompt 'container> ' \
            | string split -f1 \t)
        or return 1
    end
    docker exec -it $container sh -c 'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'
end
