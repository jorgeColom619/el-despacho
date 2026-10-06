extends Node
## Perfil persistente del jugador: monedas, colección, objetos equipados, logros y escaparate diario.

signal changed
signal earned(amount: int, reason: String)
signal achievement(id: String)

const S := preload("res://scripts/data/shop_data.gd")
const PATH := "user://perfil.json"
const SHOP_SIZE := 6

var laureles := 0
var lingotes := 0
var owned := {}
var equipped := {}
var achievements := {}
var stats := {"partidas": 0, "victorias": 0, "clausulas": 0}
var receipts := []
## Memoria entre partidas: lo que salió en las últimas para no repetirlo
var recent_events := []
var recent_tramas := []
var current_events := []
var current_tramas := []


func _ready() -> void:
	load_profile()
	for id in S.ITEMS.keys():
		if S.ITEMS[id].get("default", false):
			owned[id] = true
			if not equipped.has(S.ITEMS[id]["slot"]):
				equipped[S.ITEMS[id]["slot"]] = id
	Payments.purchase_completed.connect(_on_purchase)


# ------------------------------------------------------------------ guardado

func save_profile() -> void:
	if GS.no_save:
		return
	var d := {"laureles": laureles, "lingotes": lingotes, "owned": owned, "equipped": equipped, "achievements": achievements, "stats": stats, "receipts": receipts,
		"recent_events": recent_events, "recent_tramas": recent_tramas, "current_events": current_events, "current_tramas": current_tramas}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Dictionary):
		return
	laureles = int(d.get("laureles", 0))
	lingotes = int(d.get("lingotes", 0))
	owned = d.get("owned", {})
	equipped = d.get("equipped", {})
	achievements = d.get("achievements", {})
	var st: Dictionary = d.get("stats", {})
	for k in st.keys():
		stats[k] = st[k]
	receipts = d.get("receipts", [])
	recent_events = d.get("recent_events", [])
	recent_tramas = d.get("recent_tramas", [])
	current_events = d.get("current_events", [])
	current_tramas = d.get("current_tramas", [])


# ------------------------------------------------------------------ memoria entre partidas

## Al empezar una partida, la anterior pasa a la memoria (se recuerdan las dos últimas)
func start_game() -> void:
	if not current_events.is_empty():
		recent_events.push_front(current_events.duplicate())
	if not current_tramas.is_empty():
		recent_tramas.push_front(current_tramas.duplicate())
	while recent_events.size() > 2:
		recent_events.pop_back()
	while recent_tramas.size() > 2:
		recent_tramas.pop_back()
	current_events = []
	current_tramas = []
	save_profile()


## Se llama cada mes: anota lo que va saliendo en la partida actual
func note_game(event_ids: Array, tramas: Array) -> void:
	current_events = event_ids.duplicate()
	current_tramas = tramas.duplicate()
	save_profile()


## Multiplicador de probabilidad: lo visto en la última partida sale mucho menos; lo de la penúltima, algo menos
func recent_factor(id: String) -> float:
	if recent_events.size() > 0 and id in recent_events[0]:
		return 0.25
	if recent_events.size() > 1 and id in recent_events[1]:
		return 0.6
	return 1.0


## Récord de años en el poder (modo infinito)
func record_years(years: float) -> void:
	if GS.no_save:
		return
	if years > float(stats.get("record_anios", 0.0)):
		stats["record_anios"] = snappedf(years, 0.1)
		save_profile()


func unlock_terms(terms_won: int, years: float) -> void:
	if years >= 8.0:
		unlock("veterano")
	if years >= 12.0:
		unlock("decada")
	if terms_won >= 4:
		unlock("dinastia")


func trama_factor(id: String) -> float:
	if recent_tramas.size() > 0 and id in recent_tramas[0]:
		return 0.15
	if recent_tramas.size() > 1 and id in recent_tramas[1]:
		return 0.5
	return 1.0


# ------------------------------------------------------------------ monedas

func earn(amount: int, reason: String) -> void:
	if amount <= 0 or GS.no_save:
		return
	laureles += amount
	save_profile()
	earned.emit(amount, reason)
	changed.emit()


func unlock(id: String) -> void:
	if achievements.has(id) or not S.ACHIEVEMENTS.has(id) or GS.no_save:
		return
	achievements[id] = Time.get_date_string_from_system()
	var a: Dictionary = S.ACHIEVEMENTS[id]
	laureles += int(a["reward"])
	save_profile()
	achievement.emit(id)
	changed.emit()


func add_stat(key: String, n: int = 1) -> int:
	stats[key] = int(stats.get(key, 0)) + n
	save_profile()
	return int(stats[key])


# ------------------------------------------------------------------ objetos

func is_owned(id: String) -> bool:
	return owned.has(id)


func price_for(id: String, discount: float = 0.0) -> Dictionary:
	var it: Dictionary = S.ITEMS[id]
	var p := int(it.get("price", 0))
	if p > 0:
		return {"laureles": int(round(p * (1.0 - discount)))}
	return {"lingotes": int(it.get("premium", 0))}


func can_afford(cost: Dictionary) -> bool:
	return laureles >= int(cost.get("laureles", 0)) and lingotes >= int(cost.get("lingotes", 0))


func buy(id: String, discount: float = 0.0) -> bool:
	if is_owned(id):
		return false
	var cost := price_for(id, discount)
	if not can_afford(cost):
		return false
	laureles -= int(cost.get("laureles", 0))
	lingotes -= int(cost.get("lingotes", 0))
	owned[id] = true
	equip(id)
	if owned.size() - _defaults_count() >= 10:
		unlock("coleccionista")
	save_profile()
	changed.emit()
	return true


func _defaults_count() -> int:
	var n := 0
	for id in S.ITEMS.keys():
		if S.ITEMS[id].get("default", false):
			n += 1
	return n


func equip(id: String) -> void:
	if not is_owned(id):
		return
	equipped[S.ITEMS[id]["slot"]] = id
	save_profile()
	changed.emit()


func equipped_data(slot: String) -> Dictionary:
	var id: String = equipped.get(slot, "")
	if id == "" or not S.ITEMS.has(id):
		for k in S.ITEMS.keys():
			if S.ITEMS[k]["slot"] == slot and S.ITEMS[k].get("default", false):
				return S.ITEMS[k]["data"]
		return {}
	return S.ITEMS[id]["data"]


func flag_style() -> String:
	return equipped_data("bandera").get("style", "clasica")


func office_theme() -> String:
	return equipped_data("despacho").get("theme", "clasico")


func wood() -> String:
	return equipped_data("madera").get("wood", "caoba")


func apply_outfit(look: Dictionary) -> Dictionary:
	var l := look.duplicate()
	l["suit"] = equipped_data("traje").get("suit", l.get("suit", "1b2436"))
	if l.get("g", "m") == "m":
		l["tie"] = equipped_data("corbata").get("tie", l.get("tie", "8e2a22"))
	l["acc"] = equipped_data("accesorio").get("acc", "")
	return l


# ------------------------------------------------------------------ escaparate diario

func today_index() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"], "hour": 0, "minute": 0, "second": 0}) / 86400)


func seconds_to_rotation() -> int:
	var d := Time.get_datetime_dict_from_system()
	return 86400 - (int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"]))


func shop_today() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = today_index() * 7919 + 13
	var pool := []
	for id in S.ITEMS.keys():
		if not S.ITEMS[id].get("default", false):
			pool.append(id)
	pool.sort()
	# barajado determinista
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out := pool.slice(0, SHOP_SIZE)
	# las novedades están a la venta todos los días hasta que se compran
	for id in S.ITEMS.keys():
		if S.ITEMS[id].get("nuevo", false) and not is_owned(id) and not out.has(id):
			out.append(id)
	return out


func featured_today() -> String:
	var items := shop_today()
	for id in items:
		if int(S.ITEMS[id].get("price", 0)) > 0:
			return id
	return ""


# ------------------------------------------------------------------ pagos

func buy_pack(pack_id: String) -> void:
	Payments.buy(pack_id)


func exchange() -> bool:
	if lingotes < int(S.EXCHANGE["lingotes"]):
		return false
	lingotes -= int(S.EXCHANGE["lingotes"])
	laureles += int(S.EXCHANGE["laureles"])
	save_profile()
	changed.emit()
	return true


func _on_purchase(pack_id: String, receipt: Dictionary) -> void:
	for p in S.PACKS:
		if p["id"] == pack_id:
			lingotes += int(p["amount"])
			receipts.append(receipt)
			save_profile()
			changed.emit()
			return
