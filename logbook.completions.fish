# logbook fish completions
#
# Gehört nach $XDG_CONFIG_HOME/fish/completions/logbook.fish (Fish liest
# completions/ separat von conf.d/). install.sh übernimmt das.

# --- XDG-Pfade auflösen (analog zur Hook-Datei) -----------------------------

set -l __lb_data (test -n "$XDG_DATA_HOME"; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/logbook
set -l __lb_cfg  (test -n "$XDG_CONFIG_HOME"; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/logbook

# --- Dynamic completion sources --------------------------------------------

function __logbook_sessions --description "list logbook session names"
    set -l data_dir (test -n "$XDG_DATA_HOME"; and echo $XDG_DATA_HOME; or echo $HOME/.local/share)/logbook
    set -l sess_dir $data_dir/sessions
    if test -d $sess_dir
        for f in $sess_dir/*.jsonl
            test -f $f; or continue
            basename $f .jsonl
        end
    end
end

function __logbook_prompts --description "list logbook prompt template names"
    set -l cfg_dir (test -n "$XDG_CONFIG_HOME"; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/logbook
    set -l p_dir $cfg_dir/prompts
    if test -d $p_dir
        for f in $p_dir/*.md
            test -f $f; or continue
            basename $f .md
        end
    end
end

function __logbook_ollama_models --description "list installed Ollama models (leise bei Fehlern)"
    # `ollama list` Format: NAME ID SIZE MODIFIED — Spalte 1 ist der Tag.
    # Quietly skip wenn ollama nicht im PATH oder Server nicht erreichbar.
    if command -q ollama
        ollama list 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}'
    end
end

# --- Top-level: keine File-Completion per default --------------------------

complete -c logbook -f

# --- Subcommands -----------------------------------------------------------

complete -c logbook -n "__fish_use_subcommand" -a init    -d "neue Session anlegen"
complete -c logbook -n "__fish_use_subcommand" -a on      -d "Recording fortsetzen"
complete -c logbook -n "__fish_use_subcommand" -a off     -d "Recording pausieren"
complete -c logbook -n "__fish_use_subcommand" -a status  -d "Status der aktiven Session"
complete -c logbook -n "__fish_use_subcommand" -a note    -d "Note an aktive Session"
complete -c logbook -n "__fish_use_subcommand" -a section -d "Section-Marker setzen (H2 in render)"
complete -c logbook -n "__fish_use_subcommand" -a tag     -d "Tag fürs nächste cmd-Event"
complete -c logbook -n "__fish_use_subcommand" -a list    -d "alle Sessions auflisten"
complete -c logbook -n "__fish_use_subcommand" -a show    -d "Events einer Session zeigen"
complete -c logbook -n "__fish_use_subcommand" -a edit    -d "Session in \$EDITOR öffnen"
complete -c logbook -n "__fish_use_subcommand" -a drop    -d "Event(s) löschen (N oder N-M)"
complete -c logbook -n "__fish_use_subcommand" -a prune   -d "Bulk-Remove (--failed/--noise)"
complete -c logbook -n "__fish_use_subcommand" -a restore -d ".bak-Backup zurückspielen"
complete -c logbook -n "__fish_use_subcommand" -a render  -d "Session als Markdown auf stdout"
complete -c logbook -n "__fish_use_subcommand" -a doc     -d "LLM-Doku via Ollama (streamed)"
complete -c logbook -n "__fish_use_subcommand" -a config  -d "Konfiguration verwalten"
complete -c logbook -n "__fish_use_subcommand" -a info    -d "Status-Dashboard"
complete -c logbook -n "__fish_use_subcommand" -a search  -d "grep über cmd+note Felder"
complete -c logbook -n "__fish_use_subcommand" -a tail    -d "Live-Viewer (follow JSONL)"
complete -c logbook -n "__fish_use_subcommand" -a explain -d "Event via LLM erklären"
complete -c logbook -n "__fish_use_subcommand" -a help    -d "Hilfe (optional zu einem Subcommand)"

# --- Session-Namen wo eine Session erwartet wird ---------------------------

complete -c logbook -n "__fish_seen_subcommand_from show render doc edit drop prune restore tail" \
    -a "(__logbook_sessions)" -d "Session"

# explain nimmt entweder eine bare event-id (numerisch, schwer zu completen)
# oder <session>:<id>. Wir bieten zumindest die Session-Namen mit nachgestelltem
# Doppelpunkt an, damit das Tippen kürzer wird.
complete -c logbook -n "__fish_seen_subcommand_from explain" \
    -a "(__logbook_sessions)" -d "Session"

# --- `config <action>` -----------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from show edit path reset" \
    -a "show edit path reset"
complete -c logbook -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from reset" \
    -l yes -s y -d "ohne Rückfrage"

# --- `help <subcommand>` ---------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from help" \
    -a "init on off status note section tag list show edit drop prune restore render doc config info search tail explain help"

# --- Flags für `doc` -------------------------------------------------------

# Hinweis: -x = -r -f (Argument erforderlich, kein File-Fallback).
# --save-to bekommt -r ohne -f, damit Fish Verzeichnisse vorschlägt.
complete -c logbook -n "__fish_seen_subcommand_from doc" -l model       -x -d "Ollama-Modell"        -a "(__logbook_ollama_models)"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l prompt      -x -d "Prompt-Template"      -a "(__logbook_prompts)"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l endpoint    -x -d "Ollama URL"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l temperature -x -d "sampling temperature 0.0-2.0"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l save-to     -r -d "Ziel-Verzeichnis (DIR)"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l save           -d "nutzt [output].docs_dir"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l commit         -d "git add+commit nach save"
complete -c logbook -n "__fish_seen_subcommand_from doc" -l prompt-only    -d "nur Prompts drucken, kein LLM-Call"

# --- Flags für `search` ----------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from search" -l case-sensitive -s c -d "case-sensitive"
complete -c logbook -n "__fish_seen_subcommand_from search" -l type -x -d "Event-Typ" -a "cmd note"

# --- Flags für `prune` -----------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from prune" -l failed -d "type:cmd mit exit != 0 entfernen"
complete -c logbook -n "__fish_seen_subcommand_from prune" -l noise  -d "Noise-Filter retroaktiv anwenden"

# --- Flags für `tag` -------------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from tag" -l clear -d "pending Tag löschen"

# --- Flags für `init` ------------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from init" -l force -d "bestehende Session überschreiben"

# --- Flags für `tail` ------------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from tail" -l lines -s n -x -d "letzte N Events vor follow"
complete -c logbook -n "__fish_seen_subcommand_from tail" -l filter -x -d "Regex auf cmd/note/section"
complete -c logbook -n "__fish_seen_subcommand_from tail" -l type -x -d "Event-Typ" -a "cmd note section"
complete -c logbook -n "__fish_seen_subcommand_from tail" -l no-color -d "plain output trotz TTY"
complete -c logbook -n "__fish_seen_subcommand_from tail" -l explain  -d "Raw-TTY-Mode mit LLM-Erklärungen [e]/[E]/[q]"

# --- Flags für `explain` ---------------------------------------------------

complete -c logbook -n "__fish_seen_subcommand_from explain" -l model       -x -d "Ollama-Modell"   -a "(__logbook_ollama_models)"
complete -c logbook -n "__fish_seen_subcommand_from explain" -l prompt      -x -d "Prompt-Template" -a "(__logbook_prompts)"
complete -c logbook -n "__fish_seen_subcommand_from explain" -l endpoint    -x -d "Ollama URL"
complete -c logbook -n "__fish_seen_subcommand_from explain" -l temperature -x -d "sampling temperature 0.0-2.0"

# --- Top-level Flags -------------------------------------------------------

complete -c logbook -l version -s V -d "Version anzeigen"
complete -c logbook -l help    -s h -d "Hilfe anzeigen"
