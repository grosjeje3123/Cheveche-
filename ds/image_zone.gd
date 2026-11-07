class_name ImageZone
extends Control
## La zone centrale d'une carte : l'image (ou son gabarit provisoire) sous la couche à gratter.
## Le contenu est interchangeable ; la couche `cover` est celle de ScratchCover.

const PHOTO_SHADER := preload("rounded_photo.gdshader")

var cover: ScratchCover
var _holder: Control


func _init(interactive := true) -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	cover = ScratchCover.new()
	cover.interactive = interactive
	cover.crumbs_enabled = interactive
	cover.mask_size = Vector2i(256, 128)
	cover.brush_radius_ratio = 0.07
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)


func show_photo(tex: Texture2D) -> void:
	_clear()
	var photo := ColorRect.new()
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PHOTO_SHADER
	mat.set_shader_parameter("photo", tex)
	mat.set_shader_parameter("photo_size", Vector2(tex.get_size()))
	mat.set_shader_parameter("corner_radius", float(Ds.RADIUS))
	photo.material = mat
	photo.resized.connect(func() -> void: mat.set_shader_parameter("rect_size", photo.size))
	_holder.add_child(photo)


func show_placeholder(description: String) -> void:
	_clear()
	var art := PlaceholderArt.new(description)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(art)


## Vrai si une vraie photo est affichée (et non le gabarit provisoire).
func shows_photo() -> bool:
	return _holder.get_child_count() > 0 and _holder.get_child(0) is ColorRect


func _clear() -> void:
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
