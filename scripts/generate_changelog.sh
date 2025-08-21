#!/bin/bash

generate_changelog() {
  local new_version="$1"
  local ref="${2:-HEAD}"

  local previous_tag
  previous_tag=$(git tag --list '[0-9]*' --sort=-v:refname | head -n 1)

  if [[ -n "$previous_tag" ]]; then
    local changelog_content
    changelog_content=$(git log "${previous_tag}".."${ref}" --pretty=format:"- %s (%ae)" --no-merges \
      | grep -v "docs: update changelog for version" \
      | sed -E 's/.*\+([^@]+)@.*/- \1/')

    if [[ -z "$changelog_content" ]]; then
      changelog_content="- No changes detected"
    fi

    local new_changelog="## ${new_version} - $(date +%Y-%m-%d)\n${changelog_content}\n"

    if [[ -f CHANGELOG.md ]]; then
      local old_content
      old_content=$(cat CHANGELOG.md)
      echo -e "${new_changelog}\n${old_content}" > CHANGELOG.md
      git add CHANGELOG.md
      git commit -m "docs: update changelog for version ${new_version}"
      git push origin "$ref"
    fi
  fi
}

generate_changelog "$1" "$2"