# Gitflow Versioning Action

Automates Git Flow-style versioning with incremental tag creation and optional CHANGELOG.md updates.

This Action creates tags for development cycles (dev), release series, and package finalization, and maintains auxiliary branches (develop/{major}x, release/{major}x) when appropriate.

## Table of Contents
- What this Action does
- Prerequisites and permissions
- Inputs
- Execution modes (mode)
- Usage examples (workflows)
- Branch and tag conventions
- Tips and troubleshooting

## What this Action does
- Automatically generates tags based on the existing tag history.
- Maintains semantic versioning (MAJOR.MINOR.PATCH) for releases.
- Creates pre-release development tags in the format dev-MAJOR.MINOR.PATCH.
- Creates/ensures auxiliary branches develop/{major}x and {major}.x (release branch) when applicable.
- Updates the CHANGELOG.md file when finalizing a package (optional, via input).
- Removes dev-* tags when a release is finalized.

## Prerequisites and permissions
- The repository must use semantic release tags in the X.Y.Z format (numbers and dots only) so the "latest release" can be detected.
- This Action uses git to:
  - create and push tags;
  - create and push branches;
  - commit changes to CHANGELOG.md (when applicable).
- Ensure that GITHUB_TOKEN (or the checkout token) has write permission to contents:
  
  permissions:
    contents: write

- This Action already includes a checkout step with fetch-depth: 0 to access the full history, which is required to read older tags. If you override checkout in your workflow, keep fetch-depth: 0.

## Inputs
- mode (required): defines the execution mode. Supported values:
  - dev, dev-branch, release-branch, finalize-package, finalize-release, release-patch, develop-patch
- branch (optional): base name used in dev-branch and release-branch (e.g., "feature/login" or "1x").
- changelog_entry (optional): text to be added to CHANGELOG.md when using finalize-package.

There are no outputs defined by this Action.

## Execution modes (mode)
Below is a summary of each mode's behavior.

1) dev
- Calculates the next development tag based on the latest X.Y.Z release tag.
- Rules:
  - If there is no previous release, assume 0.0 as the base.
  - Increments the MINOR of the latest release and manages sequential PATCH for dev.
  - Format: dev-MAJOR.MINOR.PATCH
- Example: if the latest release is 1.4.2, the next dev will be dev-1.5.0 (or dev-1.5.N depending on existing tags).

2) dev-branch
- Creates incremental tags based on the provided "branch" value.
- Format: {branch}.{patch}
- Example: branch=feature/login → feature/login.0, feature/login.1, ...

3) release-branch
- Similar to dev-branch, but typically used for release branches.
- Format: {branch}.{patch}
- Example: branch=1x → 1x.0, 1x.1, ...

4) finalize-package
- Defines the next final release tag:
  - If no previous release exists: 0.0.0
  - Otherwise: keep MAJOR, increment MINOR, and reset PATCH → MAJOR.(MINOR+1).0
- If changelog_entry is provided:
  - Adds a section "## X.Y.Z (YYYY-MM-DD)" to CHANGELOG.md with the provided content.
  - Commits and pushes this change to the current branch.
- Creates/ensures the develop/{major}x branch for the release MAJOR.
- Removes all dev-* tags (local and remote).

5) finalize-release
- Creates the first tag of a new MAJOR series:
  - If no previous release exists: creates 1.0.0
  - Otherwise: new_major = last MAJOR + 1 → new_major.0.0
- Creates the release branch {branch_major}.x, where branch_major is the MAJOR of the previous series.
- Ensures the develop/{new_major}x branch for the new series.
- Removes all dev-* tags and deletes old remote develop/* branches, except the new develop/{new_major}x.

6) release-patch
- To be used on {major}.x branches.
- Reads MAJOR from the branch name (e.g., 1x → 1).
- Finds the latest tag 1.*.* and increments PATCH.
- Creates and pushes the new tag 1.MINOR.PATCH.

7) develop-patch
- To be used on develop/{major}x branches.
- Increments PATCH within the current MAJOR series, based on the latest tag found for that series.
- Note: the script tries to infer the series from the latest tag {series}.*. If it’s the first time, it starts at patch 0.

Note: Some behavior depends on the tag history and the current checkout branch.

## Usage examples (workflows)
Quick start: minimal workflow integrating this Action (mirrors .github/workflows/gitflow.yaml)

```yaml
name: Git Flow Automation
on:
  push:
    branches: [main, master, 'hotfix/*', '*.*']
  workflow_dispatch:
    inputs:
      mode:
        description: 'Choose Action mode'
        required: true
        type: choice
        options: [finalize-package, finalize-release]
        default: finalize-package

jobs:
  gitflow:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: {fetch-depth: 0}
      - name: Run Gitflow Versioning
        uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.mode || github.ref == 'refs/heads/main' && 'dev' || startsWith(github.ref, 'refs/heads/hotfix') && 'hotfix-patch' || (contains(github.ref, '.x') && !startsWith(github.ref, 'refs/heads/hotfix')) && 'release-patch' }}
          changelog_entry: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.changelog_entry || '' }}
```

Below is a workflow that covers common scenarios:

name: Git Flow Automation

on:
  push:
    branches:
      - main
      - 'develop/*'
      - '*.*'
  workflow_dispatch:
    inputs:
      mode:
        description: 'Choose Action mode'
        required: true
        type: choice
        options:
          - finalize-package
          - finalize-release
        default: finalize-package
      changelog_entry:
        description: 'Notes for CHANGELOG'
        required: false

jobs:
  dev-tag:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: dev

  develop-patch:
    if: contains(github.ref, 'refs/heads/develop/')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: develop-patch

  release-patch:
    if: contains(github.ref, '.x') && !contains(github.ref, 'refs/heads/hotfix/')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: release-patch

  workflow-dispatch:
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: ${{ github.event.inputs.mode }}
          changelog_entry: ${{ github.event.inputs.changelog_entry }}

### Other examples
- Generate a tag for an arbitrary branch (dev-branch):

jobs:
  tag-feature:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: dev-branch
          branch: feature/login

- Generate a tag for a specific release branch (release-branch):

jobs:
  tag-release-branch:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: release-branch
          branch: 1x

- Finalize a package with changelog update (finalize-package):

jobs:
  finalize:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: finalize-package
          changelog_entry: |
            - feat: new /metrics endpoint
            - fix: fix NPE in OrderService

## Branch and tag conventions
- Releases: tags in the format X.Y.Z (digits and dots only).
- Dev tags: dev-MAJOR.MINOR.PATCH.
- Development branches: develop/{major}x (e.g., develop/1x, develop/2x).
- Release branches: {major}.x (e.g., 1x, 2x).

## Tips and troubleshooting
- Insufficient permissions:
  - Errors when pushing tags/commits usually indicate missing permissions.contents: write.
- Tag history not found:
  - Ensure fetch-depth: 0 in checkout (already configured internally by this Action).
- Conflicts in CHANGELOG.md:
  - If multiple jobs try to write to CHANGELOG simultaneously, serialize executions or restrict triggers.
- "tag already exists":
  - Indicates that the tag was created by another job/run. Re-running may generate the next patch automatically depending on the mode.
- Current branch does not match the mode:
  - release-patch should run on {major}.x, develop-patch on develop/{major}x. Adjust workflow conditions accordingly.

## Development
- The Makefile includes helper targets:
  - make date: writes date/time to the version file and commits/pushes.
  - make delete-tag version=MAJOR.MINOR: removes all tags starting with that prefix (e.g., 1.2.*).

## License
This repository follows the license defined by the author. See the LICENSE file if available.

## Author
- bhcosta90