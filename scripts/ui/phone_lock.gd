extends Control
## Pantalla de bloqueo del móvil del presidente (encima de la mesa): la hora y los avisos pendientes.

const Redes := preload("res://scripts/systems/redes.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var unread := Redes.unread()
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1220") if unread == 0 else Color("10213a"))
	for i in 8:
		var t := float(i) / 8.0
		draw_rect(Rect2(0, h * t, w, h / 8.0 + 1.0), Color(0.11, 0.3, 0.6, 0.05 + t * 0.06))
	var mins := int(GS.day_progress() * 600.0) + 8 * 60
	var fs := int(h * 0.13)
	draw_string(UI.f_sans_b, Vector2(0, h * 0.22), "%02d:%02d" % [int(mins / 60) % 24, mins % 60], HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(1, 1, 1, 0.92))
	draw_string(UI.f_sans, Vector2(0, h * 0.29), UI.date_mid(GS.day), HORIZONTAL_ALIGNMENT_CENTER, w, int(h * 0.045), Color(1, 1, 1, 0.6))
	if unread == 0:
		draw_string(UI.f_serif_b, Vector2(0, h * 0.62), "pío", HORIZONTAL_ALIGNMENT_CENTER, w, int(h * 0.09), Color(0.11, 0.6, 0.94, 0.35))
		return
	var y := h * 0.38
	var n := 0
	for c in GS.social.get("chats", []):
		if c["state"] != "nuevo":
			continue
		var r := Rect2(w * 0.07, y, w * 0.86, h * 0.14)
		draw_rect(r, Color(1, 1, 1, 0.14))
		draw_string(UI.f_sans_b, Vector2(r.position.x + w * 0.05, y + h * 0.055), str(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - w * 0.08, int(h * 0.042), Color.WHITE)
		var last: String = str((c["msgs"] as Array).back()["t"])
		draw_string(UI.f_sans, Vector2(r.position.x + w * 0.05, y + h * 0.105), last.left(26) + "…", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - w * 0.08, int(h * 0.036), Color(1, 1, 1, 0.75))
		y += h * 0.16
		n += 1
		if n >= 3:
			break
