# Claude Code abbreviations for fish, deployed only while ENABLE_CLAUDE_CODE is true.
# Named so that none collides with a hakuspace abbreviation or a Fedora command.

if status is-interactive
    abbr --add cl claude
    abbr --add clco 'claude --continue'
    abbr --add clre 'claude --resume'
end
