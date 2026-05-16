# logbook — Install-Logbook für Debian-Setups

MVP-Stand (Schritt 1). Erfasst ausgeführte Kommandos, Notes und Section-Marker
in JSONL und rendert nach Markdown. LLM-Anbindung folgt in Schritt 3.

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

```fish
logbook init debian-trixie-setup
# → Session ist aktiv, alles weitere wird aufgezeichnet

logbook section "GPU-Setup"
logbook note "535er Branch reicht für die A4000"
sudo apt install nvidia-driver

logbook section "Docker + NVIDIA Container Toolkit"
sudo apt install docker.io
# ...

logbook off            # pausieren
logbook on             # weitermachen (letzte Session)
logbook status         # aktive Session + Event-Count

logbook list           # alle Sessions
logbook show           # Events der aktiven Session (mit Zeilen-IDs)
logbook render         # → Markdown auf stdout
logbook render > docs/debian-trixie-setup.md
```

### Was aufgezeichnet wird

- Ausgeführte Kommandos: `cmd`, `cwd`, `exit`, `ts`, `user`, `host`
- Notes (manuelle Prosa)
- Sections (werden in `render` zu H2-Überschriften)

### Was **nicht** aufgezeichnet wird

- Kommandos mit führendem Leerzeichen (HISTCONTROL-Konvention) → bewusst Opt-out
- `logbook` selbst
- Noise-Liste: `cd`, `ls`, `ll`, `la`, `pwd`, `clear`, `exit`, `logout`, `fg`, `bg`
- Leere Kommandos

---

## Editieren

Format ist JSONL, eine Zeile pro Event. Direkt editierbar:

```fish
$EDITOR ~/.local/share/logbook/sessions/debian-trixie-setup.jsonl
```

Zeile löschen = Event entfernt. `logbook drop <id>`, `logbook prune --failed`
und `logbook edit` kommen in **Schritt 2**.

---

## Verzeichnislayout

```
~/.local/share/logbook/
├── active                       # Datei mit Namen der aktiven Session (absent = off)
├── last                         # zuletzt aktive Session (für `logbook on`)
└── sessions/
    └── <name>.jsonl             # die Logs
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
  (z. B. `mysql -p PASS`). Workaround: führendes Leerzeichen verwenden,
  oder hinterher in der JSONL editieren.
- **Multi-line Kommandos.** Newlines werden im JSON escaped (`\n`), in
  `render` als ein Codeblock dargestellt. Funktioniert, ist aber etwas
  sperrig zu lesen.

---

## Roadmap

| Schritt | Inhalt |
|---|---|
| 1 ✅ | MVP: Recording, JSONL, render |
| 2 | `edit`, `drop <id|range>`, `prune --failed`, `tag` |
| 3 | Ollama-Integration (`logbook doc`) — Default-Modell `qwen3.6:35b-a3b` |
| 4 | Config (`~/.config/logbook/config.toml`) + Prompt-Templates |
| 5 | Cloud-Backend (Anthropic API) als zweites Backend |

Siehe `CLAUDE.md` für Architektur-Notizen und Entwicklungs-Constraints
zur Weiterarbeit mit Claude Code.

---

## Lizenz

Privat / unkommerziell, keine explizite Lizenz nötig. Mach was Sinn macht.
