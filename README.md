# logbook — Install-Logbook für Debian-Setups

MVP-Stand (Schritte 1+2+3+4). Erfasst ausgeführte Kommandos, Notes und
Section-Marker in JSONL, rendert nach Markdown und kann die Session über
ein lokales Ollama in eine Setup-Doku verwandeln. Verhalten ist über
`~/.config/logbook/config.toml` und Prompt-Templates anpassbar.

Single-File Python 3 + Fish-Hook, **keine externen Abhängigkeiten** (stdlib only).

---

## Installation

```bash
./install.sh
```

Macht:

1. Kopiert `logbook` nach `~/.local/bin/logbook` (0755)
2. Kopiert `logbook.fish` nach `~/.config/fish/conf.d/logbook.fish` (0644)
3. Legt `~/.local/share/logbook/sessions/` an
4. Prüft `python3 >= 3.11` und ob `~/.local/bin` im `$PATH` ist

Danach: **neue Fish-Session öffnen** (oder `source ~/.config/fish/conf.d/logbook.fish`).

---

## Benutzung

### Recording

```fish
logbook init debian-trixie-setup
# → Session ist aktiv, alles weitere wird aufgezeichnet

logbook section "GPU-Setup"
logbook note "535er Branch reicht für die A4000"
logbook tag driver           # nächstes cmd-Event bekommt tag:driver (one-shot)
sudo apt install nvidia-driver

logbook off                  # pausieren
logbook on                   # weitermachen (letzte Session)
logbook status               # aktive Session, Event-Count, pending tag
```

### Anschauen und editieren

```fish
logbook show                 # Events der aktiven Session mit Zeilen-IDs
logbook edit                 # JSONL der aktiven Session in $VISUAL/$EDITOR

logbook drop 12              # Event mit ID 12 löschen
logbook drop 12-18           # Range löschen
logbook prune --failed       # alle type:cmd mit exit != 0 entfernen
logbook prune --noise        # Noise-Filter retroaktiv anwenden
logbook restore              # letzte drop/prune-Aktion rückgängig (via .bak)
```

`drop` und `prune` schreiben vor jeder Aktion `<session>.jsonl.bak` —
`logbook restore` zieht das Backup atomar zurück. Das Backup wird bei
der nächsten destruktiven Operation überschrieben, also zeitnah
restoren wenn nötig.

### Render und LLM-Doku

```fish
logbook list                 # alle Sessions
logbook render               # Markdown auf stdout
logbook render > docs/debian-trixie-setup.md
```

Für die LLM-Doku via Ollama:

```fish
# Voraussetzung: `ollama serve` läuft, Modell ist gepullt
ollama pull qwen3:8b

# Streaming auf stdout
logbook doc debian-trixie-setup --model qwen3:8b

# Zusätzlich als <save-to>/<session>.md ablegen
logbook doc debian-trixie-setup --model qwen3:8b --save-to ~/notes

# Oder kürzer: --save nutzt [output].docs_dir aus der config.toml
logbook doc debian-trixie-setup --save

# In einem Git-Repo: stagen + committen lassen (--commit braucht --save / --save-to)
logbook doc debian-trixie-setup --save --commit

# Alternatives Prompt-Template (Datei unter ~/.config/logbook/prompts/<name>.md)
logbook doc debian-trixie-setup --prompt runbook

# Den vollen Prompt rausziehen, ohne LLM zu fragen (z.B. für ein Cloud-Modell)
logbook doc debian-trixie-setup --prompt-only

# Anderer Ollama-Host
logbook doc debian-trixie-setup --endpoint http://10.0.0.5:11434
```

Default-Modell ist `qwen3.6:35b-a3b`. Reasoning-Modelle (qwen3,
deepseek-r1) bekommen `think: false` im Payload — sonst landet die
ganze Generation im `thinking`-Feld und stdout bleibt leer. Ältere
Ollama-Versionen ignorieren das Flag; das Tool warnt dann am Ende mit
Hinweis auf alternative Modelle (z.B. `qwen2.5:7b`, `llama3.1:8b`).

`--temperature 0.2` (Default) ist bewusst nüchtern — höher wird
kreativer und halluzinationsfreudiger, was bei Setup-Dokus selten
gut tut.

### Konfiguration

Beim ersten `logbook doc <session>` legt das Tool zwei Dateien an, falls
sie noch nicht existieren — beides idempotent, bestehende Files werden
nie überschrieben:

```
~/.config/logbook/config.toml
~/.config/logbook/prompts/setup-doc.md
```

Die `config.toml` ist eine **auskommentierte** Vorlage; ohne Edit
bleiben die Hardcode-Defaults aktiv. Auflösungsreihenfolge ist
**CLI-Flag > config.toml > Default**.

Schema:

```toml
[llm]
# model = "qwen3.6:35b-a3b"          # Ollama-Modell
# endpoint = "http://localhost:11434"
# temperature = 0.2
# seed = 42                          # für reproduzierbare Generationen
# default_prompt = "setup-doc"       # Datei unter prompts/<name>.md
# think = false                      # true = Reasoning der Thinking-Modelle erlauben

[output]
# docs_dir = "~/docs/setups"         # Default-Ziel für `--save`
# auto_commit = false                # implizites git add+commit nach Speichern

[filter]
# extra_noise = ["htop", "tmux "]    # zusätzliche Noise-Strings
```

- `[llm].think` und `[llm].seed` sind bewusst **nur per Config**
  setzbar, kein CLI-Flag dafür.
- `--save` ohne Argument nutzt `[output].docs_dir`. Ohne diese
  Config-Option meldet das Tool einen Fehler. `--save-to DIR` überschreibt
  den Wert explizit.
- `auto_commit = true` triggert das gleiche `git add -A && git commit`
  wie `--commit` — gilt nur, wenn auch wirklich gespeichert wird.
- `extra_noise`-Einträge **mit trailing space** sind Präfix-Matches
  (`"tmux "` droppt `tmux attach`, `tmux new` etc.), ohne trailing space
  exakte Matches (`"htop"` droppt nur `htop` alleine). Greift sowohl
  in `_record` (live) als auch bei `prune --noise` (retroaktiv).

#### Prompt-Templates

`~/.config/logbook/prompts/<name>.md` ist die Datei, die als
**System-Prompt** an Ollama geschickt wird. `setup-doc.md` wird beim
ersten Lauf angelegt — frei editierbar. Zusätzliche Templates einfach
daneben legen und mit `--prompt <name>` auswählen:

```fish
$EDITOR ~/.config/logbook/prompts/runbook.md
logbook doc my-session --prompt runbook
```

### Was aufgezeichnet wird

- Ausgeführte Kommandos: `cmd`, `cwd`, `exit`, `ts`, `user`, `host`
- Optional `tag` am cmd-Event, wenn vorher `logbook tag <wert>` gesetzt war
- Notes (manuelle Prosa)
- Sections (werden in `render` zu H2-Überschriften)

### Was **nicht** aufgezeichnet wird

- Kommandos mit führendem Leerzeichen (HISTCONTROL-Konvention) → bewusst Opt-out
- `logbook` selbst
- Noise-Liste: `cd`, `ls`, `ll`, `la`, `pwd`, `clear`, `exit`, `logout`, `fg`, `bg`
- Leere Kommandos

---

## JSONL direkt editieren

Format ist JSONL, eine Zeile pro Event. Direkt editierbar:

```fish
$EDITOR ~/.local/share/logbook/sessions/debian-trixie-setup.jsonl
# oder bequemer:
logbook edit
```

Zeile löschen = Event entfernt. Komfortabler geht's mit `logbook drop`
und `logbook prune` (siehe oben).

---

## Verzeichnislayout

```
~/.local/share/logbook/
├── active                       # Name der aktiven Session (absent = off)
├── last                         # zuletzt aktive Session (für `logbook on`)
├── pending_tag                  # one-shot Tag fürs nächste cmd-Event (absent = none)
└── sessions/
    ├── <name>.jsonl             # die Logs
    └── <name>.jsonl.bak         # Backup von drop/prune, via `logbook restore` zurück

~/.config/logbook/
├── config.toml                  # auskommentierte Vorlage, beim 1. doc angelegt
└── prompts/
    └── <name>.md                # System-Prompt-Templates (setup-doc.md initial)
```

Pfade respektieren `$XDG_DATA_HOME` und `$XDG_CONFIG_HOME`.

---

## Ehrliche Trade-offs / Limits

- **Sync-Recording.** Jedes Kommando triggert einen ~50ms Python-Start.
  Auf der Dell Precision 7760 kaum spürbar; auf langsameren Hosts
  potenziell ein Wahrnehmungs-Issue. Async-Variante (`& disown`) ist
  möglich, birgt aber Race-Conditions bei schnellen Kommandos in Folge —
  bewusst sync gelassen.
- **`$status` nach Pipes.** Fish liefert standardmäßig den Status des
  letzten Pipe-Befehls. Wenn dir das matters: einzeln laufen lassen oder
  `$pipestatus` selber inspizieren und nachpflegen.
- **`sudo`-cwd.** `cwd` ist das Working-Dir der aufrufenden Shell, nicht
  von root. In der Regel egal.
- **Sensible Daten.** Passwörter in Kommandozeilen werden mitgeloggt
  (z.B. `mysql -p PASS`). Workaround: führendes Leerzeichen verwenden,
  oder hinterher in der JSONL editieren (`logbook edit`).
- **Multi-line Kommandos.** Newlines werden im JSON escaped (`\n`), in
  `render` als ein Codeblock dargestellt. Funktioniert, ist aber etwas
  sperrig zu lesen.
- **LLM-Qualität.** `qwen3.6:35b-a3b` ist ein MoE-Modell, läuft auf
  8 GB VRAM mit CPU-Offload (~6-12 t/s erwartet). Realistisch: kleine
  Sessions (< 10 Befehle) tendieren zum Halluzinieren, gut strukturierte
  Sessions mit Sections und Notes liefern verwertbares Material. Für
  größere Dokus später Cloud-Backend (Schritt 5).
- **`--commit` ist breit.** Mit `--save-to ... --commit` macht das Tool
  ein `git add -A` im erkannten Repo — committet also auch andere
  unstaged Änderungen. Wenn dich das stört, manuell stagen und committen
  statt `--commit`.
- **`--bak` ist Single-Level.** Jedes neue `drop`/`prune` überschreibt
  die bestehende Backup-Datei. Mehrfach-Undo gibt es nicht; wenn du es
  brauchst: vorher die `.jsonl.bak` woanders hin kopieren.

---

## Roadmap

| Schritt | Inhalt |
|---|---|
| 1 ✅ | MVP: Recording, JSONL, render |
| 2 ✅ | `edit`, `drop` (id/range), `prune --failed/--noise`, `tag`, `restore` |
| 3 ✅ | Ollama-Integration (`logbook doc`) — Streaming, `--save-to`, `--commit` |
| 4 ✅ | Config (`~/.config/logbook/config.toml`) + Prompt-Templates, `--prompt`, `--save`, `auto_commit`, `extra_noise` |
| 4.5  | Zusätzliche Prompt-Templates: `runbook.md`, `ansible-skeleton.md` |
| 5    | Cloud-Backend (Anthropic API) als zweites Backend |

Siehe `CLAUDE.md` für Architektur-Notizen und Entwicklungs-Constraints
zur Weiterarbeit mit Claude Code.

---

## Lizenz

Privat / unkommerziell, keine explizite Lizenz nötig. Mach was Sinn macht.
