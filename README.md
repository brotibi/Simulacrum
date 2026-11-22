# Simulacrum

A 3D game built with Godot 4.7.

## Repository Structure (Git Worktrees)

This workspace uses a bare Git repository (`.bare/`) with worktrees:

- `main/` — Primary `main` branch worktree
- `dev/` — Development `dev` branch worktree

### Managing Worktrees

```bash
# List active worktrees
git worktree list

# Add a new feature worktree
git worktree add -b feature/my-feature feature-my-feature main

# Remove a worktree when done
git worktree remove feature-my-feature
```
