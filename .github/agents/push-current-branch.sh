#!/usr/bin/env bash
set -u

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
git_dir=$(git -C "$repo_root" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
marker="$git_dir/copilot-auto-push-pending"

if [[ ! -f "$marker" ]]; then
  exit 0
fi

rm -f "$marker"

if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
  printf '%s\n' '{"systemMessage":"Auto-push skipped: the worktree is not clean. Review and commit the remaining changes manually."}'
  exit 0
fi

if ! git -C "$repo_root" symbolic-ref --quiet --short HEAD >/dev/null; then
  printf '%s\n' '{"systemMessage":"Auto-push skipped: HEAD is detached."}'
  exit 0
fi

if git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
  if git -C "$repo_root" push; then
    printf '%s\n' '{"systemMessage":"Committed changes pushed to the current branch."}'
  else
    printf '%s\n' '{"systemMessage":"Auto-push failed. Check remote access, branch protection, and Git output."}'
    exit 1
  fi
else
  if git -C "$repo_root" push --set-upstream origin HEAD; then
    printf '%s\n' '{"systemMessage":"Committed changes pushed to origin and upstream tracking was configured."}'
  else
    printf '%s\n' '{"systemMessage":"Auto-push failed. Check the origin remote, access, branch protection, and Git output."}'
    exit 1
  fi
fi