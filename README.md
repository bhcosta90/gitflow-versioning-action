# Gitflow Versioning Action

GitHub Action for automated semantic versioning based on a simple Gitflow-like strategy.

This composite action helps you:
- Generate development (pre-release) tags from main/master using a predictable pattern.
- Maintain MAJOR.x maintenance branches.
- Create patch releases from MAJOR.x branches.
- Finalize a development cycle by promoting the current dev version to a stable tag.

The action operates only with Git tags and branches; it does not modify files in your repository.

## Tagging Strategy

- On main/master:
  - Detects the latest stable tag in the repository (numeric pattern like `1.4.2`).
  - Computes the next base minor for the upcoming release line as `MAJOR.(MINOR+1).0`.
  - Ensures the maintenance branch `MAJOR.x` exists (creates and pushes it if missing).
  - Creates and pushes a development tag: `dev-<BASE_VERSION>-<N>-rc`, where `<BASE_VERSION>` is `MAJOR.(MINOR+1).0` and `<N>` is an incrementing sequence starting at 0.

- On `MAJOR.x` branches (e.g., `1.x`):
  - Finds the latest tag matching `MAJOR.*`.
  - Increments the patch number and creates a new patch tag: `MAJOR.0.<next_patch>`.

- When run with `mode: package` (Finalize package):
  - Recomputes the current dev cycle base version as on main/master.
  - Keeps only the latest `dev-<BASE_VERSION>-*-rc` tag for that base, deletes older dev tags for the same MAJOR.MINOR line.
  - Creates a stable tag `MAJOR.MINOR.PATCH` (based on the current dev base’s `MAJOR.MINOR.0`).

Notes:
- The action relies on your repository’s existing tags to determine the next versions.
- Tags are pushed to `origin`. Ensure your workflow has proper permissions and that the repository is checked out with full history.

## Inputs

- `mode` (required, default: `auto`)
  - `auto`: normal behavior (main/master creates dev tags; MAJOR.x creates patch tags)
  - `package`: finalize the current dev cycle and create a stable tag

## Requirements

- You must checkout the repository before using this action (with full history to get tags).
- The workflow must have permission to push tags: `permissions: contents: write`.
- Ensure `fetch-depth: 0` when checking out to fetch all tags and history.

## Usage Examples

### Single workflow handling Auto and Finalize

Use one workflow to handle both development/patch tagging (on push) and manual finalize (workflow_dispatch).

```yaml
name: Versioning - All-in-One

on:
  push:
    branches:
      - main
      - master
      - "[0-9]+.x"  # e.g., 1.x, 2.x
  workflow_dispatch:

permissions:
  contents: write

jobs:
  version-auto:
    if: ${{ github.event_name == 'push' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Versioning Action (auto)
        uses: bhcosta90/gitflow-versioning-action@1.0.0
        with:
          mode: auto

  finalize:
    if: ${{ github.event_name == 'workflow_dispatch' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Versioning Action (package)
        uses: bhcosta90/gitflow-versioning-action@1.0.0
        with:
          mode: package
```

## How it Works (Internals)

The action is defined as a composite action (action.yaml) and performs:
- Git configuration for the bot user.
- Fetches all tags and determines the current branch.
- On main/master, it:
  - Finds the latest stable numeric tag (`[0-9]*`), calculates the next minor base, ensures `MAJOR.x` exists, and creates a `dev-<BASE>-<seq>-rc` tag.
- On `MAJOR.x`, it:
  - Creates a new patch tag `MAJOR.0.<next_patch>` incrementing from the latest `MAJOR.*` tag.
- With `mode: package`, it:
  - Keeps only the most recent dev tag for the current base and promotes it to a stable `MAJOR.MINOR.PATCH` tag.

## Troubleshooting

- No tags found: The action will start from `0.0.0` as a baseline.
- Permission denied when pushing: Ensure `permissions: contents: write` is set and that the workflow runs on a branch where the token has rights.
- Missing tags or incorrect version detection: Ensure checkout uses `fetch-depth: 0` so that all tags are available locally.

## License

MIT (or the license of this repository if different).
