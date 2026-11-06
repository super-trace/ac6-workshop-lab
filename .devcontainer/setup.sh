#!/usr/bin/env bash
set -euo pipefail

# Codespaces shows this script's output only in the creation log, so it also
# goes to a log file that setup-progress.sh streams into every new terminal
# while setup runs. The state file says whether setup is running (and as
# which process), done or failed.
log=/tmp/ac6-workshop-setup.log
state_file=/tmp/ac6-workshop-setup.state
echo "running $$" > "$state_file"
exec > >(tee "$log") 2>&1
trap 'status=$?; if (( status == 0 )); then echo done; else echo failed; fi > "$state_file"' EXIT

# step prints a numbered, timestamped banner, so the creation log (Codespaces:
# View Creation Log, or `gh codespace logs`) shows which step is running and
# how long each took. The ERR trap names the step that failed.
total_steps=4
step_number=0
current_step="starting"
step() {
    step_number=$((step_number + 1))
    current_step="$*"
    printf '\n\033[1;36m==> [%d/%d] [%s] %s\033[0m\n' \
        "$step_number" "$total_steps" "$(date +%T)" "$current_step"
}
trap 'echo "!! setup failed during: ${current_step}" >&2' ERR

# just — not preinstalled on the base devcontainer image. postCreateCommand
# runs as the non-root default user (vscode), which can't write to
# /usr/local/bin directly — sudo (passwordless for this user, standard on
# devcontainer base images) is required here.
step "Installing just"
curl --proto '=https' --tlsv1.2 -fS --progress-bar https://just.systems/install.sh \
    | sudo bash -s -- --to /usr/local/bin
just --version

# docker-in-docker's nested dockerd starts in the background and isn't
# necessarily ready the moment postCreateCommand runs — confirmed live
# ("failed to connect to the docker API ... no such file or directory" on
# an otherwise-clean build). Wait for the socket rather than racing it.
step "Waiting for dockerd"
for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
done
docker info >/dev/null 2>&1 || { echo "dockerd never became ready" >&2; exit 1; }
echo "dockerd ready after ${i}s ($(docker version --format '{{.Server.Version}}'))"

# Codespaces supplies registry credentials for this repository's private package.
step "Pulling lab images, installing SSH config (just lab-setup)"
cd "$(dirname "$0")/.."
just lab-setup

step "Summary"
docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}'
free -h | head -2
df -h / | tail -1

echo ""
echo "Setup complete. Next: install stcli (README step 2), then: just lab-up    then: just verify"
echo "SSH ports 2401 (nokia) and 2402 (arista) auto-forward — VS Code Ports tab, or"
echo "'gh codespace ports forward'."
