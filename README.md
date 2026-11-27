# Simulacrum

A first-person PS1 / Silent Hill stylized 3D game built with Godot 4.7.

## Running the Game

```bash
godot --path /home/olaoluwa/dev/Simulacrum/dev
```

### Controls
- **Move**: `W` / `A` / `S` / `D`
- **Look**: Mouse (`Esc` to release/capture cursor)
- **Jump / Wall Jump**: `Space`
- **Flashlight Toggle**: `F`

---

## Simulacrum Studio (Cross-Platform Object & Room Builder)

**Simulacrum Studio** is a built-in visual authoring program that runs natively on **Arch Linux** and **macOS (Apple Silicon)** using Godot 4.

### Launching Simulacrum Studio

From either Arch Linux or macOS Apple Silicon:

```bash
./run_studio.sh
```
*(Or directly via `godot --path . res://tools/simulacrum_studio.tscn`)*

### Features

1. **Object Editor (`1. Object Editor`)**:
   - Build single-mesh or composite multi-part 3D objects (`box`, `cylinder`, `sphere`, `prism`, `plane`, or custom `.glb`/`.gltf`/`.obj` models via `res://`).
   - Live 3D PS1 preview viewport (`426x240` with 15-bit RGB555 Bayer dithering, orbit/pan/zoom camera, and turntable mode).
   - Apply procedural low-res PS1 textures (`concrete`, `rust`, `bricks`, `tiles`, `checker`, `grate`) or custom image textures (`res://assets/textures/...`).
   - Tune PS1 shader effects per part: **Albedo Tint**, **UV Tiling**, **Vertex Snapping (Jitter Grid)**, **Affine Texture Warping**, and **Distance Vertex Darkening**.
   - Optional attached `OmniLight3D` with customizable color, energy, and range.
   - Saves both re-editable JSON configs (`content/objects/<name>.json`) and ready-to-use Godot scenes (`scenes/objects/<name>.tscn`).

2. **Room Editor (`2. Room Editor`)**:
   - Configure room dimensions (`Width`, `Height`, `Depth`), toggle floor, ceiling, and walls (`North`, `South`, `East`, `West`), customize floor/ceiling thickness, Y-offsets, and PS1 subdivisions, and configure skyboxes (`procedural_sky`, `solid_color`, `custom_panorama`) and Silent Hill depth fog.
   - Place saved objects from your Object Library into the room, duplicate/delete items, and modify their 3D position (via SpinBoxes or interactive 3D RGB X/Y/Z vector arrows), rotation, and scale with live 3D preview.
   - Add and position room lights (`OmniLight3D`) with custom color, energy, and range.
   - Saves both `content/rooms/<name>.json` and `scenes/rooms/<name>.tscn` (or one-click export directly to `res://scenes/main.tscn`).

3. **Shader Editor (`3. Shader Editor`)**:
   - Built-in `.gdshader` code editor (`CodeEdit`) with line numbers, auto-indentation, brace matching, and Godot shader syntax highlighting.
   - Load existing shaders (`ps1_surface`, `ps1_post_process`, or custom shaders), start from `+ New 3D Spatial` or `+ New Post-FX` templates, and save directly to `res://shaders/<name>.gdshader`.
   - Live 3D environment preview (`Sphere + Box + Floor Showcase`, `Current Edited Object`, or `Current Edited Room`) that compiles and previews both `spatial` 3D surface shaders and `canvas_item` fullscreen post-processing shaders in real time.
   - Saved spatial shaders automatically appear in the **Shader File** dropdowns inside both the Object Editor and Room Editor.

---

## Repository Structure (Git Worktrees)

This workspace uses a bare Git repository (`.bare/`) with worktrees:

- `main/` — Primary `main` branch worktree
- `dev/` — Development `dev` branch worktree
