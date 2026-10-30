#!/usr/bin/env bash
# Rebuild NixOS from this flake, recording each generation in git.
# This trial config installs no bootloader; run ./sync-limine.sh after a
# kernel change to refresh the copies on the shared ESP.
#
# Usage: rebuild.sh [--force] [commit subject] [body paragraph...]
#   Commits pending work FIRST (so the generation records an exact rev via
#   system.configurationRevision), then builds, switches, and adds an empty
#   "rebuild: gen N" commit holding the commit shortlog and the nvd diff.
#   With no args the work commit is "wip: <timestamp>", meant to be rewritten.
#   Runs on a clean tree too, as long as HEAD moved since the last rebuild —
#   that's the manual-commit workflow.
#   --force: rebuild regardless, and don't touch git at all.
#
# See docs/adr/0001-two-commit-rebuild-protocol.md.
#
# ponytail: nothing is staged for you — `git commit -a` only sweeps tracked
# files. New files stay untracked (and so invisible to the flake) until you
# `git add` them yourself, on purpose.

set -euo pipefail
cd "$(dirname "$0")"

force=0
if [ "${1:-}" = "--force" ]; then force=1; shift; fi

# Before any dirty check, so there is only one post-format state to reason about.
alejandra -q . || { echo "formatting failed!"; exit 1; }

# Nix computes dirtiness over the whole tree, so any tracked change counts.
dirty=0
git diff HEAD --quiet || dirty=1
last_rebuild="$(git log -1 --format=%H --grep='^rebuild: gen ')"

if [ "$force" = 0 ] && [ "$dirty" = 0 ] && [ "$(git rev-parse HEAD)" = "$last_rebuild" ]; then
    echo "Nothing to rebuild."
    exit 0
fi

# Print Git Diff and create WIP commit
committed=0
if [ "$force" = 0 ] && [ "$dirty" = 1 ]; then
    git diff HEAD -U0
    subject="${1:-wip: $(date -Iseconds)}"
    [ $# -eq 0 ] || shift
    printf '%s\n\n' "$subject" "$@" | git commit -a --cleanup=verbatim -F -
    committed=1
fi

# Attempt build if build fails reset 1 soft
echo "NixOS rebuilding..."
build_start=$SECONDS
nixos-rebuild build --flake .#NixIsland --log-format internal-json -v 2>&1 |
    nom --json ||
    { [ "$committed" = 0 ] || git reset --soft HEAD~1; exit 1; }
build_secs=$((SECONDS - build_start))
printf '\nBuild time: %dm%02ds\n' $((build_secs / 60)) $((build_secs % 60))

system_path="$(readlink -f result)"

# Captured output isn't a tty, so force colour on and strip it for the commit.
nvd_out="$(nvd --color=always diff /run/current-system result)"
printf '%s\n' "$nvd_out"

# A failed switch keeps the work commit: it built, so it belongs on the branch.
sudo nixos-rebuild switch --no-reexec --store-path "$system_path"

# ponytail: the switch restarts polkitd, and an agent's registration dies with
# it — soteria keeps running but can no longer prompt, so pkexec just fails.
systemctl --user restart polkit-soteria.service || true

if [ "$force" = 0 ]; then
    gen="$(readlink /nix/var/nix/profiles/system | tr -dc 0-9)"
    {
        printf 'rebuild: gen %s\n\n' "$gen"
        [ -z "$last_rebuild" ] || git log --oneline "$last_rebuild"..HEAD | sed 's/^/    /'
        printf '\nnvd diff:\n\n```text\n%s\n```\n' "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$nvd_out")"
    } | git commit --allow-empty --cleanup=verbatim -F -
fi

command -v notify-send >/dev/null && notify-send -e "NixOS rebuilt OK" || true
