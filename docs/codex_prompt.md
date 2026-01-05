You are Codex. Generate a runnable Godot 4.x (GDScript) project skeleton for a 2D platformer prototype (Hollow Knight-like feel but simplified). The project must be Gamepad-first and include: hub + dungeon/boss room, guardian NPC with Undertale-like typewriter dialogue, layered music controlled by distance, white-screen transitions synced to 4-second music bars, basic combat with hitbox + invulnerability frames, boss that "dies" and revives, and full world reset on player death.

HARD REQUIREMENTS
Godot: 4.x, 2D.
Use CharacterBody2D for Player and Boss.
No external assets required: use ColorRect / simple Sprite2D with solid colors.
All content must run as-is.

INPUT (Gamepad-first)
- Left stick X axis for movement.
- Cross (X) = jump
- Square = attack
- Triangle = interact/confirm (same button for starting dialogue and advancing dialogue)
Also bind keyboard equivalents (A/D, Space, J, E) optionally for debugging, but prioritize gamepad mapping.

Implement InputMap actions:
move_left, move_right, jump, attack, interact, reset

GAME STRUCTURE
res://
  scenes/
    Main.tscn
    Hub.tscn
    BossRoom.tscn
    Player.tscn
    Boss.tscn
    Guardian.tscn
    ui/
      DialogueUI.tscn
      PromptUI.tscn
      WhiteoutUI.tscn
  scripts/
    game_director.gd        # global state machine + transitions + reset
    scene_manager.gd        # loads/unloads scenes, spawn points
    player.gd               # movement + attack hitbox + i-frames
    boss.gd                 # hp, death->pause->revive loop
    guardian.gd             # dialogue progression, animation state, emits audio signals
    interactable.gd         # base interface for interactables
    interaction_resolver.gd # selects current interactable + prompt
    dialogue_ui.gd          # undertale-like typewriter
    audio_director.gd       # ambient + layered music, time_to_next_bar, fades
    whiteout_ui.gd          # fade to white & back
    prompt_ui.gd            # show "Triangle: Talk/Enter" near player

MAIN LOOP / STATES
Create a GameDirector singleton (autoload preferred) controlling states:
HUB_FREE, HUB_DIALOGUE, TRANSITION, BOSSROOM_FREE, BOSS_FIGHT, RESET
- Player death triggers RESET pipeline:
  whiteout -> wait time_to_next_bar -> load Hub -> start hub audio -> fade from white
- Door to boss room triggers TRANSITION pipeline similarly.

SCENES
Main.tscn:
- Instances HUD layers: DialogueUI, PromptUI, WhiteoutUI.
- Ensures GameDirector / AudioDirector available (autoload).
- Loads Hub on start and spawns Player at Marker2D "PlayerSpawn".

Hub.tscn:
- Floor/platforms (StaticBody2D colliders).
- Marker2D "PlayerSpawn".
- Guardian instance placed on the left.
- Door/Descent (Area2D interactable) on the right, initially LOCKED.
- A label "Hub" optional.

BossRoom.tscn:
- Arena floor and walls.
- Marker2D "PlayerSpawn"
- Marker2D "BossSpawn"
- Boss instance at BossSpawn.
- Exit/Return door interactable back to Hub (optional for MVP, but include if easy).
- Start boss music when player within a proximity radius to Boss.

PLAYER
Movement: left/right + jump only (no dash, no walljump).
Implement:
- acceleration/deceleration
- gravity
- coyote time
- jump buffer
- max fall speed clamp
Camera:
- Camera2D with a deadzone so player stays near center, but camera clamps to level bounds.

Attack:
- On attack press, spawn/enable a semi-circle hitbox in front of the player facing direction.
- Attack works in air and on ground.
- When hit connects, target flashes white and becomes invulnerable for a short duration (i-frames).
- Player also has i-frames when damaged.
Parameters (exported):
attack_cooldown, attack_radius, attack_offset, iframes_duration, damage_amount.

INTERACTION
Interaction is always explicit by pressing Triangle (interact).
Approach an interactable: show PromptUI text near player:
- "△ Talk" for Guardian
- "△ Enter" for Door
Use an InteractionResolver:
- tracks nearby interactables via Area2D enters/exits
- chooses nearest as current_interactable
- on interact pressed:
  - if Dialogue active: advance/confirm
  - else if current_interactable: call interact(player)

DIALOGUE (Undertale-like)
Dialogue does NOT pause time. It only blocks player movement while active.
Typewriter printing in real time.
The player cannot confirm until the current line finished printing.
After line fully printed, pressing Triangle advances to next line.
No choices.
Guardian dialogue progression:
- intro (once) -> on end: unlock descent door
- extra_lines[] (sequential each interaction)
- repeat_line (forever after extras consumed)

AUDIO
Ambient + Music simultaneously.
Music is layered (e.g., base + 2 layers).
In Hub:
- layers fade in/out based on distance to Guardian (radius-based). Closer = louder layers.
If Dialogue with Guardian is active:
- layers fade out to 0 and Guardian animation switches to "not playing".
Transitions:
- Whiteout transition waits until end of the current 4-second music bar.
- AudioDirector must provide:
  - get_time_to_next_bar() based on bar_length_sec=4.0 and a bar timer
  - fade_out_current_ambient(duration)
  - start_scene_audio(scene_name) (hub/bossroom)
During whiteout:
- fade ambient out, wait time_to_next_bar, then switch scene, then fade new ambient/music in.

BOSS
Boss has HP and can be damaged by player attack.
When HP reaches 0:
- play a clear death animation (scale down / flash / disappear)
- pause ~0.8s
- revive (reverse animation), reset HP
Boss music must NOT stop or change on death.
After the FIRST time the boss hits HP=0, display an on-screen dialogue-like overlay line:
"Советы по игре будут?"
This overlay should NOT pause time and should NOT block player controls (use a non-blocking message UI or a special DialogueUI mode).

DELIVERABLE
Provide full contents for all .tscn and .gd files.
Include step-by-step instructions:
- Set Main.tscn as main scene
- Setup autoloads (GameDirector, AudioDirector, InteractionResolver if needed)
- Setup InputMap with gamepad bindings (Cross/Square/Triangle, left stick)
- Run the project

CONSTRAINTS
Do NOT add inventory, quests, save system, complex UI.
Keep it clean, extendable, deterministic.
