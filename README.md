# Comfymaid

Godot 4.x 2D platformer vertical slice with Hollow Knight-like movement. The project is a minimal skeleton: Hub and BossRoom, placeholder player and boss, scene transitions, basic HUD, and a SceneManager that keeps the player persistent across levels.

## Current Status
- Vertical slice runs with two scenes: `Hub` and `BossRoom`.
- Player can move left/right and jump with coyote time, jump buffer, and max fall speed.
- Boss placeholder dashes toward the player and respawns the player on contact.
- Door triggers swap scenes.
- Debug HUD shows scene name, velocity, grounded state.

## How To Run
1. Open the project in Godot 4.x.
2. Run the main scene: `res://scenes/Main.tscn` (already set in `project.godot`).

## Controls
Gamepad-first mapping:
- Move: left stick X
- Jump: Cross (A)
- Attack: Square (X)
- Interact/Confirm: Triangle (Y)

Keyboard mapping:
- Move: A / D or Left / Right
- Jump: Space
- Attack: J
- Interact: K
- Reset: R

Prompt text adapts to the last used input device for all actions:
- Uses tokens like `{INTERACT}`, `{JUMP}`, `{ATTACK}`, `{MOVE}`, `{RESET}`

## Folder Structure
- `scenes/`
  - `Main.tscn` (entry point)
  - `Hub.tscn`
  - `BossRoom.tscn`
  - `Player.tscn`
  - `Boss.tscn`
  - `ui/DebugHUD.tscn`
- `scripts/`
  - `scene_manager.gd`
  - `player.gd`
  - `boss.gd`
  - `door.gd`
  - `debug_hud.gd`

## Design Documents
- `docs/design.md`: full design text and technical spec (state machine, audio, dialogue, interaction).
- `docs/codex_prompt.md`: prompt to regenerate the project skeleton.
- `docs/audio_notes.md`: recording and mixing notes for the boss guitar theme.

## Next Steps (Planned)
- Dialogue UI with typewriter and non-blocking world time.
- Interaction system (NPC + doors + prompts) with a single input.
- Audio Director with layered music + bar-synced transitions.
- Combat hitboxes and revive loop for the boss.
