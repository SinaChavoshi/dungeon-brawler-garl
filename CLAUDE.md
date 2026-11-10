# Notes for Claude

## Working agreement
- The owner (sina) has said: merge your own PRs without waiting for their review, unless the change truly needs a human (for example licensing or legal questions, deleting work, changes to repo settings, or a design call that changes the game's direction). Open a PR, make sure any CI is green, merge it, and say what you merged in the project thread.
- Keep everything original: no text, art or characters copied from any book or game. Use the stand-in cast in `docs/GAME_DESIGN.md`.

## Project
- Godot 4.3+, GDScript. Desktop uses Forward+; the web export falls back to Compatibility (`rendering_method.web`). Check `Level.high_quality()` before using Forward+-only features.
- Low-poly 3D with an MMO-style third-person camera and controls (see `scripts/player.gd`).
- Caves, textures, Garl's model and icons come from Python generators in `tools/`; rerun them rather than hand-editing the outputs.
- CI saves desktop screenshots (`godot -- --screenshot=DIR`) and web screenshots, printed as base64 in the log.
- Code is Apache 2.0. Assets must be CC0 or original, with their license noted next to them in `assets/`.
- Scenes are in `scenes/`, scripts in `scripts/`, design notes in `docs/`.
