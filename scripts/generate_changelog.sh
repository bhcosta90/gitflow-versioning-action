#!/bin/bash

set -euo pipefail

# Resolve the branch to push changes to
resolve_branch() {
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    echo "$GITHUB_REF_NAME"; return
  fi
  if [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
    echo "$GITHUB_HEAD_REF"; return
  fi
  if [[ -n "${GITHUB_REF:-}" ]]; then
    if [[ "$GITHUB_REF" == refs/heads/* ]]; then
      echo "${GITHUB_REF#refs/heads/}"; return
    fi
  fi
  # Try current branch
  local br
  br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ -n "$br" && "$br" != "HEAD" ]]; then
    echo "$br"; return
  fi
  # Fallback to remote default branch (origin/HEAD)
  br=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  echo "$br"
}

generate_changelog() {
  local new_version="$1"
  local ref="${2:-HEAD}"

  # Basic git config for CI environments (e.g., GitHub Actions)
  git config --global --add safe.directory "$(pwd)" || true
  git config --global user.email "${GIT_AUTHOR_EMAIL:-actions@github.com}" || true
  git config --global user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}" || true

  local previous_tag
  previous_tag=$(git tag --list '[0-9]*' --sort=-v:refname | head -n 1)

  if [[ -n "$previous_tag" ]]; then
    local changelog_content
    changelog_content=$(git log "${previous_tag}".."${ref}" --pretty=format:"- %s (%ae)" --no-merges \
      | grep -v "docs: update changelog for version" || true)

    if [[ -z "$changelog_content" ]]; then
      changelog_content="- No changes detected"
    fi

    local new_changelog="## ${new_version} - $(date +%Y-%m-%d)\n${changelog_content}\n"

    # Ensure the file exists
    if [[ ! -f CHANGELOG.md ]]; then
      touch CHANGELOG.md
    fi

    # Prepend new content to the changelog
    local old_content
    old_content=$(cat CHANGELOG.md)
    echo -e "${new_changelog}\n${old_content}" > CHANGELOG.md

    # Stage and commit only if there are actual changes
    if ! git diff --quiet -- CHANGELOG.md; then
      git add CHANGELOG.md
      git commit -m "docs: update changelog for version ${new_version}" || true

      # Determine branch and push
      local branch
      branch=$(resolve_branch)
      if [[ -n "$branch" ]]; then
        # Use HEAD:<branch> to handle detached HEAD
        git push origin "HEAD:${branch}"
      else
        # Fallback: try a simple push (may fail in detached HEAD)
        git push
      fi
    fi
  fi
}

generate_changelog "$1" "$2"