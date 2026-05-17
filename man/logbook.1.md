% LOGBOOK(1) logbook 0.5 | User Commands
% <Your Name>
% May 2026

# NAME

logbook - install-logbook recorder with optional LLM-rendered documentation

# SYNOPSIS

**logbook** \[**-h**|**\--help**\] \[**-V**|**\--version**\] *command* \[*args*\]

# DESCRIPTION

**logbook** records executed shell commands, prose notes and section markers
to JSONL while you work, lets you retroactively prune mistakes, and renders
the result as Markdown — optionally through a local Ollama instance for
polished installation documentation.

Recording is opt-in per session and uses a *fish_postexec* hook to capture
commands as they run. The hook only fires when a session is active, so the
tool is silent until **logbook init** is called.

The tool is **fish-shell only** and has no Python dependencies beyond the
standard library.

# GLOBAL OPTIONS

**-h**, **\--help**
:   Print help and exit. Equivalent to **logbook help**.

**-V**, **\--version**
:   Print version and exit.

# SESSION MANAGEMENT

**logbook init** *name*
:   Start a new session and activate it. Recording begins immediately for
    all subsequent commands in fish sessions on this host.

**logbook on**
:   Resume recording into the last-used session.

**logbook off**
:   Pause recording. The session remains intact and can be resumed.

**logbook status**
:   Show the active session, event count, and any pending tag.

**logbook list**
:   List all sessions with event counts.

**logbook info**
:   Status dashboard: paths, session counts, Ollama reachability,
    installed Ollama models, available prompt templates, config status.

# RECORDING ANNOTATIONS

**logbook note** *text*
:   Add a free-form prose note to the active session. Notes render as
    block quotes.

**logbook section** *title*
:   Add a section marker. Renders as a level-2 heading.

**logbook tag** *tag*
:   Tag the next captured cmd event. One-shot — consumed by the next
    automatic recording.

**logbook tag \--clear**
:   Clear any pending tag.

# VIEWING AND EDITING

**logbook show** \[*name*\]
:   Dump session events as numbered plain text with status markers.
    Defaults to the active session.

**logbook edit** \[*name*\]
:   Open the JSONL of a session in **\$VISUAL**, **\$EDITOR**, or **vi**.

**logbook render** \[*name*\]
:   Render a session to Markdown on stdout.

# DESTRUCTIVE OPERATIONS

Every destructive operation writes a *\<session\>.jsonl.bak* before
changes. Single-level backup: the previous *.bak* is overwritten on every
new operation. Use **logbook restore** to roll back the most recent
destructive operation.

**logbook drop** *id*
:   Delete the event with the given line ID (from **logbook show**).

**logbook drop** *start*-*end*
:   Delete a range of events inclusive.

**logbook prune \--failed**
:   Delete all *type:cmd* events with non-zero exit status.

**logbook prune \--noise**
:   Re-apply the noise filter retroactively, deleting captured events
    that would now be filtered.

**logbook restore**
:   Restore the most recent *.bak* atomically.

# LLM-RENDERED DOCUMENTATION

**logbook doc** \[*name*\] \[*options*\]
:   Render a session to Markdown, POST to Ollama's */api/generate*, and
    stream the result to stdout. On first invocation, creates an
    annotated *config.toml* and *prompts/setup-doc.md* skeleton in
    **\$XDG_CONFIG_HOME/logbook/**.

    Options:

    **\--model** *model*
    :   Override the Ollama model. Default: from config or
        *qwen3.6:35b-a3b*.

    **\--endpoint** *url*
    :   Override the Ollama URL. Default: *http://localhost:11434*.

    **\--temperature** *float*
    :   Override sampling temperature. Default: 0.2.

    **\--prompt** *name*
    :   Use prompt template *name* from
        **\$XDG_CONFIG_HOME/logbook/prompts/**.

    **\--save-to** *dir*
    :   Save the generated Markdown to *dir/\<session\>.md* in addition
        to stdout.

    **\--save**
    :   Same as **\--save-to** but uses *\[output\].docs_dir* from
        config.toml.

    **\--commit**
    :   After saving, run *git add -A && git commit* in the target
        directory if it is a git repository. Requires **\--save** or
        **\--save-to**.

    **\--prompt-only**
    :   Print the assembled system and user prompts to stdout without
        calling the LLM.

# SEARCH AND HELP

**logbook search** *pattern* \[**-c**\] \[**\--type** *cmd*|*note*\]
:   Search cmd and note fields across all sessions using Python regex.
    Case-insensitive by default; **-c** for case-sensitive. Exit code
    follows grep convention (0 on match, 1 on none).

**logbook help** \[*topic*\]
:   Show general help, or detailed help for *topic* (a subcommand name).

# CONFIGURATION

**logbook config show**
:   Print effective configuration with source annotations
    (*\[config.toml\]* vs *\[default\]*).

**logbook config path**
:   Print the absolute path to *config.toml*.

**logbook config edit**
:   Open *config.toml* in **\$VISUAL**/**\$EDITOR**.

**logbook config reset** \[**-y**\]
:   Backup **\$XDG_CONFIG_HOME/logbook/** to a timestamped sibling and
    remove it. Recreated on next **logbook doc**. Sessions in
    **\$XDG_DATA_HOME/logbook/** are unaffected.

# FILES

*\$XDG_DATA_HOME/logbook/active*
:   File whose content is the active session name. Absent means
    recording is off.

*\$XDG_DATA_HOME/logbook/last*
:   Last active session name; used by **logbook on**.

*\$XDG_DATA_HOME/logbook/pending_tag*
:   One-shot tag for the next cmd event.

*\$XDG_DATA_HOME/logbook/sessions/\<name\>.jsonl*
:   JSONL log of a session.

*\$XDG_DATA_HOME/logbook/sessions/\<name\>.jsonl.bak*
:   Backup written by drop and prune.

*\$XDG_CONFIG_HOME/logbook/config.toml*
:   Configuration. Auto-created with all values commented out (defaults
    active) on first **logbook doc**.

*\$XDG_CONFIG_HOME/logbook/prompts/\<name\>.md*
:   System-prompt templates for **logbook doc**.

# ENVIRONMENT

**XDG_DATA_HOME**, **XDG_CONFIG_HOME**
:   Respected for storage locations. Default to *\~/.local/share* and
    *\~/.config*.

**EDITOR**, **VISUAL**
:   Used by **logbook edit** and **logbook config edit**. **VISUAL**
    takes precedence over **EDITOR**.

# EXIT STATUS

**0**
:   Success.

**1**
:   General failure (no active session, file not found, LLM error,
    no search matches).

**2**
:   Usage or argument error (invalid session name, missing required
    flag, malformed regex).

**130**
:   Interrupted by SIGINT.

# EXAMPLES

Start a session and capture a setup:

    logbook init debian-trixie
    logbook section "GPU Setup"
    sudo apt install nvidia-driver
    logbook note "535 branch is enough for the A4000"

Clean up failed attempts before rendering:

    logbook prune --failed
    logbook render > setup.md

Generate prose documentation with a small local model:

    ollama pull qwen3:8b
    logbook doc debian-trixie --model qwen3:8b --save-to ~/docs

Search for past nvidia-related work across all sessions:

    logbook search -i nvidia

# LIMITATIONS

Synchronous recording adds ~50 ms latency per command (Python startup).

Sensitive data on command lines (passwords, tokens) is recorded as-is.
Use a leading space to skip recording, or remove afterwards with
**logbook edit**.

Single-level backup only — each new destructive operation overwrites
the previous *.bak*.

**\--commit** runs *git add -A* on the entire target directory; other
unstaged changes get committed alongside the doc.

# SEE ALSO

**fish**(1), **ollama**(1), **git**(1), **tldr**(1)

Project homepage and source:
:   *https://github.com/\<you\>/logbook*

# AUTHOR

Written by \<Your Name\>. Substantial portions developed with AI
assistance (Claude Opus 4.7 via Claude Code).
