#!/usr/bin/env bash
# Claude Code status line: model, location from the git root, branch, context use,
# session cost, lines changed and the five-hour rate limit, in the rice palette.
#
# The colour tokens below are filled in from config/palette.env when phase 62 deploys
# this as ~/.claude/statusline.sh. Claude Code pipes a JSON snapshot to stdin on
# every update and cancels a run still in flight when the next one starts, so this
# makes one jq call and at most two git calls. Any field may be missing: a missing
# field drops its segment, and nothing is ever written to stderr.
set -uo pipefail
exec 2>/dev/null

color() { printf -v "$1" '\033[38;2;%d;%d;%dm' "0x${2:1:2}" "0x${2:3:2}" "0x${2:5:2}"; }

if [[ -n "${NO_COLOR:-}" ]]; then
    ACCENT="" DIM="" BLUE="" MAGENTA="" AQUA="" GREEN="" YELLOW="" RED="" RESET=""
else
    color ACCENT '@@ACCENT@@'
    color DIM '@@FG2@@'
    color BLUE '@@BLUE@@'
    color MAGENTA '@@MAGENTA@@'
    color AQUA '@@AQUA@@'
    color GREEN '@@GREEN@@'
    color YELLOW '@@YELLOW@@'
    color RED '@@RED@@'
    RESET=$'\033[0m'
fi

# Raw UTF-8 bytes, so the glyphs survive a C locale.
BRANCH_ICON=$'\xee\x82\xa0'
UP=$'\xe2\x86\x91'
DOWN=$'\xe2\x86\x93'
DOT=$'\xc2\xb7'

# Fields are joined with the ASCII unit separator (code 31), which cannot occur in
# them, and numbers are rounded inside jq so bash never parses a decimal point.
FILTER='
def str: if . == null then "" else tostring | gsub("[\\x00-\\x1f]"; " ") end;
def pct: if type == "number" then round | tostring else "" end;
[ (.model.display_name | str),
  ((.workspace.current_dir // .cwd) | str),
  (.context_window.used_percentage | pct),
  (.cost.total_cost_usd | if type == "number" then . * 100 | round | tostring else "" end),
  (.cost.total_lines_added | str),
  (.cost.total_lines_removed | str),
  (.rate_limits.five_hour.used_percentage | pct),
  ((.workspace.git_worktree // .worktree.name) | str),
  (.pr.number | str)
] | join([31] | implode)'

model="" cwd="" ctx="" cents="" added="" removed="" five="" worktree="" pr=""
if command -v jq >/dev/null; then
    IFS=$'\x1f' read -r model cwd ctx cents added removed five worktree pr < <(jq -r "$FILTER")
fi

# Store the colour for a percentage in the variable named by $1.
level() {
    if (( $2 >= 80 )); then
        printf -v "$1" '%s' "$RED"
    elif (( $2 >= 50 )); then
        printf -v "$1" '%s' "$YELLOW"
    else
        printf -v "$1" '%s' "$GREEN"
    fi
}

wide=1
[[ "${COLUMNS:-}" =~ ^[0-9]+$ ]] && (( COLUMNS < 100 )) && wide=0

top="" prefix="" branch="" oid="" ab="" dirty="" ahead=0 behind=0
if [[ -n "$cwd" && -d "$cwd" ]] && command -v git >/dev/null; then
    { IFS= read -r top; IFS= read -r prefix; } < <(git -C "$cwd" rev-parse --show-toplevel --show-prefix)
fi
if [[ -n "$top" ]]; then
    while IFS= read -r row; do
        case "$row" in
            "# branch.head "*) branch="${row#"# branch.head "}" ;;
            "# branch.oid "*) oid="${row#"# branch.oid "}" ;;
            "# branch.ab "*) ab="${row#"# branch.ab "}" ;;
            "#"*) ;;
            ?*) dirty=1; break ;;
        esac
    done < <(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch --untracked-files=no)
    [[ "$branch" == "(detached)" ]] && branch="${oid:0:7}"
    if [[ "$ab" =~ ^\+([0-9]+)\ -([0-9]+)$ ]]; then
        ahead="${BASH_REMATCH[1]}"
        behind="${BASH_REMATCH[2]}"
    fi
fi

place=""
if [[ -n "$top" ]]; then
    place="${top##*/}"
    [[ -n "$prefix" ]] && place+="/${prefix%/}"
elif [[ -n "$cwd" && ( "$cwd" == "$HOME" || "$cwd" == "$HOME"/* ) ]]; then
    printf -v place '~%s' "${cwd#"$HOME"}"
else
    place="$cwd"
fi

segments=()
[[ -n "$model" ]] && segments+=("${ACCENT}${model}${RESET}")

if [[ -n "$place" ]]; then
    where="${BLUE}${place}${RESET}"
    if [[ -n "$branch" ]]; then
        where+=" ${MAGENTA}${BRANCH_ICON} ${branch}${RESET}"
        [[ -n "$dirty" ]] && where+="${YELLOW}*${RESET}"
        (( ahead > 0 )) && where+=" ${AQUA}${UP}${ahead}${RESET}"
        (( behind > 0 )) && where+=" ${AQUA}${DOWN}${behind}${RESET}"
    fi
    [[ -n "$worktree" ]] && where+=" ${DIM}worktree ${worktree}${RESET}"
    segments+=("$where")
fi

tone=""
if [[ "$ctx" =~ ^[0-9]+$ ]]; then
    level tone "$ctx"
    segments+=("${DIM}ctx${RESET} ${tone}${ctx}%${RESET}")
fi

if [[ "$five" =~ ^[0-9]+$ ]]; then
    level tone "$five"
    segments+=("${DIM}5h${RESET} ${tone}${five}%${RESET}")
fi

if [[ "$cents" =~ ^[0-9]+$ ]] && (( cents > 0 )); then
    printf -v cost "\$%d.%02d" $(( cents / 100 )) $(( cents % 100 ))
    segments+=("${DIM}${cost}${RESET}")
fi

if (( wide )) && [[ "$added$removed" =~ [1-9] ]]; then
    segments+=("${GREEN}+${added:-0}${RESET} ${RED}-${removed:-0}${RESET}")
fi

if (( wide )) && [[ "$pr" =~ ^[0-9]+$ ]]; then
    segments+=("${AQUA}#${pr}${RESET}")
fi

line=""
for segment in "${segments[@]}"; do
    line+="${line:+ ${DIM}${DOT}${RESET} }${segment}"
done
printf '%s\n' "$line"
exit 0
