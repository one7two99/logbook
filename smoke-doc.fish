#!/usr/bin/env fish
# Smoke-Test für `logbook doc` — deckt --prompt-only und Connection-Refused ab.
# Setzt $XDG_DATA_HOME auf ein Wegwerf-Dir, damit die echte Logbook-Daten
# unangetastet bleiben.

set -lx XDG_DATA_HOME (mktemp -d)
set -l LB /home/user/github/logbook-mvp/logbook
set -l rc 0

# Setup: kleine Session mit Section, Note, einem erfolgreichen und einem
# fehlgeschlagenen Befehl.
$LB init smoke-test >/dev/null
$LB section "Setup" >/dev/null
$LB note "smoke-test fixture" >/dev/null
$LB _record --exit-code 0 --cwd /tmp -- echo hallo >/dev/null
$LB _record --exit-code 1 --cwd /tmp -- false >/dev/null

echo "=== Test 1: logbook doc --prompt-only ==="
$LB doc smoke-test --prompt-only > /tmp/doc-prompt-only.out
set -l ec $status
if test $ec -ne 0
    echo "FAIL: exit=$ec (erwartet 0)"
    set rc 1
else if not grep -q "=== SYSTEM ===" /tmp/doc-prompt-only.out
    echo "FAIL: SYSTEM-Marker fehlt"
    set rc 1
else if not grep -q "=== USER ===" /tmp/doc-prompt-only.out
    echo "FAIL: USER-Marker fehlt"
    set rc 1
else if not grep -q "# logbook: smoke-test" /tmp/doc-prompt-only.out
    echo "FAIL: gerenderter Header fehlt"
    set rc 1
else
    echo "OK"
end

echo
echo "=== Test 2: logbook doc --endpoint http://localhost:1 ==="
$LB doc smoke-test --endpoint http://localhost:1 2> /tmp/doc-cr.err
set -l ec $status
if test $ec -ne 1
    echo "FAIL: exit=$ec (erwartet 1)"
    set rc 1
else if not grep -q "ollama nicht erreichbar" /tmp/doc-cr.err
    echo "FAIL: deutsche ConnectionRefused-Meldung fehlt"
    cat /tmp/doc-cr.err
    set rc 1
else if grep -qE "Traceback|File \"" /tmp/doc-cr.err
    echo "FAIL: Stacktrace im stderr — soll sauber sein"
    cat /tmp/doc-cr.err
    set rc 1
else
    echo "OK"
end

rm -rf $XDG_DATA_HOME /tmp/doc-prompt-only.out /tmp/doc-cr.err

if test $rc -eq 0
    echo
    echo "ALL SMOKETESTS PASSED"
else
    echo
    echo "SMOKETEST FAILURES — rc=$rc"
end
exit $rc
