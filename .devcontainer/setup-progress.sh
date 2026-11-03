#!/usr/bin/env bash
# Streams setup.sh's output into this terminal while Codespace setup runs;
# ~/.bashrc runs it in every new interactive shell (see on-create.sh). Does
# nothing once setup has finished. Ctrl-C stops watching; setup keeps going.
set -uo pipefail

state_file=/tmp/ac6-workshop-setup.state
log=/tmp/ac6-workshop-setup.log

# read_state sets phase (pending, running, done or failed) and, while
# running, setup_pid from the state file.
read_state() {
    phase=none setup_pid=""
    read -r phase setup_pid < "$state_file" 2>/dev/null || true
}
setup_running() { [[ -n "$setup_pid" ]] && kill -0 "$setup_pid" 2>/dev/null; }

read_state
case "$phase" in
    pending | running) ;;
    *) exit 0 ;;
esac

# A state left behind by a setup that was interrupted (the Codespace stopped
# mid-setup) would otherwise make every terminal wait forever.
if [[ "$phase" == running ]] && ! setup_running; then
    exit 0
fi

printf '\033[1;36m==> Codespace setup is still running; following its progress here.\033[0m\n'
printf '    Ctrl-C stops watching; setup keeps going in the background.\n\n'

tail -n +1 -F "$log" 2>/dev/null &
tail_pid=$!
trap 'kill "$tail_pid" 2>/dev/null; printf "\nStopped watching. Setup continues; open a new terminal to watch again.\n"; exit 0' INT

waited=0
while :; do
    read_state
    case "$phase" in
        done | failed) break ;;
        running) setup_running || break ;;
        pending)
            # postCreateCommand normally starts within seconds of the editor
            # connecting; stop waiting if it never does.
            (( waited >= 300 )) && break
            ;;
    esac
    sleep 1
    waited=$((waited + 1))
done

sleep 1 # let tail print setup's last lines
kill "$tail_pid" 2>/dev/null
wait "$tail_pid" 2>/dev/null

read_state
case "$phase" in
    done) printf '\n\033[1;32m==> Codespace setup finished. Next: just lab-up\033[0m\n\n' ;;
    failed) printf '\n\033[1;31m==> Codespace setup failed; see the errors above, or Codespaces: View Creation Log.\033[0m\n\n' ;;
    *) printf '\n==> Stopped watching setup; check Codespaces: View Creation Log.\n\n' ;;
esac
