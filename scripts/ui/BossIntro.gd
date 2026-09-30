extends CanvasLayer
class_name BossIntro
## Stargazer - Boss introduction
## A short, dramatic title card. It always ends on its own after a few
## seconds and can be skipped instantly with Enter/Space or a click, so
## repeat attempts never feel padded.

signal finished()

const DURATION := 3.2

var _done: bool = false
var _definition: Dictionary = {}

func _init(definition: Dictionary = {}) -> void:
	layer = 20
	_definition = definition

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var accent: Color = _definition.get("accent", Palette.GOLD)

	var scrim := UIKit.scrim(0.82)
	add_child(scrim)

	var box := UIKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(box)

	var name_label := UIKit.title(String(_definition.get("name", "???")).to_upper(), 52, accent)
	box.add_child(name_label)
	box.add_child(UIKit.title(String(_definition.get("title", "")), 22, Palette.TEXT))
	var flavour := UIKit.title(String(_definition.get("intro", "")), 16, Palette.TEXT_DIM)
	flavour.custom_minimum_size = Vector2(0, 60)
	box.add_child(flavour)
	box.add_child(UIKit.title("Enter / Space to skip", 13, Palette.TEXT_DIM))

	name_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(name_label, "modulate:a", 1.0, 0.5)
	t.tween_interval(DURATION - 1.1)
	t.tween_property(scrim, "modulate:a", 0.0, 0.6)
	t.tween_callback(_finish)

func _unhandled_input(event: InputEvent) -> void:
	var skip := event.is_action_pressed("skip") or event.is_action_pressed("attack")
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
