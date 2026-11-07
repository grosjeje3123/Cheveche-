class_name ClueList
extends VBoxContainer
## Les indices d'un dossier (deux), numérotés I, II.
## Le texte est toujours mis en page (la carte ne bouge jamais) mais reste invisible tant que
## l'indice n'est pas débloqué ; un filet discret tient sa place.

const NUMERALS := ["I", "II", "III"]

var _rows: Array = []
var _unlocked := 0


func _init() -> void:
	add_theme_constant_override("separation", Ds.S2)


func set_clues(clues: Array) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	_unlocked = 0
	for i in clues.size():
		if i > 0:
			add_child(Ds.rule())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Ds.S3)
		add_child(row)

		var numeral := Ds.label(NUMERALS[i], Ds.Role.NUMERAL, Ds.INK_FAINT)
		numeral.custom_minimum_size = Vector2(44, 0)
		numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(numeral)

		var holder := MarginContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(holder)
		var text := Ds.label(str(clues[i]), Ds.Role.CLUE, Ds.INK, true)
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.modulate.a = 0.0
		holder.add_child(text)

		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(overlay)
		var line := ColorRect.new()
		line.color = Color(Ds.INK, 0.16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = 0.5
		line.anchor_bottom = 0.5
		line.offset_right = -48
		line.offset_top = -1
		line.offset_bottom = 1
		overlay.add_child(line)
		_rows.append({"numeral": numeral, "text": text, "line": line})


func unlocked_count() -> int:
	return _unlocked


## Débloque les `count` premiers indices (sans effet sur ceux qui le sont déjà).
func unlock(count: int, animated := true) -> void:
	count = mini(count, _rows.size())
	for i in range(_unlocked, count):
		var r: Dictionary = _rows[i]
		(r["numeral"] as Label).add_theme_color_override("font_color", Ds.TERRACOTTA)
		if animated:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(r["text"], "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
			tw.tween_property(r["line"], "modulate:a", 0.0, 0.25)
		else:
			(r["text"] as Label).modulate.a = 1.0
			(r["line"] as ColorRect).modulate.a = 0.0
	_unlocked = maxi(_unlocked, count)
