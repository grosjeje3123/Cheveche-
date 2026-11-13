class_name PaperConfetti
extends Control
## Une courte pluie de papier découpé, pour fêter la fin d'une série : des petits rectangles et triangles aux
## couleurs du carnet (ocre, sauge, terre cuite, ardoise), qui tombent en tournoyant et s'effacent en deux
## secondes et demie. Pas de paillettes ni de couleurs vives : du papier. Posé par-dessus la page, sans bloquer
## le doigt. `burst()` lance la pluie ; elle s'arrête d'elle-même.

const COLORS := [Ds.OCHRE, Ds.SAGE, Ds.TERRACOTTA, Color("34423A"), Color("D9C9A3")]
const DURATION := 2.6
const COUNT := 70

var _bits: Array = []
var _time := 0.0
var _running := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Lance la pluie depuis le haut de la page (`origin_y` : hauteur de départ, en part de la hauteur).
func burst(origin_y := 0.18) -> void:
	_rng.randomize()
	_bits.clear()
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	for i in COUNT:
		_bits.append({
			"pos": Vector2(_rng.randf_range(0.05, 0.95) * w, origin_y * h + _rng.randf_range(-0.12, 0.04) * h),
			"vel": Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-260.0, -60.0)),
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-5.0, 5.0),
			"size": Vector2(_rng.randf_range(10.0, 18.0), _rng.randf_range(6.0, 11.0)),
			"tri": _rng.randf() < 0.3,
			"color": COLORS[_rng.randi() % COLORS.size()],
			"sway": _rng.randf_range(0.0, TAU),
			"delay": _rng.randf_range(0.0, 0.35),
		})
	_time = 0.0
	_running = true
	set_process(true)


func is_running() -> bool:
	return _running


func _process(delta: float) -> void:
	_time += delta
	for b in _bits:
		if _time < float(b["delay"]):
			continue
		var v: Vector2 = b["vel"]
		v.y = minf(v.y + 520.0 * delta, 210.0)  # la gravité, freinée par l'air : le papier plane
		v.x *= 0.985
		b["vel"] = v
		b["sway"] = float(b["sway"]) + delta * 3.2
		b["pos"] = (b["pos"] as Vector2) + Vector2(v.x + sin(float(b["sway"])) * 40.0, v.y) * delta
		b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
	if _time >= DURATION:
		_running = false
		_bits.clear()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _running:
		return
	var fade := clampf((DURATION - _time) / 0.7, 0.0, 1.0)  # s'efface sur la fin
	for b in _bits:
		if _time < float(b["delay"]):
			continue
		var s: Vector2 = b["size"]
		# Le papier tourne sur lui-même : sa largeur apparente bat comme une feuille qui retombe.
		var flip := absf(cos(float(b["rot"]) * 1.7)) * 0.75 + 0.25
		var c: Color = b["color"]
		c.a = fade
		draw_set_transform(b["pos"], float(b["rot"]), Vector2(flip, 1.0))
		if b["tri"]:
			draw_colored_polygon(PackedVector2Array([Vector2(-s.x / 2, s.y / 2), Vector2(s.x / 2, s.y / 2), Vector2(0, -s.y / 2)]), c)
		else:
			draw_rect(Rect2(-s / 2.0, s), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
