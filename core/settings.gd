class_name Settings
extends RefCounted
## Réglages du joueur (son, vibrations), gardés à part de la progression (user://settings.json) :
## remettre la progression à zéro ne touche pas aux réglages.

const DEFAULT_PATH := "user://settings.json"

var path: String
var sound := true
var vibration := true


func _init(settings_path := DEFAULT_PATH) -> void:
	path = settings_path
	load_from_disk()


func load_from_disk() -> void:
	sound = true
	vibration = true
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		sound = bool(data.get("sound", true))
		vibration = bool(data.get("vibration", true))


func save() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Réglages non enregistrés : %s" % path)
		return false
	file.store_string(JSON.stringify({"sound": sound, "vibration": vibration}, "\t"))
	file.close()
	return true


func set_sound(on: bool) -> void:
	sound = on
	save()


func set_vibration(on: bool) -> void:
	vibration = on
	save()
