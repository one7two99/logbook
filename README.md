# logbook

> Record what you actually typed during a system setup, edit out the wrong turns, and turn the result into Markdown documentation — optionally rendered through a local LLM.

`logbook` is a single-file Python CLI tool that hooks into the fish shell, captures executed commands plus prose notes and section markers into JSONL, and renders the result as Markdown. With a local Ollama instance running, it can also feed the rendered log through an LLM to produce a polished setup document.

Built for a specific stack — fish shell on Debian — and pragmatic about it. No abstraction layers, no plugin system, no third-party Python dependencies (stdlib only).

---

## At a glance

```fish
# Start a session — everything you type from here is recorded
logbook init debian-trixie-setup

logbook section "GPU setup"
logbook note "535er driver is enough for the A4000"

sudo apt update
sudo apt install nvidia-driver
sudo modprobe nvidia          # this one fails — we'll prune it later

logbook section "Docker + NVIDIA Container Toolkit"
sudo apt install docker.io nvidia-container-toolkit
sudo systemctl restart docker

# Inspect, prune mistakes, render
logbook show                  # numbered events with status markers
logbook prune --failed        # drop everything that exited != 0
logbook render > setup.md     # straight Markdown export

# Or let a local LLM produce a polished writeup
logbook doc debian-trixie-setup --model qwen3:8b --save-to ~/docs/setups
```

---

## Why

System setups end up partially in shell history, partially in scratch notes, partially in nobody's memory. Tools like `script(1)` capture everything verbatim including ANSI escapes and dead-ends; manual documentation tends to fossilize. `logbook` sits in between: passive recording while you work, easy retroactive cleanup, and a clean handoff path to either plain Markdown or an LLM for write-up.

The opinionated parts:

- **Fish shell only.** No bash/zsh hooks. `fish_postexec` is reliable and clean; multiplying shell support would multiply the testing surface.
- **Local LLM by default.** Ollama integration is built in; cloud backends are not. Local inference means your install log doesn't leave your machine.
- **stdlib only.** No `pip install`. Drops cleanly into any Debian/Ubuntu host without dependency tangles.
- **German user-facing strings** for output and prompts. The tool was built for and by a German-speaking sysadmin; output is in German, code/config in English.

---

## Requirements

- **Linux** (developed and tested on Debian 13/Trixie; should work on any glibc Linux with fish)
- **fish shell** ≥ 3.0
- **Python 3.11+** (for stdlib `tomllib`)
- *(optional)* **Ollama** for `logbook doc` — any modern Ollama version, local or remote

No other runtime dependencies.

---

## Installation

```bash
git clone https://github.com/one7two99/logbook.git
cd logbook
./install.sh
```

The installer:

1. Copies `logbook` to `~/.local/bin/logbook`
2. Copies `logbook.fish` to `~/.config/fish/conf.d/logbook.fish`
3. Copies `logbook.completions.fish` to `~/.config/fish/completions/logbook.fish`
4. Creates `~/.local/share/logbook/sessions/`
5. Verifies `python3 >= 3.11` and reminds you if `~/.local/bin` isn't in `$PATH`

After install, open a new fish session (or `source ~/.config/fish/conf.d/logbook.fish`).

### Documentation

A man page is included.
It is built into the `.deb` automatically; for source installs:

```fish
# Man page
pandoc -s -t man man/logbook.1.md -o logbook.1
gzip -9 logbook.1
sudo install -m 644 logbook.1.gz /usr/share/man/man1/
sudo mandb && man logbook
```
---

## Usage

### Recording

```fish
logbook init <session-name>      # start and activate a new session
logbook section "Phase title"    # add a heading (renders as H2)
logbook note "free-form prose"   # add a note
logbook tag <tag>                # tag the next cmd event (one-shot)

logbook off                      # pause recording
logbook on                       # resume into the last session
logbook status                   # show current state
```

Once a session is active, every command you run is captured automatically — no prefix needed. To opt out of recording for a single command, prefix it with a space (the same convention as `HISTCONTROL=ignorespace` in bash).

### Viewing and editing

```fish
logbook show                     # numbered events with status markers
logbook list                     # all sessions
logbook edit                     # open the JSONL of the active session in $EDITOR

logbook drop 12                  # delete event with ID 12
logbook drop 12-18               # delete a range
logbook prune --failed           # delete all cmd events that exited != 0
logbook prune --noise            # apply the noise filter retroactively
logbook restore                  # undo the last drop/prune (single-level)
```

Every destructive operation writes a `<session>.jsonl.bak` first, restorable via `logbook restore`. Backup is single-level — the previous `.bak` is overwritten on every new operation.

### Rendering and LLM-generated docs

```fish
logbook render                   # plain Markdown to stdout
logbook render > setup.md

# Through Ollama (must be running locally or reachable)
ollama pull qwen3:8b
logbook doc <session> --model qwen3:8b
logbook doc <session> --model qwen3:8b --save-to ~/docs/setups
logbook doc <session> --save                    # uses [output].docs_dir from config
logbook doc <session> --save --commit           # auto git add+commit in the target repo
logbook doc <session> --prompt-only             # dump the full prompt, skip the LLM call
```

Default model is `qwen3.6:35b-a3b`. Reasoning models (qwen3, deepseek-r1) get `think: false` in the payload — without that, all generation lands in the `thinking` field and stdout stays empty. If your Ollama version ignores the flag, the tool warns at the end with alternative model suggestions.

### Live monitoring

Watch a session as it grows in a second terminal:

```fish
logbook tail                       # follow the active session
logbook tail my-session            # follow a specific session
logbook tail --lines 10            # show 10 recent events, then follow
logbook tail --filter 'apt|systemctl'
logbook tail --type note
logbook tail --no-color            # plain output even on a TTY
```

The viewer polls the JSONL file every ~300 ms — no inotify dependency. On a TTY, events are colorized (✓ green ok, ✗ red fail, § yellow section, > cyan note) and tagged events get a bold magenta prefix. Piped or with `--no-color` / `NO_COLOR`, output is one flat machine-readable line per event with no banners.

Without an explicit name, `tail` follows whichever session is currently active: pausing recording (`logbook off`) prints `⏸ session paused`, and a new `logbook init` switches the view to the new session with a separator. Ctrl+C exits cleanly.

### Fish prompt integration

`logbook.fish` exposes `__logbook_active_session` for use in your prompt. It only reads `~/.local/share/logbook/active` directly — no subprocess, no `logbook` invocation — so it's cheap enough for every prompt refresh:

```fish
function fish_prompt
    # ... your existing prompt ...
    set -l lb (__logbook_active_session)
    if test -n "$lb"
        printf '%s[📝 %s]%s ' (set_color brblue) $lb (set_color normal)
    end
end
```

For starship or tide, define a custom prompt module that reads `~/.local/share/logbook/active` (or `$XDG_DATA_HOME/logbook/active`) directly. The fish helper does the same thing inline and is the simplest path.

### Searching and status

```fish
logbook info                     # dashboard: paths, counts, Ollama reachability
logbook search apt               # regex over cmd + note across all sessions
logbook search -c Apt            # case-sensitive
logbook search --type note <re>  # only notes
logbook help [subcommand]        # git-style help
logbook --version
```

`info` makes a 2-second probe against Ollama's `/api/tags` and reports unreachable gracefully. `search` follows grep exit-code convention (0 if matches, 1 otherwise).

### Configuration

On first run of `logbook doc`, two files are created idempotently (never overwritten):

```
~/.config/logbook/config.toml
~/.config/logbook/prompts/setup-doc.md
```

The `config.toml` is a fully-commented template; without edits, all hardcoded defaults remain active. Resolution order is **CLI flag > config.toml > built-in default**.

Schema:

```toml
[llm]
# model = "qwen3.6:35b-a3b"
# endpoint = "http://localhost:11434"
# temperature = 0.2
# seed = 42
# default_prompt = "setup-doc"
# think = false                  # true to keep reasoning visible

[output]
# docs_dir = "~/docs/setups"     # default target for --save
# auto_commit = false            # implicit git add+commit after save

[filter]
# extra_noise = ["htop", "tmux "]  # entries ending with space are prefix matches
```

Management subcommands:

```fish
logbook config show              # effective values with source: [config.toml] vs [default]
logbook config path              # absolute path to config.toml (scriptable)
logbook config edit              # open config.toml in $EDITOR
logbook config reset -y          # backup to ~/.config/logbook.bak.<ts>/ and reset
```

### Prompt templates

`~/.config/logbook/prompts/<name>.md` is the system prompt sent to Ollama. `setup-doc.md` is bootstrapped on first run; add more templates and select with `--prompt <name>`:

```fish
$EDITOR ~/.config/logbook/prompts/runbook.md
logbook doc my-session --prompt runbook
```

### Tab completion

Fish completes dynamically:

- Session names for `show`/`render`/`doc`/`edit`/`drop`/`prune`/`restore`/`tail`
- Prompt template names for `--prompt`
- Installed Ollama models for `--model` (via `ollama list`)
- All subcommands and `config <show|edit|path|reset>` actions

---

## What is and isn't captured

**Captured:**

- Executed commands with `cmd`, `cwd`, `exit code`, `timestamp`, `user`, `host`
- Optional `tag` on a cmd event (set via `logbook tag` before the command)
- Notes (manual prose via `logbook note`)
- Section markers (`logbook section`, become H2 in render)

**Not captured:**

- Commands with a leading space (HISTCONTROL convention) — explicit opt-out
- The `logbook` command itself
- The hardcoded noise list: `cd`, `ls`, `ll`, `la`, `pwd`, `clear`, `exit`, `logout`, `fg`, `bg`
- Anything matching `[filter].extra_noise` from config

---

## Storage layout

```
~/.local/share/logbook/
├── active                       # active session name (absent = recording off)
├── last                         # last active session (for `logbook on`)
├── pending_tag                  # one-shot tag for next cmd event
└── sessions/
    ├── <name>.jsonl             # the log
    └── <name>.jsonl.bak         # backup, restored by `logbook restore`

~/.config/logbook/
├── config.toml                  # commented template, created on first doc / config edit
└── prompts/
    └── <name>.md                # system-prompt templates
```

Both paths respect `$XDG_DATA_HOME` and `$XDG_CONFIG_HOME`.

---

## Honest limitations

- **Synchronous recording.** Every command triggers a ~50 ms Python startup. Barely noticeable on a modern workstation; potentially visible on older hardware. An async variant would risk race conditions with rapid command sequences, so this is deliberate.
- **`$status` after pipes.** Fish reports the status of the last pipe stage by default. If pipeline status matters, run stages separately or inspect `$pipestatus` manually.
- **`sudo` cwd.** The recorded `cwd` is the calling shell's, not root's. Usually fine.
- **Secrets in command lines.** Passwords passed on the command line (`mysql -p PASS`, `curl -u user:pass`) are recorded as-is. Use a leading space to skip recording, or edit them out afterward with `logbook edit`.
- **Multi-line commands.** Newlines are JSON-escaped (`\n`) and rendered as a single code block. Functional but a bit cramped to read.
- **LLM quality varies.** Small sessions (< 10 commands) tend to hallucinate. Sessions with clear sections and notes produce usable output. For larger work, `--prompt-only` and paste into a cloud model.
- **`--commit` is broad.** `--save-to ... --commit` does `git add -A` in the target repo — other unstaged changes get committed too. Manual staging is safer if that matters.
- **Single-level backup.** Each new `drop`/`prune` overwrites the existing `.bak`. No multi-step undo.

---

## Project status

Personal tool, used in production for the author's own consulting work. Stable feature-wise as of v0.5. Open to issues and bug reports; PRs welcome but not solicited.

**Planned:**

- Additional prompt templates (`runbook.md`, `ansible-skeleton.md`)

**Explicitly not planned:**

- Cloud LLM backends (Anthropic, OpenAI). Local Ollama covers the use case.
- bash or zsh support. Fish-only is a feature.
- TUI / web UI / daemon. CLI is the right interface.

---

## Development notes

The tool was developed iteratively with substantial AI assistance (Claude Opus 4.7 via Claude Code). Commits tagged with `[ai: <model>]` denote AI-assisted contributions; `Co-Authored-By: Claude Opus 4.7` appears in commit messages where significant code was generated.

The project root contains a `CLAUDE.md` file describing architecture, design constraints, and roadmap — used by Claude Code as project context but also useful as a high-level engineering overview for human readers.

To contribute or extend:

1. Read `CLAUDE.md` first — the design constraints (stdlib only, single-file, atomic file ops, German user-facing prose) are non-negotiable
2. Maintain the `CLAUDE.md` "Aktueller Stand" section as features land
3. Keep commits small and rebase before merging

---

## License

MIT. See `LICENSE`.
