class_name OwlMark
extends TextureRect
## La chevêche, mascotte du jeu, en trois tailles optiques : plus elle est petite, moins elle a de détails.
## Les dessins sont générés par tools/make_owl.py (assets/brand/*.svg) ; ne pas les retoucher à la main.

const FULL := preload("res://assets/brand/owl_full.svg")  # à partir de ~80 px
const MARK := preload("res://assets/brand/owl_mark.svg")  # 44 à 80 px
const ICON := preload("res://assets/brand/owl_icon.svg")  # sous 44 px
const FULL_FROM := 80.0
const MARK_FROM := 44.0


func _init(px := 96) -> void:
	custom_minimum_size = Vector2(px, px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture = pick(float(px))
	resized.connect(func() -> void: texture = pick(minf(size.x, size.y)))


## La version du dessin adaptée à une taille d'affichage (en pixels).
static func pick(px: float) -> Texture2D:
	if px >= FULL_FROM:
		return FULL
	if px >= MARK_FROM:
		return MARK
	return ICON
