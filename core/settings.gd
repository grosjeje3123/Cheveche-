class_name Settings
extends RefCounted
## Réglages du joueur (son, vibrations, page « Comment jouer » déjà vue), gardés à part de la progression (user://settings.json) :
## remettre la progression à zéro ne touche pas aux réglages.

const DEFAULT_PATH := "user://settings.json"

var path: String
var sound := true
var vibration := true
## La page « Comment jouer » a été vue avant la première série : elle ne s'ouvre plus d'elle-même.
var rules_seen := false


func _init(settings_path := DEFAULT_PATH) -> void:
	path = settings_path
	load_from_disk()


func load_from_disk() -> void:
	sound = true
	vibration = true
	rules_seen = false
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
		rules_seen = bool(data.get("rules_seen", false))


func save() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Réglages non enregistrés : %s" % path)
		return false
	file.store_string(JSON.stringify({"sound": sound, "vibration": vibration, "rules_seen": rules_seen}, "\t"))
	file.close()
	return true


func set_sound(on: bool) -> void:
	sound = on
	save()


func set_vibration(on: bool) -> void:
	vibration = on
	save()


func set_rules_seen(seen: bool) -> void:
	rules_seen = seen
	save()
