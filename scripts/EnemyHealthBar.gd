extends Node2D
class_name EnemyHealthBar

# A sleek, thin health bar that floats just above an enemy so the player can read how
# much damage they've dealt. Deliberately unobtrusive (matches the near-zero-UI art
# direction): hidden at full health, it appears the moment the enemy is first hit and
# drains toward empty. It counter-scales against its parent so it stays a crisp, constant
# on-screen size no matter how small the enemy is drawn in the world.

@export var bar_width: float = 46.0     # on-screen px
@export var bar_height: float = 5.0     # on-screen px
@export var y_offset: float = -86.0     # on-screen px above the enemy's origin (its head)
@export var fill_color: Color = Color(0.95, 0.36, 0.26)  # warm ember, on-vibe accent

var _ratio: float = 1.0
var _shown: bool = false


func _ready() -> void:
	z_index = 50            # draw over the enemy sprite
	visible = false


# Feed this from the enemy's health_changed signal.
func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	_shown = _ratio < 1.0   # stay invisible until the first hit lands
	visible = _shown
	queue_redraw()


func _process(_delta: float) -> void:
	if not _shown:
		return
	# Undo the parent's scale so the bar renders at a fixed on-screen size.
	var ps := get_parent() as Node2D
	if ps != null and ps.global_scale.x != 0.0 and ps.global_scale.y != 0.0:
		scale = Vector2(1.0, 1.0) / ps.global_scale
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	var x := -bar_width * 0.5
	var y := y_offset
	# Soft dark backdrop / frame.
	draw_rect(Rect2(x - 1.5, y - 1.5, bar_width + 3.0, bar_height + 3.0), Color(0, 0, 0, 0.7), true)
	# Empty track.
	draw_rect(Rect2(x, y, bar_width, bar_height), Color(0.18, 0.05, 0.06, 0.95), true)
	# Remaining health.
	if _ratio > 0.0:
		draw_rect(Rect2(x, y, bar_width * _ratio, bar_height), fill_color, true)
