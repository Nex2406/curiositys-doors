extends Node

## THE GAME IS READING YOU — ALL OF IT, FROM THE FIRST DOOR.
##
## Not one level (Advika, 2026-08-07): the read runs the whole game. It starts
## the moment a Curiosity exists in any scene and never stops, so by the time
## the mirror is standing in the drained forest it has watched the cave, the
## sky-fight and the forest — a description of how this person plays, not how
## they played for ten minutes.
##
## Nothing has to wire it up. It ATTACHES ITSELF to whatever is in the "player"
## group, in any scene, forever, so a realm nobody has touched since March is
## still being read. `begin()` stays for anything that wants to hand it a
## specific body, and `reset()` means "a new person is playing" — it belongs to
## starting a new game, NOT to entering a level.
##
## Everything the mirror boss becomes is measured here, while the player is
## busy playing and has no idea it is happening. It is a description
## of HOW SOMEONE PLAYS, in numbers: how often they leave the ground, how fast
## they swing, how close they stand when they do, which way they break when
## something comes at them, whether they back off after landing a hit, how hard
## they close.
##
## It is not a recording, and there is deliberately no tape. An earlier pass
## kept a ring buffer of movement snippets so the boss could replay a moment
## back at them; it was cut (Advika) — the boss is meant to ANALYSE them and
## fight on what it learns, not perform their greatest hits.
##
## Session-only, never written to disk: this is not a save, it is a read of
## who is holding the controller right now. Every fresh run builds a fresh
## boss, which is the whole point — no two players fight the same Curiosity.
##
## Nothing in here decides anything. It only measures. The boss asks.

## how near an enemy counts as "in combat"
const COMBAT_RANGE := 420.0

# ---- the live profile ----
var jumps: int = 0
var attacks: int = 0
var play_seconds: float = 0.0
## mean and spread of the gap between swings — the boss's own attack rhythm
var attack_cadence_mean: float = 0.0
var attack_cadence_var: float = 0.0
## how far from the enemy they were standing when they swung
var engage_distance: float = 0.0
## -1 fully left, +1 fully right: which way they habitually dodge
var dodge_bias: float = 0.0
## 0..1, how often they back away in the second after landing a hit
var retreat_tendency: float = 0.0
## average speed while closing on an enemy
var approach_speed: float = 0.0
## 0..1, how much of their time is spent off the ground. Jumps-per-minute says
## how often they leave it; this says whether they LIVE up there.
var air_fraction: float = 0.0

var _player: CharacterBody2D = null
var _was_floor := true
var _last_attack_t := -1.0
var _gaps: Array[float] = []
var _engage: Array[float] = []
var _approach: Array[float] = []
var _dodges: Array[float] = []
var _retreats: Array[float] = []
var _post_hit := 0.0
var _post_hit_x := 0.0
var _air_seconds := 0.0


## the level hands us the player once control unlocks — before that, nothing
## the player does is really them playing
func begin(player: CharacterBody2D) -> void:
	_player = player
	_was_floor = true


func stop() -> void:
	_player = null


func reset() -> void:
	jumps = 0
	attacks = 0
	play_seconds = 0.0
	attack_cadence_mean = 0.0
	attack_cadence_var = 0.0
	engage_distance = 0.0
	dodge_bias = 0.0
	retreat_tendency = 0.0
	approach_speed = 0.0
	air_fraction = 0.0
	_air_seconds = 0.0
	_gaps.clear()
	_engage.clear()
	_approach.clear()
	_dodges.clear()
	_retreats.clear()
	_last_attack_t = -1.0


## jumps per minute — the single most legible number about how someone moves
func jumps_per_minute() -> float:
	if play_seconds < 1.0:
		return 0.0
	return float(jumps) / (play_seconds / 60.0)


## swings per minute — how hard they lean on the blade
func attacks_per_minute() -> float:
	if play_seconds < 1.0:
		return 0.0
	return float(attacks) / (play_seconds / 60.0)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		# it finds her itself. A scene change frees the old body, and the next
		# frame it picks up the new one — no realm has to know this exists.
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player == null:
			return
		_was_floor = true
	play_seconds += delta

	# --- jumps: a floor->air transition with upward velocity, which is a
	# jump; a floor->air transition with downward velocity is a fall ---
	var on_floor: bool = _player.is_on_floor()
	if _was_floor and not on_floor and _player.velocity.y < -30.0:
		jumps += 1
	_was_floor = on_floor
	# and how much of their life is spent up there, which is a different
	# question from how often they leave: one long float and twenty little
	# hops give the same jumps-per-minute and are not the same player
	if not on_floor:
		_air_seconds += delta
	air_fraction = _air_seconds / maxf(play_seconds, 0.01)

	var near: Node2D = _nearest_enemy()
	var gap: float = INF
	if near != null:
		gap = _player.global_position.distance_to(near.global_position)

	# --- attacks: cadence, and how close they stand to throw one ---
	if _attack_pressed():
		attacks += 1
		if _last_attack_t >= 0.0:
			_gaps.append(play_seconds - _last_attack_t)
			_recompute_cadence()
		_last_attack_t = play_seconds
		if near != null and gap < COMBAT_RANGE:
			_engage.append(gap)
			engage_distance = _mean(_engage)
			# arm the retreat test: did they back off after this swing?
			_post_hit = 1.0
			_post_hit_x = _player.global_position.x

	# --- retreat: one second after a swing, are they further away? ---
	if _post_hit > 0.0:
		_post_hit -= delta
		if _post_hit <= 0.0 and near != null:
			var moved_away: bool = absf(near.global_position.x
					- _player.global_position.x) > absf(near.global_position.x
					- _post_hit_x)
			_retreats.append(1.0 if moved_away else 0.0)
			retreat_tendency = _mean(_retreats)

	# --- dodge bias + approach speed, only while something is threatening ---
	if near != null and gap < COMBAT_RANGE:
		if absf(_player.velocity.x) > 40.0:
			var toward: float = signf(near.global_position.x
					- _player.global_position.x)
			var moving: float = signf(_player.velocity.x)
			if moving != toward:
				# moving AWAY from the threat: that is the dodge, and this is
				# the direction they instinctively pick
				_dodges.append(moving)
				dodge_bias = _mean(_dodges)
			else:
				_approach.append(absf(_player.velocity.x))
				approach_speed = _mean(_approach)


func _recompute_cadence() -> void:
	attack_cadence_mean = _mean(_gaps)
	var v := 0.0
	for g in _gaps:
		v += pow(g - attack_cadence_mean, 2.0)
	attack_cadence_var = v / maxf(float(_gaps.size()), 1.0)


# ---------- helpers ----------

func _attack_pressed() -> bool:
	for a in ["attack", "attack1", "strike"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	# the realms advertise J / Z as the swing
	return Input.is_key_pressed(KEY_J) and not _j_held \
			or Input.is_key_pressed(KEY_Z) and not _z_held


var _j_held := false
var _z_held := false


func _physics_process(_d: float) -> void:
	_j_held = Input.is_key_pressed(KEY_J)
	_z_held = Input.is_key_pressed(KEY_Z)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or _player == null:
			continue
		var d: float = _player.global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v in a:
		t += float(v)
	return t / float(a.size())


## FAKE SOMEBODY, so the boss can be judged without playing three different
## ways for ten minutes each. Three archetypes, taken from how people actually
## hold this game: a rusher who lives in the enemy's face, a camper who pokes
## from as far as the blade reaches, and a spammer who never stops swinging.
## Test-only — nothing in the level ever calls this.
##   0 rusher   1 camper   2 spammer
func seed_fake(kind: int) -> void:
	reset()
	play_seconds = 240.0
	match kind:
		0:
			jumps = 120; attacks = 60; air_fraction = 0.34
			attack_cadence_mean = 0.9; engage_distance = 70.0
			dodge_bias = 0.6; retreat_tendency = 0.1; approach_speed = 205.0
		1:
			jumps = 12; attacks = 30; air_fraction = 0.05
			attack_cadence_mean = 2.1; engage_distance = 190.0
			dodge_bias = -0.75; retreat_tendency = 0.85; approach_speed = 90.0
		_:
			jumps = 40; attacks = 200; air_fraction = 0.14
			attack_cadence_mean = 0.42; engage_distance = 105.0
			dodge_bias = 0.05; retreat_tendency = 0.3; approach_speed = 160.0


## one block of text for the debug overlay — the profile, as the boss sees it
func summary() -> String:
	return "READING YOU\n" \
		+ "played      %.1fs\n" % play_seconds \
		+ "jumps       %d  (%.1f/min)\n" % [jumps, jumps_per_minute()] \
		+ "attacks     %d\n" % attacks \
		+ "cadence     %.2fs  (var %.3f)\n" % [attack_cadence_mean, attack_cadence_var] \
		+ "engage dist %.0fpx\n" % engage_distance \
		+ "dodge bias  %+.2f  (%s)\n" % [dodge_bias,
			"left" if dodge_bias < -0.15 else ("right" if dodge_bias > 0.15 else "even")] \
		+ "retreat     %.0f%%\n" % (retreat_tendency * 100.0) \
		+ "approach    %.0fpx/s\n" % approach_speed \
		+ "in the air  %.0f%%  (%.1f swings/min)" \
			% [air_fraction * 100.0, attacks_per_minute()]
