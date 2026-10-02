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
	var d := {"laureles": laureles, "lingotes": lingotes, "owned": owned, "equipped": equipped, "achievements": achievements, "stats": stats, "receipts": receipts}
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
