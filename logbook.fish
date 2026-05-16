# ~/.config/fish/conf.d/logbook.fish
# logbook: install logbook recorder — fish shell integration
#
# Captures executed commands and records them via `logbook _record`.
# Gate: only records when ~/.local/share/logbook/active exists.

# Resolve XDG data dir once at startup
if test -n "$XDG_DATA_HOME"
    set -g __logbook_dir "$XDG_DATA_HOME/logbook"
else
    set -g __logbook_dir "$HOME/.local/share/logbook"
end

function __logbook_should_skip --argument-names cmd
    # Empty?
    test -z "$cmd"; and return 0
    # Leading space — intentional opt-out (HISTCONTROL=ignorespace convention)
    string match -q ' *' -- $cmd; and return 0
    string match -q \t'*' -- $cmd; and return 0
    # logbook command itself — don't recurse
    string match -q 'logbook' -- $cmd; and return 0
    string match -q 'logbook *' -- $cmd; and return 0
    return 1
end

function __logbook_postexec --on-event fish_postexec --argument-names cmd
    # Capture status of the just-executed command immediately.
    set -l last_status $status

    # Fast gate: no active session → do nothing.
    test -f "$__logbook_dir/active"; or return

    __logbook_should_skip $cmd; and return

    # Pass command as a single argv element after `--`.
    # `command` bypasses any function named `logbook`.
    command logbook _record --exit-code $last_status --cwd (pwd) -- $cmd
end
