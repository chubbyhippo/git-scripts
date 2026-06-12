# pick-missing.sh

A POSIX-compliant shell script that cherry-picks commits from another branch
whose commit messages (subjects) do **not** already exist on the current
branch, optionally limited to a date/time range.

This is useful when branches have diverged and commits were rebased,
squashed, or re-created with different hashes — comparing by commit message
catches duplicates that hash-based ranges like `HEAD..other-branch` miss.

## Requirements

- `git`
- Any POSIX shell (`sh`, `dash`, `bash`, `ksh`, ...)
- `grep` (POSIX, with the common `-F`/`-x`/`-q` flags)

No temporary files are created; everything is held in shell variables.

## Installation

```sh
chmod +x pick-missing.sh
# optionally put it on your PATH:
mv pick-missing.sh /usr/local/bin/pick-missing
```

## Usage

```sh
./pick-missing.sh [-n] <other-branch> [since] [until]
```

| Argument | Description | Default |
|---|---|---|
| `-n` | Dry run: list the commits that would be picked, change nothing | off |
| `other-branch` | Branch (or any ref/commit) to pick commits from | required |
| `since` | Start of the date/time range | beginning of history |
| `until` | End of the date/time range | `now` |

`since` and `until` accept anything `git log --since/--until` accepts:

- `"2026-06-01"`
- `"2026-06-01 14:30"`
- `"2026-06-01T14:30:00"`
- `"2 weeks ago"`, `"yesterday 9am"`

### Examples

```sh
# Dry run: see what would be picked from feature-x
./pick-missing.sh -n feature-x

# Pick everything from feature-x not present (by message) on the current branch
./pick-missing.sh feature-x

# Limit to a date/time window
./pick-missing.sh feature-x "2026-06-01 09:00" "2026-06-10 18:00"

# Relative dates work too
./pick-missing.sh feature-x "2 weeks ago"
```

## How it works

1. Collects all commit subjects (`%s`, the first line of each message) on the
   current branch into a shell variable.
2. Walks the other branch oldest-first (`--reverse`), skipping merge commits
   (`--no-merges`), within the optional `--since`/`--until` range.
3. For each commit, checks for an exact whole-line subject match
   (`grep -Fxq`). If the subject is not found on the current branch, the
   commit is cherry-picked.

The loop reads from a here-document rather than a pipe, so it runs in the
current shell — a cherry-pick conflict cleanly stops the whole script.

## Conflict handling

If a cherry-pick conflicts, the script stops and tells you. Then:

```sh
# resolve the conflict, stage the files, and:
git cherry-pick --continue

# then simply re-run the script:
./pick-missing.sh feature-x "2026-06-01" "2026-06-10"
```

Re-running is safe: commits already picked now exist on the current branch
with the same subject, so they are skipped automatically.

## Caveats

- **Matching is by subject line only.** If your history contains many
  commits with identical generic subjects (e.g. `update`, `wip`), those will
  be wrongly treated as duplicates and skipped. Use a dry run (`-n`) first.
- **Merge commits are skipped** (`--no-merges`), since cherry-picking merges
  requires choosing a parent and is rarely what you want in bulk.
- **Date filtering uses commit dates**, which can differ from author dates
  if commits were rebased.
- The script refuses to start if another cherry-pick is already in progress.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (including "nothing to pick") |
| 1 | Runtime error (not a repo, bad ref, conflict, cherry-pick in progress) |
| 2 | Usage error |
