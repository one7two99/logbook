# CLAUDE.md — Project Context for `logbook`

> Dieses File wird von Claude Code automatisch aus dem Projekt-Root geladen.
> Hier steht alles, was du brauchst, um nahtlos weiterzuentwickeln.

---

## Was ist das?

`logbook` ist ein CLI-Tool, das ausgeführte Shell-Kommandos, Notes und
Section-Marker in JSONL aufzeichnet, nach Markdown rendert und (in
einem späteren Schritt) durch ein lokales LLM (Ollama) jagt, um daraus
Installations-Dokumentationen zu erzeugen.

**Zielsystem:** Single user, Debian 13 (Trixie), Fish shell, Ollama mit
NVIDIA A4000 (8 GB VRAM), 128 GB RAM. Kein Portabilitätsziel über diesen
Stack hinaus — Pragmatismus vor Generalität.

---

## Aktueller Stand (MVP — Schritte 1+2, ✅ done)

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

**Subcommands:** `init`, `on`, `off`, `status`, `note`, `section`,
`tag`, `edit`, `drop`, `prune`, `restore`, `list`, `show`, `render`,
intern `_record`

---

## Architektur

```
fish_postexec hook   →   logbook _record   →   JSONL append
                                                   │
user runs `logbook render`  ←  load JSONL  ←  ─────┘
                                                   │
(Schritt 3:) user runs `logbook doc`  →  render MD  →  POST Ollama  →  output
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
```

### Event-Schema

```jsonc
// init wird einmal pro Session geschrieben
{"ts":"ISO8601","type":"init","name":"...","host":"...","user":"..."}

// pro ausgeführtem (gefiltertem) CLI-Kommando
{"ts":"ISO8601","type":"cmd","cmd":"...","cwd":"...","exit":0,"user":"...","host":"..."}

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

### Schritt 3 — Ollama-Integration

- `logbook doc [name] [--model ...] [--prompt ...]`
- Rendert intern erst nach Markdown, packt das in den Prompt, POST an
  `http://localhost:11434/api/generate` (oder `/api/chat`)
- **Default-Modell:** `qwen3.6:35b-a3b` (User-Wunsch)
- `--model qwen3:8b` als Schnell-Override für GPU-only
- Streaming-Output (`stream: true` in der API) — ans Terminal ausgeben
  während es generiert wird
- **Honest warning:** bei 35B MoE auf 8 GB VRAM kommt CPU-Offload zum
  Tragen. ~6–12 t/s erwartet. Im Code keinen Spinner versprechen, der
  schneller dreht als die Realität.

Skelett für den HTTP-Call (stdlib only):

```python
import json, urllib.request
def ollama_generate(prompt, model, host="http://localhost:11434"):
    req = urllib.request.Request(
        f"{host}/api/generate",
        data=json.dumps({"model": model, "prompt": prompt, "stream": True}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        for line in resp:
            chunk = json.loads(line)
            yield chunk.get("response", "")
            if chunk.get("done"):
                return
```

### Schritt 4 — Config + Prompts

- `$XDG_CONFIG_HOME/logbook/config.toml`
- Schema-Vorschlag:
  ```toml
  [llm]
  backend = "ollama"          # "ollama" | "anthropic"
  model = "qwen3.6:35b-a3b"
  endpoint = "http://localhost:11434"
  temperature = 0.2
  seed = 42
  default_prompt = "setup-doc"

  [filter]
  extra_noise = ["watch", "htop"]
  ```
- Prompt-Templates in `$XDG_CONFIG_HOME/logbook/prompts/*.md`
- Default-Templates beim ersten Lauf nach `prompts/` schreiben, wenn
  dort nichts liegt (idempotent — niemals user-files überschreiben)
- Beispiel-Prompts zum Ausliefern: `setup-doc.md`, `runbook.md`,
  `ansible-skeleton.md`

### Schritt 5 — Cloud-Backend

- Anthropic API als zweites Backend, gewählt via `[llm].backend = "anthropic"`
  oder `--backend anthropic`
- Key aus Env (`ANTHROPIC_API_KEY`), niemals aus der Config (zu leicht
  versehentlich committed)
- Bei MoE-Renders empfiehlt sich sowieso oft das Cloud-Modell für
  größere Dokus

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
| `install.sh` | Installer (bash). One-shot. |
| `README.md` | User-Doku (DE). |
| `CLAUDE.md` | Dieses File. |
