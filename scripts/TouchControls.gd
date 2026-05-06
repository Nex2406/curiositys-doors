extends CanvasLayer

const IDLE_ALPHA: float = 0.35
const PRESSED_ALPHA: float = 1.0
const FADE_TIME: float = 0.18
const BUTTON_RADIUS: float = 70.0
const EDGE_PADDING: float = 80.0
const BUTTON_GAP: float = 30.0

@onready var _left: TouchScreenButton = $LeftButton
@onready var _right: TouchScreenButton = $RightButton
@onready var _jump: TouchScreenButton = $JumpButton
@onready var _interact: TouchScreenButton = $InteractButton

var _tweens: Dictionary = {}


func _ready() -> void:
	visible = _should_show_touch_ui()
	if not visible:
		return
	_wire_button(_left)
	_wire_button(_right)
	_wire_button(_jump)
	_wire_button(_interact)
	get_viewport().size_changed.connect(_layout_buttons)
	_layout_buttons()


func _should_show_touch_ui() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _wire_button(btn: TouchScreenButton) -> void:
	btn.modulate.a = IDLE_ALPHA
	btn.pressed.connect(_on_pressed.bind(btn))
	btn.released.connect(_on_released.bind(btn))


func _on_pressed(btn: TouchScreenButton) -> void:
	_fade(btn, PRESSED_ALPHA)


func _on_released(btn: TouchScreenButton) -> void:
	_fade(btn, IDLE_ALPHA)


func _fade(btn: TouchScreenButton, target_alpha: float) -> void:
	var existing: Tween = _tweens.get(btn)
	if existing and existing.is_valid():
		existing.kill()
	var tween := create_tween()
	tween.tween_property(btn, "modulate:a", target_alpha, FADE_TIME)
	_tweens[btn] = tween


func _layout_buttons() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var button_size: float = BUTTON_RADIUS * 2.0
	var bottom_y: float = size.y - EDGE_PADDING - button_size
	var stacked_y: float = bottom_y - button_size - BUTTON_GAP
	_left.position = Vector2(EDGE_PADDING, bottom_y)
	_right.position = Vector2(EDGE_PADDING + button_size + BUTTON_GAP, bottom_y)
	# Right cluster: jump on top, interact directly below so a thumb at rest
	# sits on Enter and reaches up for jump.
	var right_x: float = size.x - EDGE_PADDING - button_size
	_jump.position = Vector2(right_x, stacked_y)
	_interact.position = Vector2(right_x, bottom_y)
