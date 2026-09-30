extends RefCounted
class_name SaveIO
## Stargazer - SaveIO
## Versioned JSON persistence in user://. Never destroys an existing save
## unless explicitly asked, and always degrades gracefully to defaults when a
## file is missing, unreadable or malformed.

const SAVE_PATH := "user://stargazer_save.json"
const BACKUP_PATH := "user://stargazer_save.bak.json"

static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

## Writes the state, keeping the previous file as a one-slot backup so a
## failed write can never silently destroy progress.
static func save_state(state: GameStateData, path: String = SAVE_PATH) -> bool:
	if state == null:
		return false
	var text := JSON.stringify(state.to_dict(), "\t")
	if FileAccess.file_exists(path):
		var previous := FileAccess.get_file_as_string(path)
		if previous != "":
			var backup := FileAccess.open(_backup_for(path), FileAccess.WRITE)
			if backup:
				backup.store_string(previous)
				backup.close()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Stargazer: could not write save to %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

## Loads into a fresh GameStateData. Corrupt or missing saves yield a valid
## default state; `ok` in the result reports whether real data was restored.
static func load_state(path: String = SAVE_PATH) -> Dictionary:
	var state := GameStateData.new()
	if not FileAccess.file_exists(path):
		return {"ok": false, "state": state, "reason": "missing"}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		# Try the backup before giving up.
		var backup_path := _backup_for(path)
		if FileAccess.file_exists(backup_path):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(backup_path))
		if parsed == null:
			return {"ok": false, "state": state, "reason": "corrupt"}
	if not state.from_dict(parsed):
		return {"ok": false, "state": state, "reason": "incompatible"}
	return {"ok": true, "state": state, "reason": "ok"}

static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _backup_for(path: String) -> String:
	return path.get_basename() + ".bak.json"
