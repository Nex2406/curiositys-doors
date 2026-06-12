extends RealmBase

# Throwaway proving ground for the RealmBase foundation — NOT a shipped realm.
# Demonstrates the full M1 loop in one screen: enter via RealmBase (ambient +
# visited flag + state restore), change state ([Y] collects a token), persist
# it, and exit home ([S]/down) via RealmBase. Relaunching shows the collected
# count restored — the in-realm proof that SaveManager survives a restart.

const TOKEN_COUNT: int = 3

var _collected: int = 0

@onready var _label: Label = $UI/Label
@onready var _tokens: HBoxContainer = $UI/Tokens


func _on_realm_ready() -> void:
	_refresh()


func capture_state() -> Dictionary:
	return {"collected": _collected}


func apply_state(data: Dictionary) -> void:
	_collected = clampi(int(data.get("collected", 0)), 0, TOKEN_COUNT)


func _process(_delta: float) -> void:
	if _exiting:
		return
	if Input.is_action_just_pressed("interact") and _collected < TOKEN_COUNT:
		_collected += 1
		save_realm()
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		exit_to_hub()


func _refresh() -> void:
	var msg: String
	if _collected < TOKEN_COUNT:
		msg = "SAVE TEST\n\nPress  Y  to fill the dots  (%d / %d)" % [_collected, TOKEN_COUNT]
	else:
		msg = "SAVED.  Now REFRESH this page (F5).\n\nIf the dots are still gold, the save system works."
	_label.text = msg
	for i in _tokens.get_child_count():
		var dot: ColorRect = _tokens.get_child(i) as ColorRect
		if dot:
			dot.color = Color(0.92, 0.78, 0.46, 1.0) if i < _collected else Color(0.22, 0.2, 0.26, 1.0)
