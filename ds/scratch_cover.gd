class_name ScratchCover
extends ColorRect
## Couche à gratter, mate. À placer par-dessus le contenu à cacher.
##
## - La matière s'amincit au frottement (plusieurs passages pour l'ôter complètement).
## - Le pourcentage gratté est compté au fil des coups de pinceau, sans relire les pixels.
## - La zone peut être découpée en bandes horizontales (`band_count`) : chacune a son propre
##   pourcentage, ce qui permet de savoir quel indice a été découvert.
## - À la réponse, `reveal_all()` fait s'effriter ce qui reste.

signal scratch_started
## Le doigt (ou la souris) se lève après avoir gratté.
signal scratch_ended
signal progress_changed(fraction: float)
signal revealed

const SHADER := preload("scratch_cover.gdshader")
## Un pixel du masque compte comme gratté au-delà de cette valeur (0-255).
const SCRATCHED_THRESHOLD := 150

## Résolution du masque. Choisir un ratio proche de celui du contrôle.
@export var mask_size := Vector2i(256, 208)
## Rayon du pinceau, en proportion de la largeur du contrôle.
@export_range(0.01, 0.2) var brush_radius_ratio := 0.06
## Part du rayon occupée par le bord adouci du pinceau.
@export_range(0.05, 1.0) var brush_softness := 0.55
## Quantité de matière retirée à chaque tampon (plus bas = plus de passages nécessaires).
@export_range(0.05, 1.0) var brush_pressure := 0.30
## Nombre de bandes horizontales suivies séparément (0 = aucune).
@export var band_count := 0
## Si faux, la couche ignore les gestes (aperçu décoratif).
@export var interactive := true
@export var corner_radius := Ds.RADIUS
@export var crumbs_enabled := true

## Part de la surface déjà grattée, entre 0.0 et 1.0.
var scratch_fraction: float:
	get:
		return _fraction

var _mask_image: Image
var _mask_texture: ImageTexture
var _values := PackedByteArray()
var _scratched_count := 0
var _fraction := 0.0
var _row_band := PackedInt32Array()
var _band_counts := PackedInt32Array()
var _band_totals := PackedInt32Array()
var _dirty := false
var _drawing := false
var _started := false
var _revealed := false
var _last_pos := Vector2.ZERO
var _tween: Tween
var _mat: ShaderMaterial
var _crumbs: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_build_mask()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("mask_tex", _mask_texture)
	_mat.set_shader_parameter("slate", Ds.SLATE)
	material = _mat
	resized.connect(_update_rect_uniforms)
	_update_rect_uniforms()
	_make_crumbs()


func is_revealed() -> bool:
	return _revealed


## Part grattée de la bande `i` (0 à 1).
func band_fraction(i: int) -> float:
	if i < 0 or i >= _band_totals.size() or _band_totals[i] == 0:
		return 0.0
	return float(_band_counts[i]) / float(_band_totals[i])


## Remet une couche neuve (nouvelle question).
func reset() -> void:
	if _tween:
		_tween.kill()
	_mask_image.fill(Color.BLACK)
	_mask_texture.update(_mask_image)
	_values.fill(0)
	_band_counts.fill(0)
	_scratched_count = 0
	_fraction = 0.0
	_dirty = false
	_drawing = false
	_started = false
	_revealed = false
	_set_crumbs(false)
	_mat.set_shader_parameter("dissolve", 0.0)
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	progress_changed.emit(0.0)


## Fait s'effriter ce qui reste de la couche. Le pourcentage gratté reste lisible.
func reveal_all(animated := true) -> void:
	if _revealed:
		return
	_revealed = true
	_drawing = false
	_set_crumbs(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	if animated:
		_tween = create_tween()
		_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("dissolve", v),
				0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_mat.set_shader_parameter("dissolve", 1.0)
	revealed.emit()


## Trace un geste programmé (coordonnées normalisées 0-1) : sert aux aperçus décoratifs.
func scratch_path(points: Array, passes := 1) -> void:
	for p in passes:
		for i in points.size():
			var pos: Vector2 = points[i] * size
			if i == 0:
				_last_pos = pos
			_stroke_to(pos)
	_process(0.0)


func _update_rect_uniforms() -> void:
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("corner_radius", float(corner_radius))


func _build_mask() -> void:
	_mask_image = Image.create(mask_size.x, mask_size.y, false, Image.FORMAT_R8)
	_mask_image.fill(Color.BLACK)
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_values.resize(mask_size.x * mask_size.y)
	_values.fill(0)
	_row_band.resize(mask_size.y)
	var bands := maxi(band_count, 1)
	_band_counts.resize(bands)
	_band_counts.fill(0)
	_band_totals.resize(bands)
	_band_totals.fill(0)
	for y in mask_size.y:
		var b := mini(int(y * bands / mask_size.y), bands - 1)
		_row_band[y] = b
		_band_totals[b] += mask_size.x


func _make_crumbs() -> void:
	# Quelques miettes de matière, très discrètes.
	_crumbs = CPUParticles2D.new()
	_crumbs.emitting = false
	_crumbs.amount = 14
	_crumbs.lifetime = 0.5
	_crumbs.local_coords = false
	_crumbs.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_crumbs.emission_sphere_radius = 12.0
	_crumbs.direction = Vector2(0, 1)
	_crumbs.spread = 80.0
	_crumbs.gravity = Vector2(0, 700)
	_crumbs.initial_velocity_min = 30.0
	_crumbs.initial_velocity_max = 110.0
	_crumbs.scale_amount_min = 2.0
	_crumbs.scale_amount_max = 3.5
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0.0, 1.0])
	tint.colors = PackedColorArray([Ds.SLATE.lightened(0.12), Color(Ds.SLATE, 0.0)])
	_crumbs.color_ramp = tint
	add_child(_crumbs)


func _set_crumbs(active: bool, pos := Vector2.ZERO) -> void:
	if _crumbs == null:
		return
	if active:
		_crumbs.position = pos
	_crumbs.emitting = active and crumbs_enabled


func _gui_input(event: InputEvent) -> void:
	if _revealed or not interactive:
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		var was_drawing := _drawing
		_drawing = button.pressed
		if was_drawing and not button.pressed:
			scratch_ended.emit()
		if button.pressed:
			_last_pos = button.position
			if not _started:
				_started = true
				scratch_started.emit()
			_stamp(button.position)
			_set_crumbs(true, button.position)
		else:
			_set_crumbs(false)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion and _drawing:
		_stroke_to(motion.position)
		_set_crumbs(true, motion.position)
		accept_event()


# Relie le dernier point au nouveau par des tampons rapprochés (pas de trous à vitesse élevée).
func _stroke_to(pos: Vector2) -> void:
	var step := maxf(size.x * brush_radius_ratio * 0.5, 1.0)
	var count := maxi(int(ceil(_last_pos.distance_to(pos) / step)), 1)
	for i in range(1, count + 1):
		_stamp(_last_pos.lerp(pos, float(i) / count))
	_last_pos = pos


# Retire de la matière dans une ellipse adoucie autour de `center` (coordonnées locales).
# L'ellipse compense un ratio masque/contrôle différent : le pinceau reste rond à l'écran.
func _stamp(center: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var w := mask_size.x
	var h := mask_size.y
	var radius_px := size.x * brush_radius_ratio
	var rx := maxf(radius_px / size.x * w, 1.0)
	var ry := maxf(radius_px / size.y * h, 1.0)
	var cx := center.x / size.x * w
	var cy := center.y / size.y * h
	var x0 := maxi(int(floor(cx - rx)), 0)
	var x1 := mini(int(ceil(cx + rx)), w - 1)
	var y0 := maxi(int(floor(cy - ry)), 0)
	var y1 := mini(int(ceil(cy + ry)), h - 1)
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5 - cy) / ry
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5 - cx) / rx
			var d2 := dx * dx + dy * dy
			if d2 >= 1.0:
				continue
			var falloff := clampf((1.0 - sqrt(d2)) / brush_softness, 0.0, 1.0)
			var add := int(falloff * brush_pressure * 255.0)
			if add <= 0:
				continue
			var idx := y * w + x
			var old := _values[idx]
			if old >= 255:
				continue
			var now := mini(old + add, 255)
			_values[idx] = now
			if old < SCRATCHED_THRESHOLD and now >= SCRATCHED_THRESHOLD:
				_scratched_count += 1
				_band_counts[_row_band[y]] += 1
			_mask_image.set_pixel(x, y, Color(now / 255.0, 0.0, 0.0))
			_dirty = true


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	_mask_texture.update(_mask_image)
	var f := float(_scratched_count) / float(_values.size())
	if not is_equal_approx(f, _fraction):
		_fraction = f
		progress_changed.emit(_fraction)
