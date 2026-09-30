extends CanvasLayer
class_name ResultOverlay
## Stargazer - Encounter result overlay
## Shown when the player dies or wins. It pauses the fight, lists any rewards
## and offers exactly two exits, so a finished encounter can never be left
## running in the background.

signal retry_pressed()
signal leave_pressed()

var _victory: bool = false
var _heading: String = ""
var _lines: Array = []
var _accent: Color = Palette.GOLD

func _init(victory: bool = false, heading: String = "", lines: Array = [], accent: Color = Palette.GOLD) -> void:
	layer = 25
	_victory = victory
	_heading = heading
	_lines = lines
	_accent = accent

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var scrim := UIKit.scrim(0.78)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var panel := UIKit.panel(Vector2(480, 0))
	center.add_child(panel)
	var box := UIKit.vbox(10)
	panel.add_child(box)

	box.add_child(UIKit.title(_heading, 34, _accent if _victory else Palette.DANGER))
	box.add_child(UIKit.separator())
	for line in _lines:
		box.add_child(UIKit.title(String(line), 15, Palette.TEXT))

	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := UIKit.button("Fight again" if _victory else "Try again", _accent)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(retry)
	var leave := UIKit.button("Return to the clearing")
	leave.pressed.connect(func() -> void: leave_pressed.emit())
	row.add_child(leave)
	box.add_child(row)

	leave.grab_focus()
