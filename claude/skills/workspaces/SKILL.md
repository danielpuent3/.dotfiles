---
name: workspaces
version: 2.0.0
description: Manage and work within Streamlabs workspaces — scoped multi-repo Claude Code sessions at ~/Code/streamlabs-workspaces/.
---

# Streamlabs Workspaces

A workspace is a directory inside `~/Code/streamlabs-workspaces/` that combines a curated set of repos via symlinks, giving Claude a focused, scoped session instead of navigating the full 15+ repo docker-environment root.

## Why Workspaces Exist

Starting Claude in `streamlabs-docker-environment/` gives it too much surface area to build accurate context. Workspaces solve this by:

- Exposing only the repos relevant to today's work
- Including a `CLAUDE.md` that describes how the repos interact
- Keeping the session focused on a specific feature or service boundary

## Directory Convention

```
~/Code/streamlabs-workspaces/
  <workspace-name>/
    CLAUDE.md                    ← loaded on claude startup; describes the workspace
    <repo-name>                  ← absolute symlink → actual repo path
```

Symlinks use **absolute paths** (e.g. `/Users/danielpuente/Code/streamlabs-docker-environment/<repo>`).

## How to Use a Workspace

```bash
cd ~/Code/streamlabs-workspaces/<workspace-name>
claude
```

## Important Limitation

Grep and Glob tools do **not** follow symlinks. When cross-repo search is needed, use `Read` with explicit absolute paths. Each workspace's `CLAUDE.md` lists the real paths so Claude can navigate directly.

## Creating a New Workspace

1. Create the workspace directory:
   ```bash
   mkdir ~/Code/streamlabs-workspaces/<workspace-name>
   cd ~/Code/streamlabs-workspaces/<workspace-name>
   ```

2. Add absolute symlinks for each repo:
   ```bash
   ln -s /Users/danielpuente/Code/streamlabs-docker-environment/<repo> <repo>
   ```

3. Create a `CLAUDE.md`:

   ```markdown
   # Workspace: <workspace-name>

   <one-line description>

   ## Repos in scope

   | Symlink | Real path | Purpose |
   |---|---|---|
   | `<repo>/` | `.../streamlabs-docker-environment/<repo>` | <what it does> |

   ## Sub-Repo Context Loading

   Before working in each repo, read its CLAUDE.md. For `streamlabs-identity-api`,
   also load `.agents/skills/` and `.github/copilot-instructions.md` in that order.

   ## How these repos interact

   <describe service boundaries, which calls which, shared auth, etc.>
   ```

4. Commit the workspace to the streamlabs-workspaces repo:
   ```bash
   cd ~/Code/streamlabs-workspaces
   git add <workspace-name>
   git commit -m "Add <workspace-name> workspace"
   ```

## Existing Workspaces

| Workspace | Repos | Use case |
|---|---|---|
| `sl-web-identity` | `streamlabs.com`, `streamlabs-identity-api` | Streamlabs.com frontend + identity backend |
| `streamlabs-identity` | `streamlabs-identity-api`, `streamlabs-identity-web`, `ultra-web` | Full identity/billing stack |

## Persistence

- `~/Code/streamlabs-workspaces/` is its own git repo — commit workspaces to track them.
- This skill lives in `~/.dotfiles/claude/skills/workspaces/` and is symlinked to `~/.claude/skills/workspaces/` by `setup.sh`.
