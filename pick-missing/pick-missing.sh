#!/bin/sh
# pick-missing.sh
#
# Cherry-pick commits from another branch whose commit messages (subjects)
# do not exist on the current branch, optionally limited to a date/time range.
#
# Usage:
#   ./pick-missing.sh [-n] <other-branch> [since] [until]
#
#   -n        dry run: only list the commits that would be picked
#   since     e.g. "2026-06-01 09:00", "2 weeks ago" (default: beginning of time)
#   until     e.g. "2026-06-10 18:00", "now"         (default: now)
#
# Examples:
#   ./pick-missing.sh feature-x
#   ./pick-missing.sh feature-x "2026-06-01 09:00" "2026-06-10 18:00"
#   ./pick-missing.sh -n feature-x "2 weeks ago"

set -u

DRY_RUN=0
if [ "${1:-}" = "-n" ]; then
    DRY_RUN=1
    shift
fi

OTHER="${1:-}"
SINCE="${2:-}"
UNTIL="${3:-now}"

usage() {
    printf 'Usage: %s [-n] <other-branch> [since] [until]\n' "$0" >&2
    exit 2
}

[ -n "$OTHER" ] || usage

# Make sure we are inside a git repository.
git rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'Error: not a git repository.\n' >&2
    exit 1
}

# Make sure the other branch (or any ref/commit) exists.
git rev-parse --verify --quiet "$OTHER^{commit}" >/dev/null || {
    printf 'Error: branch or ref not found: %s\n' "$OTHER" >&2
    exit 1
}

# Refuse to run with a cherry-pick already in progress.
if [ -e "$(git rev-parse --git-dir)/CHERRY_PICK_HEAD" ]; then
    printf 'Error: a cherry-pick is already in progress.\n' >&2
    printf 'Resolve it (git cherry-pick --continue|--abort) and re-run.\n' >&2
    exit 1
fi

# All commit subjects on the current branch, kept in memory.
current_msgs=$(git log --format='%s')

# Candidate commits on the other branch, oldest first, within the date range.
if [ -n "$SINCE" ]; then
    candidates=$(git log "$OTHER" --since="$SINCE" --until="$UNTIL" \
        --reverse --no-merges --format='%H %s')
else
    candidates=$(git log "$OTHER" --until="$UNTIL" \
        --reverse --no-merges --format='%H %s')
fi

if [ -z "$candidates" ]; then
    printf 'No commits found on %s in the given range.\n' "$OTHER"
    exit 0
fi

picked=0

# Here-document keeps the loop in the current shell (no subshell),
# so 'exit' on conflict stops the whole script.
while IFS=' ' read -r hash msg; do
    [ -n "$hash" ] || continue

    # Skip if an identical subject already exists on the current branch.
    if printf '%s\n' "$current_msgs" | grep -Fxq -- "$msg"; then
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'Would pick: %s %s\n' "$hash" "$msg"
    else
        printf 'Picking: %s %s\n' "$hash" "$msg"
        if ! git cherry-pick "$hash"; then
            printf '\nConflict on %s.\n' "$hash" >&2
            printf 'Resolve it, run "git cherry-pick --continue", then re-run this script;\n' >&2
            printf 'already-picked commits will be skipped automatically.\n' >&2
            exit 1
        fi
    fi
    picked=$((picked + 1))
done <<EOF
$candidates
EOF

if [ "$DRY_RUN" -eq 1 ]; then
    printf '%d commit(s) would be picked.\n' "$picked"
else
    printf 'Done: %d commit(s) picked.\n' "$picked"
fi
