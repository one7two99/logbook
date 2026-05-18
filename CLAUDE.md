# CLAUDE.md — Project Context for `logbook`

> Dieses File wird von Claude Code automatisch aus dem Projekt-Root geladen.
> Hier steht alles, was du brauchst, um nahtlos weiterzuentwickeln.

---

## Was ist das?

`logbook` ist ein CLI-Tool, das ausgeführte Shell-Kommandos, Notes und
Section-Marker in JSONL aufzeichnet, nach Markdown rendert und über
ein lokales LLM (Ollama) in Installations-Dokumentationen verwandelt.

**Zielsystem:** Single user, Debian 13 (Trixie), Fish shell, Ollama mit
NVIDIA A4000 (8 GB VRAM), 128 GB RAM. Kein Portabilitätsziel über diesen
Stack hinaus — Pragmatismus vor Generalität.

---

## Aktueller Stand (MVP — Schritte 1+2+3+4+4.5, ✅ done)

**Schritt 1 — Recording + Render:**
- Python 3 single-file binary (`logbook`), **stdlib only**, kein pip
- Fish-Integration via `fish_postexec`-Event (`logbook.fish`)
- JSONL-Storage, XDG-konform
- Noise-Filter: hardcodierte Liste + Leading-Space-Opt-out
- Installer (`install.sh`, bash) + README (DE)

**Schritt 2 — Edit-Werkzeuge:**
- `edit` — Session in `$VISUAL`/`$EDITOR` öffnen
- `drop <id>` / `drop <start>-<end>` — Event(s) per Line-ID löschen
- `prune --failed` / `--noise` — Bulk-Remove auf `type:cmd`
- `tag <tag>` — Pending-Tag fürs nächste `cmd`-Event
- `restore` — `.bak`-Backup atomar zurückspielen
- Schreibmechanik: temp file + atomarer Rename, vorher Backup nach `<name>.jsonl.bak`

**Schritt 3 — Ollama-Integration:**
- `doc [name]` — rendert Session nach Markdown, POST an Ollamas `/api/generate`,
  streamt die Antwort token-für-token auf stdout
- Flags: `--model`, `--endpoint`, `--temperature`, `--save-to DIR`,
  `--commit` (mit `--save-to`), `--prompt-only`
- `think: false` im Payload — Reasoning-Modelle (qwen3, deepseek-r1)
  überspringen ihre Thinking-Phase; wird vom Modell ignoriert, warnt
  das Tool am Ende mit Hinweis auf alternative Modelle
- HTTP via `urllib.request`, kein Third-Party-Dep

**Schritt 4 — Config + Prompt-Templates:**
- `$XDG_CONFIG_HOME/logbook/config.toml` via stdlib `tomllib`
- Sections: `[llm]` (model, endpoint, temperature, seed, default_prompt, think),
  `[output]` (docs_dir, auto_commit), `[filter]` (extra_noise)
- Resolution-Order: **CLI-Flag > config.toml > Hardcode-Default**
- `_CONFIG_CACHE` cached pro Invocation (1× File-I/O)
- `extra_noise`-Konvention: Einträge mit trailing space = Prefix-Match,
  sonst exact; gilt sowohl für `_record` als auch für `prune --noise`
- Prompt-Templates in `$XDG_CONFIG_HOME/logbook/prompts/<name>.md`
- Erster `logbook doc` oder `logbook config edit` schreibt idempotent
  eine **auskommentierte** `config.toml` (Defaults bleiben aktiv, Datei
  ist Editier-Vorlage) und `prompts/setup-doc.md`. Bestehende Files
  werden nie überschrieben.
- Neue `doc`-Flags: `--prompt NAME`, `--save` (nutzt `[output].docs_dir`)
- `[llm].think` und `[llm].seed` sind bewusst **Config-only** (kein CLI-Flag)

**Schritt 4.5 — UX-Polish:**
- Bare `logbook` druckt Hilfe (exit 0, kein argparse-Error)
- `--version` / `-V` Flag (`__version__ = "0.5"` als Modul-Konstante)
- `help [subcommand]` Subcommand (git-Style; Closure-Factory greift auf
  Parser+Subparsers zu, kein Globalmüll)
- `config show|edit|path|reset` Subcommand-Family
  - `show`: rendert `CONFIG_SCHEMA` mit Quelle pro Wert (`[config.toml]`
    vs `[default]`)
  - `reset -y`: atomares `shutil.move(XDG_CONFIG, logbook.bak.<ts>)` —
    Backup-First, falls Backup scheitert wird nichts gelöscht
- `info` — Status-Dashboard: Active Session, Pfade mit Counts,
  Ollama-Reachability (GET `/api/tags`, 2s Timeout, graceful degradation),
  Config-Status
- `search <pattern>` — Regex über `cmd` + `note` Felder aller Sessions.
  Default: case-insensitive, beide Typen. Exit 0 bei Treffern, 1 sonst
  (grep-Konvention). ANSI-Bold nur auf TTY.
- Fish Tab-Completion (`logbook.completions.fish`): Sessions, Prompts,
  Ollama-Modelle dynamisch; `install.sh` deployed nach
  `~/.config/fish/completions/`
- `CONFIG_SCHEMA`: zentrale Liste aller bekannten Keys mit Defaults —
  `config show` und `build_parser`-Defaults beide daran orientiert

**Schritt 6 — Live-Viewer + Fish-Prompt-Indikator:**
- `logbook tail [name]` — follow-mode für aktive oder benannte Session,
  Polling alle 300 ms via `time.sleep`, stdlib only
- Flags: `--lines N` (Replay vor follow), `--filter REGEX` (auf cmd/note/
  section-Inhalt), `--type cmd|note|section`, `--no-color`
- TTY-aware: ANSI-Farben + `== session: name ==`-Banner nur auf TTY;
  `NO_COLOR` und `--no-color` erzwingen plain Output (eine Zeile pro
  Event, kein Banner, keine "⏸"-Marker)
- Auto-Follow ohne expliziten Namen: reagiert auf Session-Wechsel
  (Separator + neues Banner) und `logbook off`/`on` (⏸-Marker)
- Truncation-safe: bei Datei-Größenrückgang wird ab Offset 0 neu gelesen
- Format: `HH:MM:SS  ✓     $ cmd` / `✗N` / `§` (section) / `>` (note);
  Tag-Prefix `#tag` in bold magenta vor dem Marker
- Helper-Function `__logbook_active_session` in `logbook.fish` für
  Prompt-Integration (`fish_prompt`, starship, tide) — reiner File-Read,
  kein Subprocess, README zeigt Beispiel
- Fish-Tab-Completion und Manpage müssen separat gepflegt werden
  (completions: erledigt; man: bei Bedarf nachziehen)

**Subcommands:** `init`, `on`, `off`, `status`, `note`, `section`,
`tag`, `edit`, `drop`, `prune`, `restore`, `list`, `show`, `render`,
`doc`, `config`, `info`, `search`, `tail`, `help`, intern `_record`

---

## Architektur

```
fish_postexec hook   →   logbook _record   →   JSONL append
                                                   │
user runs `logbook render`  ←  load JSONL  ←  ─────┘
                                                   │
user runs `logbook doc`     →  render MD  →  POST Ollama  →  output
```

### Storage-Layout

```
$XDG_DATA_HOME/logbook/   (default: ~/.local/share/logbook/)
├── active              # active session name (absent = off)
├── last                # last active session (for `logbook on`)
├── pending_tag         # one-shot tag for next cmd event (absent = none)
└── sessions/
    ├── <name>.jsonl     # the log
    └── <name>.jsonl.bak # backup, written by drop/prune, restored by `restore`

$XDG_CONFIG_HOME/logbook/  (default: ~/.config/logbook/)
├── config.toml         # auto-erstellt beim ersten `doc` oder `config edit`, auskommentiert
└── prompts/
    └── <name>.md       # System-Prompt-Templates (setup-doc.md beim Bootstrap)
```

### Event-Schema

```jsonc
// init wird einmal pro Session geschrieben
{"ts":"ISO8601","type":"init","name":"...","host":"...","user":"..."}

// pro ausgeführtem (gefiltertem) CLI-Kommando — "tag" optional
{"ts":"ISO8601","type":"cmd","cmd":"...","cwd":"...","exit":0,"user":"...","host":"...","tag":"..."}

// manuelle Anmerkung
{"ts":"ISO8601","type":"note","text":"..."}

// Phasen-Marker → wird in render zu H2
{"ts":"ISO8601","type":"section","title":"..."}
```

**Zeilennummer in der JSONL-Datei = Event-ID** (1-indexed) für künftige
`drop`-Operationen.

### Fish-Hook-Kontrakt

- Hook ist das Gate: existiert `$__logbook_dir/active` nicht, passiert nichts.
- Hook gibt das Kommando als **ein einzelnes argv-Element** an Python
  weiter (nach `--`, mit `command` um Funktions-Shadows zu vermeiden).
- Python-Seite hat zusätzliche Noise-Filter (defense in depth).

---

## Design-Constraints — bitte respektieren

1. **Stdlib only.** Kein `requests`, kein `httpx`, keine Third-Party-Deps.
   PEP 668 auf Debian macht pip-Installs für System-Tools zur Schmerzklasse.
   - Für Ollama HTTP: `urllib.request`
   - Für TOML (Schritt 4): `tomllib` (stdlib seit 3.11)
2. **Single-File Python-Script.** Nicht in Module aufsplitten. Erleichtert
   das Kopieren auf entfernte Hosts und das End-to-End-Lesen. 500–1500 Zeilen
   sind okay.
3. **Fail closed für Noise, fail open für Content.** Im Zweifel
   aufzeichnen — zu viel kann später geprunt werden, fehlende Events
   nicht rekonstruiert.
4. **Idempotente File-Ops.** `mkdir(parents=True, exist_ok=True)` überall.
   Skript darf mitten im Schreiben gekillt werden; leere Zeilen in JSONL
   werden beim Laden übersprungen.
5. **Keine Shell-Escaping-Spielchen.** Fish-Hook übergibt das Kommando
   als ein argv-Element. Niemals neu parsen, nie `shell=True`.
6. **Deutsche Prosa in `render`-Output** ("Beginn"/"Ende"/"Befehle"
   Header) — User sitzt in Berlin. Neue Felder bitte konsistent halten.
7. **Atomare Appends auf JSONL.** Single `f.write()` mit Zeile < 4 KB
   bleibt unter PIPE_BUF und ist auf POSIX atomar. Nicht in mehrere
   Write-Calls aufteilen.
8. **Resolution-Order CLI > Config > Default.** Wer eine neue Option
   einführt: argparse-`default=config_get(section, key, hardcode_default)`.
   Keine eigenen Lookup-Pfade — Konsistenz ist hier wichtiger als
   lokale Optimierung.
9. **`NO_COLOR` und `--no-color` respektieren** bei jedem neuen TTY-Output.
   Konvention: `sys.stdout.isatty()` UND nicht `NO_COLOR` gesetzt UND
   nicht `--no-color` → ANSI-Escapes erlaubt. Sonst plain.

---

## Nicht ohne Rücksprache machen

- Third-Party-Deps einführen "der Bequemlichkeit halber"
- In ein Python-Package aufsplitten
- Bash- oder Zsh-Hooks dazubauen (Fish only)
- Daemon / TUI / Web-UI bauen
- JSONL-Format inkompatibel ändern (Schema-Erweiterung okay, aber
  alte Sessions müssen weiter lesbar bleiben)
- Async-Recording per default (siehe Trade-off im README)

---

## Nächste Schritte (Priorität absteigend)

Schritte 6–10 sind als zusammenhängende Iterations-Batches geplant —
jeder Schritt ein abgeschlossener Claude-Code-Lauf, in der Reihenfolge
unten. Affinität (gemeinsame Code-Pfade, gemeinsame Test-Setups)
bestimmt die Bündelung innerhalb eines Schritts.

### Schritt 7 — LLM-Explain (tail --explain + explain)

- `logbook tail --explain` — Live-Viewer mit on-demand LLM-Erklärungen
  per Key-Press: `e` für letztes cmd-Event, `E` für letzte 5 im Batch,
  `q` oder Ctrl+C für Exit
- Raw-TTY-Mode via stdlib `termios` + `tty.setraw`; non-blocking
  Input-Check via `select.select([sys.stdin], [], [], 0.3)` ersetzt das
  `time.sleep(0.3)` im bestehenden Tail-Loop — Polling und Tastatur
  interleaven sich sauber
- `--explain` ohne TTY auf stdout/stdin → klarer Fehler, exit 2
- `logbook explain <id>` / `logbook explain <name>:<id>` — Standalone
  für einzelne Events, cross-session via `name:id` Syntax, pipeable
  (kein TTY-Requirement)
- Neues Prompt-Template `explain.md`, idempotent angelegt im selben
  Bootstrap-Pfad wie `setup-doc.md`. Kurzer System-Prompt für
  1–2-Satz-Erklärungen pro Befehl, auf Deutsch
- **Reuse aus Schritt 6:** `_tail_format_event` für Event-Ausgabe,
  `_tail_wrap` für ANSI-Wrapping, `TAIL_*` Color-Konstanten,
  `color_on`-Detection-Pattern. Nicht duplizieren.
- **Refactor:** gemeinsame `llm_generate_stream(*, system_prompt,
  user_prompt, model, ...) -> Iterator[str]` aus `cmd_doc` extrahieren.
  `cmd_doc`, `cmd_tail` (--explain) und `cmd_explain` nutzen denselben
  Streaming-Pfad. Fehlerbehandlung (Connection-Refused, 404) ebenfalls
  als shared Helper `format_ollama_error()`

### Schritt 8 — Reflection-Tools

- `logbook scrub` — heuristische Secrets-Detection und -Maskierung:
  - Patterns: `Authorization: Bearer`, `-p<pw>`, `--password`,
    AWS Access Keys (`AKIA[0-9A-Z]{16}`), generische
    `password=`/`token=`/`secret=`
  - Interaktiv mit Bestätigung pro Treffer, `-y` für blind
  - Backup wie üblich nach `.jsonl.bak`
- `logbook stats` — aggregierte Meta-Info über alle Sessions:
  - Counts: Sessions, Events (total + per type), Failure-Rate
  - Top-Befehle cross-session, längste/neueste Session
  - Reine Lese-Operation, kein State-Change

### Schritt 9 — Session-Templates

- `$XDG_CONFIG_HOME/logbook/session-templates/<name>.toml`
- `logbook init-from-template <template> <session>` — neue Session
  anlegen, vorgegebene Sections + initiale Notes aus dem Template
  eintragen
- `logbook templates list` / `logbook templates edit <name>`
- Beim ersten Lauf idempotent ein `debian-base.toml`-Beispiel-Template
  anlegen (analog zu `setup-doc.md`)

### Schritt 10 — logbook diff

- `logbook diff <session-a> <session-b>` — Vergleich zweier Sessions
- Plain-Mode: semantischer Sequenz-Diff via stdlib `difflib`
  (Vergleich auf cmd-Inhalt, nicht JSONL-Line-Diff)
- LLM-Mode (`--llm`): prose Beschreibung der Unterschiede via Ollama,
  neues Prompt-Template `diff.md`
- Output: gut lesbarer unified- oder side-by-side-Diff

### Schritt 4.6 — Zusätzliche Prompt-Templates (deferred)

Aktuell deprioritisiert zugunsten der Schritte 6–10. Reaktivieren wenn
nach Dogfooding klar wird welche Templates wirklich gebraucht werden.

- `runbook.md` — Schritt-für-Schritt-Operations-Anleitung für wiederholte
  Maintenance-Tasks (z.B. Service-Migration, Backup-Cycle)
- `ansible-skeleton.md` — Ausgabe als Ansible-Playbook-Skeleton statt
  Markdown-Prosa
- Optional: `commit-message.md` — kompakte Commit-Message statt voller Doku
- Templates landen unter `<XDG_CONFIG>/prompts/` und werden über
  `--prompt <name>` ausgewählt
- Die System-Prompt-Konstante `DOC_SYSTEM_PROMPT` im Script bleibt als
  Last-Resort-Fallback bestehen — nicht löschen

### Schritt 5 — Cloud-Backend (gestrichen)

Cloud-Backend wird nicht implementiert. Lokales Ollama deckt alle
Use-Cases ab. Entscheidung dokumentiert für zukünftige Iterationen,
damit nicht erneut diskutiert.

---

## Testing

Keine Tests im MVP. Falls du eine Suite hinzufügst:

- `pytest` in einem venv (PEP 668 — nicht system-weit installieren)
- Doku des venv-Setups ins README
- Fokus zuerst auf JSONL-Load/Render-Pfad — dort tun Regressions am
  meisten weh
- Keine Tests für die Fish-Integration, das ist zu sehr Shell-Verhalten —
  manuell smoketesten reicht

---

## User-Profil (für Tonalität)

- Berlin, Deutschland
- IT-Consultant, starker Sysadmin-Background — kein Hand-Holding
- Bevorzugt Open-Source / privacy-conscious Optionen
- Will ehrliche Einschätzungen inkl. Drawbacks
- Metrik, ISO-Datum, 24h
- Daily-Driver Hardware: Dell Precision 7760, Debian 13, Fish,
  i3/X11 + sway/Wayland parallel

---

## Quick reference — Files in diesem Repo

| Datei | Zweck |
|---|---|
| `logbook` | Hauptscript (Python 3, stdlib only). Wird nach `~/.local/bin/` installiert. |
| `logbook.fish` | Fish-Hook (`fish_postexec`). Wird nach `~/.config/fish/conf.d/` installiert. |
| `logbook.completions.fish` | Fish Tab-Completions. Wird nach `~/.config/fish/completions/` installiert. |
| `install.sh` | Installer (bash). One-shot. |
| `README.md` | User-Doku (DE). |
| `CLAUDE.md` | Dieses File. |
