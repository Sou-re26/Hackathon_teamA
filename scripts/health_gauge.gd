extends Control
## チャンネルの健全度ゲージ。数値は見せず、ゲージの量と色だけで示す(チラ見せ)。
## アンチコメントを消すと上がり、消し逃す(画面外まで流れる)と下がる。

@export_range(0.0, 100.0, 1.0) var initial_health: float = 100.0
@export_range(0.0, 50.0, 1.0) var anti_click_gain: float = 8.0
@export_range(0.0, 50.0, 1.0) var anti_miss_penalty: float = 15.0
@export_range(0.05, 1.0, 0.05) var fill_tween_duration: float = 0.35

const COLOR_LOW := Color(0.95, 0.3, 0.32, 1)
const COLOR_HIGH := Color(0.3, 0.85, 0.45, 1)
const FLASH_GAIN := Color(0.65, 1.0, 0.75, 0.85)
const FLASH_LOSS := Color(1.0, 0.35, 0.35, 0.85)

@onready var _track: Control = $Track
@onready var _fill: ColorRect = $Track/Fill
@onready var _flash: ColorRect = $Track/Flash

var health: float = 0.0
var _fill_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	health = initial_health
	_fill.anchor_top = 1.0 - health / 100.0
	_fill.color = _color_for(health)


func register_anti_clicked() -> void:
	_change_health(anti_click_gain, FLASH_GAIN, "+%d" % int(anti_click_gain))


func register_anti_missed() -> void:
	_change_health(-anti_miss_penalty, FLASH_LOSS, "-%d" % int(anti_miss_penalty))


func _change_health(delta: float, flash_color: Color, popup_text: String) -> void:
	health = clampf(health + delta, 0.0, 100.0)
	_animate_fill()
	_flash_pulse(flash_color)
	_spawn_popup(popup_text, flash_color)


func _animate_fill() -> void:
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween().set_parallel(true)
	_fill_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(_fill, "anchor_top", 1.0 - health / 100.0, fill_tween_duration)
	_fill_tween.tween_property(_fill, "color", _color_for(health), fill_tween_duration)


func _flash_pulse(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)


func _spawn_popup(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(_track.position.x - 6, _track.position.y - 8)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


func _color_for(h: float) -> Color:
	return COLOR_LOW.lerp(COLOR_HIGH, h / 100.0)
