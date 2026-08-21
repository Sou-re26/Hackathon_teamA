extends Control
## 動画エリアのシークバー・再生時間表示を、ゲームの制限時間に連動させる。

@export_range(10.0, 600.0, 1.0) var time_limit_seconds: float = 5.0

@onready var _seek_bg: Control = $PlayerFrame/BottomBar/SeekBarBG
@onready var _seek_fill: Control = $PlayerFrame/BottomBar/SeekBarFill
@onready var _time_label: Label = $PlayerFrame/BottomBar/HBox/TimeLabel
@onready var _result_overlay: Control = $ResultOverlay
@onready var _retry_button: Button = $ResultOverlay/ResultCenter/VBox/RetryButton
@onready var _title_button: Button = $ResultOverlay/ResultCenter/VBox/TitleButton
@onready var _comment_layer: Control = $PlayerFrame/CommentLayer
@onready var _health_gauge: Control = $Sidebar/HealthGauge

var _elapsed: float = 0.0
var _time_up: bool = false


func _ready() -> void:
	_update_seek_bar()
	_retry_button.pressed.connect(_on_retry_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	_comment_layer.comment_clicked.connect(_on_comment_clicked)
	_comment_layer.comment_exited.connect(_on_comment_exited)


func _on_comment_clicked(comment: FlowingComment) -> void:
	if comment.comment_type == &"anti":
		_health_gauge.register_anti_clicked()


func _on_comment_exited(comment: FlowingComment) -> void:
	if comment.comment_type == &"anti":
		_health_gauge.register_anti_missed()


func _process(delta: float) -> void:
	if _elapsed >= time_limit_seconds:
		return
	_elapsed = minf(_elapsed + delta, time_limit_seconds)
	_update_seek_bar()
	if _elapsed >= time_limit_seconds and not _time_up:
		_time_up = true
		_result_overlay.visible = true


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _update_seek_bar() -> void:
	var ratio := _elapsed / time_limit_seconds
	_seek_fill.position.x = _seek_bg.position.x
	_seek_fill.size.x = _seek_bg.size.x * ratio
	_time_label.text = "%s / %s" % [_format_time(_elapsed), _format_time(time_limit_seconds)]


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
