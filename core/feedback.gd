class_name Feedback
extends Node
## Sons et vibrations du jeu, en un seul endroit, selon les réglages (Settings).
## Placé une fois dans la scène par main.gd ; les écrans l'appellent par les fonctions statiques
## (Feedback.say(...), Feedback.scratch_start()...). Sans Feedback dans la scène (tests), tout reste muet.
##
## Les sons sont dans assets/sounds (fabriqués par tools/make_sounds.py ; on peut les remplacer par
## d'autres .wav de même nom). Les vibrations demandent l'autorisation VIBRATE dans l'export Android.

static var current: Feedback

## Effet -> [fichier, volume en dB, vibration en ms (0 = aucune)].
const EFFECTS := {
	"startup": ["startup.wav", -8.0, 0],
	"tap": ["tap.wav", -10.0, 0],
	"clue": ["clue.wav", -8.0, 15],
	"right": ["right.wav", -6.0, 35],
	"wrong": ["wrong.wav", -8.0, 70],
	# Fin de série (écran de résultat), selon la part des points obtenue : voir Scoring.finish_effect().
	"series_great": ["series_great.wav", -5.0, 40],
	"series_good": ["series_good.wav", -6.0, 0],
	"series_low": ["series_low.wav", -7.0, 0],
	# Page « Fiche complète » : le tampon qui se pose (avec un petit choc dans la main), puis le jingle, sans vibrer deux fois.
	"stamp": ["stamp.wav", -3.0, 30],
	"complete": ["series_great.wav", -5.0, 0],
	# Carnet : une page qu'on tourne, la couverture qu'on ouvre.
	"page": ["page.wav", -14.0, 0],
}
const SOUNDS_DIR := "res://assets/sounds"

var settings: Settings
## Les derniers effets demandés (le plus récent à la fin) : sert aux tests.
var history: Array[String] = []

var _players := {}
var _scratch: AudioStreamPlayer
## Volume du frottement : le niveau suit en douceur une cible que chaque bout gratté relance.
const SCRATCH_DB := -13.0
const SCRATCH_RISE := 7.0    # montée (par seconde) : ~0,15 s pour atteindre le plein volume
const SCRATCH_FALL := 3.5    # descente du niveau vers la cible
const SCRATCH_DECAY := 2.5   # la cible retombe si l'on ne gratte plus rien de neuf
var _scratch_level := 0.0
var _scratch_target := 0.0
var _scratching := false


func _init(player_settings: Settings = null) -> void:
	settings = player_settings if player_settings != null else Settings.new("user://_feedback_defaults.json")


func _ready() -> void:
	current = self
	for name in EFFECTS:
		var p := AudioStreamPlayer.new()
		p.stream = load("%s/%s" % [SOUNDS_DIR, EFFECTS[name][0]])
		p.volume_db = EFFECTS[name][1]
		add_child(p)
		_players[name] = p
	_scratch = AudioStreamPlayer.new()
	var loop := load("%s/scratch.wav" % SOUNDS_DIR) as AudioStreamWAV
	if loop != null:
		loop = loop.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_scratch.stream = loop
	_scratch.volume_db = -80.0
	add_child(_scratch)


func _exit_tree() -> void:
	if current == self:
		current = null


## Un effet ponctuel : « tap », « clue » (indice débloqué), « right » ou « wrong ».
static func say(effect: String) -> void:
	if current != null:
		current._effect(effect)


## Le frottement : il commence quand le doigt se pose, monte en douceur à chaque bout gratté,
## et s'éteint en fondu quand le doigt s'arrête ou se lève.
static func scratch_start() -> void:
	if current != null:
		current._scratch_begin()


static func scratch_ping() -> void:
	if current != null and current._scratching:
		current._scratch_target = 1.0


static func scratch_stop() -> void:
	if current != null:
		current._scratch_end()


func _effect(effect: String) -> void:
	if not EFFECTS.has(effect):
		return
	history.append(effect)
	if history.size() > 20:
		history.pop_front()
	if settings.sound and _players.has(effect):
		(_players[effect] as AudioStreamPlayer).play()
	var ms: int = EFFECTS[effect][2]
	if settings.vibration and ms > 0:
		Input.vibrate_handheld(ms)


func _scratch_begin() -> void:
	_scratching = true
	_scratch_target = 0.0
	if settings.sound and _scratch.stream != null and not _scratch.playing:
		_scratch_level = 0.0
		_scratch.volume_db = -80.0
		_scratch.play()


## Le doigt se lève : pas de coupure sèche, le son s'éteint en fondu (voir _process).
func _scratch_end() -> void:
	_scratching = false
	_scratch_target = 0.0


func _process(delta: float) -> void:
	if not _scratch.playing:
		return
	if not settings.sound:
		_scratch_level = 0.0
		_scratch.stop()
		return
	_scratch_target = move_toward(_scratch_target, 0.0, delta * SCRATCH_DECAY)
	var rate := SCRATCH_RISE if _scratch_target > _scratch_level else SCRATCH_FALL
	_scratch_level = move_toward(_scratch_level, _scratch_target, delta * rate)
	if not _scratching and _scratch_level <= 0.0:
		_scratch.stop()
		return
	_scratch.volume_db = linear_to_db(maxf(_scratch_level, 0.0001)) + SCRATCH_DB
