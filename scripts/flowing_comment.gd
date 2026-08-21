class_name FlowingComment
extends Label
## 画面を右から左へ流れる1件のコメント。
## 生成・レーン割り当ては CommentLayer が行う。

signal exited(comment: FlowingComment)
## プレイヤーがクリック(タップ)して消した時に発火。
signal clicked(comment: FlowingComment)

## 種別。"fan" / "tease" / "anti" / "neutral"。ゲーム側の判定に使う。
var comment_type: StringName = &"neutral"
## 秒あたりの移動px。長さによらず横断時間が一定になるよう CommentLayer が決める。
var speed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x + size.x < 0.0:
		exited.emit(self)
		queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		queue_free()
