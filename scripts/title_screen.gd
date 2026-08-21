extends Control

const RulesPopupScene := preload("res://scenes/rules_popup.tscn")

@onready var _start_button: Button = $CenterContainer/VBox/StartButton
@onready var _rules_button: Button = $CenterContainer/VBox/RulesButton

var _rules_popup: Control = null


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_rules_button.pressed.connect(_on_rules_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_rules_pressed() -> void:
	if is_instance_valid(_rules_popup):
		return
	_rules_popup = RulesPopupScene.instantiate()
	add_child(_rules_popup)
	_rules_popup.closed.connect(func() -> void: _rules_popup = null)
