extends Control
## ニコニコ動画風にコメントが流れる表示層
## - 横断時間は文字数によらず一定。長いコメントほど速い。
## - 画面をレーンに分割し、同一レーン内で重ならない場合のみ配置する。
##   空きレーンが無ければ待機列に積み、空き次第流す。

signal comment_spawned(comment: FlowingComment)
signal comment_exited(comment: FlowingComment)
## プレイヤーがコメントをクリックして消した時に発火。ジャンル判定・スコア加算はここに繋ぐ。
signal comment_clicked(comment: FlowingComment)

const TYPE_COLORS := {
	&"neutral": Color(1.0, 1.0, 1.0),
	&"fan": Color(0.65, 1.0, 0.75),
	&"tease": Color(1.0, 0.95, 0.55),
	&"anti": Color(1.0, 0.55, 0.55),
}
## 待機列の上限
const PENDING_LIMIT := 12

@export_file("*.json") var comment_data_path: String = "res://data/comments.json"
## 画面を横断しきるまでの秒数。小さいほど速い。
@export_range(1.0, 12.0, 0.1) var travel_seconds: float = 4.0
## コメント1件あたりの生成間隔(秒)。
@export_range(0.05, 3.0, 0.05) var spawn_interval: float = 0.55
@export_range(12, 96, 1) var font_size: int = 34
## 上端の除外高さ(px)。UIバーなどコメントを重ねたくない領域の分だけ確保する。
@export_range(0, 200, 1) var top_margin: int = 0
## 下端の除外高さ(px)。
@export_range(0, 200, 1) var bottom_margin: int = 0
## 種別ごとに色を変える(開発時の確認用)。本番は本家同様すべて白。
@export var colorize_by_type: bool = false
## false にすると生成が止まる(流れているコメントはそのまま流れ切る)。
@export var running: bool = true

var _font: Font
var _pool: Array[Dictionary] = []
var _bag: Array[int] = []
var _lanes: Array[FlowingComment] = []
var _lane_height: float = 1.0
var _spawn_accum: float = 0.0
var _pending: Array[Dictionary] = []
var _label_settings_cache: Dictionary = {}


func _ready() -> void:
	_font = _create_font()
	_pool = _load_comments(comment_data_path)
	resized.connect(_rebuild_lanes)
	_rebuild_lanes()


func _process(delta: float) -> void:
	if running:
		_spawn_accum += delta
		while _spawn_accum >= spawn_interval:
			_spawn_accum -= spawn_interval
			_enqueue_random()
	_flush_pending()


## 任意のコメントを外部から流す
func push_comment(text: String, type: StringName = &"neutral") -> void:
	_push_pending({ "text": text, "type": String(type) })


func _rebuild_lanes() -> void:
	_lane_height = maxf(1.0, font_size * 1.35)
	var usable_height := maxf(0.0, size.y - top_margin - bottom_margin)
	_lanes.resize(maxi(1, int(usable_height / _lane_height)))


func _enqueue_random() -> void:
	if _pool.is_empty():
		return
	if _bag.is_empty():
		_bag.assign(range(_pool.size()))
		_bag.shuffle()
	_push_pending(_pool[_bag.pop_back()])


func _push_pending(data: Dictionary) -> void:
	_pending.append(data)
	while _pending.size() > PENDING_LIMIT:
		_pending.pop_front()


func _flush_pending() -> void:
	while not _pending.is_empty() and _try_spawn(_pending[0]):
		_pending.pop_front()


func _try_spawn(data: Dictionary) -> bool:
	var text := String(data.get("text", ""))
	if text.is_empty():
		return true
	var type := StringName(data.get("type", "neutral"))
	var settings := _get_label_settings(type)
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var width: float = text_size.x + settings.outline_size * 2.0

	var speed := (size.x + width) / travel_seconds
	var lane := _pick_free_lane(width, speed)
	if lane < 0:
		return false

	var comment := FlowingComment.new()
	comment.text = text
	comment.comment_type = type
	comment.label_settings = settings
	comment.speed = speed
	comment.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	comment.size = Vector2(width, _lane_height)
	comment.position = Vector2(size.x, top_margin + lane * _lane_height)
	comment.exited.connect(_on_comment_exited)
	comment.clicked.connect(_on_comment_clicked)
	add_child(comment)

	_lanes[lane] = comment
	comment_spawned.emit(comment)
	return true


## 幅 width・速度 speed のコメントを重ならず置けるレーン番号。無ければ -1。
func _pick_free_lane(width: float, speed: float) -> int:
	var free_lanes: Array[int] = []
	for i in _lanes.size():
		var last: FlowingComment = _lanes[i]
		if not is_instance_valid(last):
			free_lanes.append(i)
			continue
		var last_right := last.position.x + last.size.x
		# 1) 直前のコメントが画面内に入りきっていること(右端で頭が重ならない)
		if last_right > size.x:
			continue
		# 2) 直前のコメントが左端を抜け切るまでに、追いついて追い越さないこと
		var time_to_exit := last_right / maxf(last.speed, 0.001)
		if size.x - speed * time_to_exit < 0.0:
			continue
		free_lanes.append(i)
	if free_lanes.is_empty():
		return -1
	return free_lanes[randi() % free_lanes.size()]


func _on_comment_exited(comment: FlowingComment) -> void:
	comment_exited.emit(comment)


func _on_comment_clicked(comment: FlowingComment) -> void:
	comment_clicked.emit(comment)


func _get_label_settings(type: StringName) -> LabelSettings:
	var key: StringName = type if colorize_by_type else &"neutral"
	if _label_settings_cache.has(key):
		return _label_settings_cache[key]
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = font_size
	settings.font_color = TYPE_COLORS.get(key, Color(1.0, 1.0, 1.0))
	settings.outline_size = maxi(2, font_size / 8)
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	_label_settings_cache[key] = settings
	return settings


## 既定フォントは日本語グリフを持たないため、OSのフォントを使う。
func _create_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Yu Gothic UI", "Meiryo", "MS Gothic",
		"Noto Sans CJK JP", "Hiragino Sans", "sans-serif",
	])
	font.font_weight = 700
	return font


func _load_comments(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("コメントデータが見つかりません: %s" % path)
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("comments"):
		push_error("コメントデータの形式が不正です(comments配列が必要): %s" % path)
		return result
	for item: Variant in (parsed as Dictionary)["comments"]:
		if typeof(item) == TYPE_DICTIONARY and (item as Dictionary).has("text"):
			result.append(item)
	if result.is_empty():
		push_error("コメントが1件も読み込めませんでした: %s" % path)
	return result
