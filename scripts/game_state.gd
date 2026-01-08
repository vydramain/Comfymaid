extends Resource
class_name GameState

enum Phase { HUB_FREE, HUB_DIALOGUE, TRANSITION, BOSSROOM_FREE, BOSS_FIGHT, RESET }

@export var mechanic_broken := false
@export var boss_defeated := false
@export var boss_revived_once := false
@export var guardian_intro_done := false
@export var guardian_post_dialogue_done := false
@export var guardian_death_hint_pending := false
@export var world_reset_count := 0
@export var phase: Phase = Phase.HUB_FREE
