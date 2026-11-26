extends Node2D
## One business night in Kajla Night Market Tycoon.
## Stalls, customers, prices, staff, inspectors, profit and reputation.

var data: Dictionary = {}
var city = null
var hud = null
var hero = null
var actors: Array = []
var stalls: Array = []
var selected: int = -1
var profit: int = 0
var served: int = 0
var rep_change: int = 0
var time_left: float = 180.0
var running: bool = true
var ended: bool = false
var paused: bool = false
var rng := RandomNumberGenerator.new()
var _think: float = 0.0
var _inspect: float = 22.0
var _hint: float = 0.0
var cam: Camera2D = null
var marker = null
var quest_progress: Dictionary = {}
var quest_giver = null
var vip = null


func _ready() -> void:
	rng.seed = int(Time.get_unix_time_from_system()) + Game.day * 97
	data = Game.day_data(Game.day)
	city = load("res://scripts/world/City2D.gd").new()
	add_child(city)
	_build_stalls()
	hero = _spawn("owner", "owner", city.extraction)
	if not city.plaza_stalls.is_empty():
		hero.position = city.plaza.position + city.plaza.size * 0.5
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	hero.add_child(cam)
	cam.make_current()
	marker = MarketMarker.new()
	marker.market = self
	add_child(marker)
	hud = load("res://scripts/ui/TycoonHUD.gd").new()
	hud.market = self
	add_child(hud)
	_spawn_customers(int(32.0 * float(data.get("rush", 1.0))))
	for i in 3:
		_spawn("inspector", "inspector", city.random_road_point(7000 + i * 31))
	for i in 2:
		_spawn("vendor", "vendor", city.random_road_point(8000 + i * 17))
	if not city.plaza_stalls.is_empty():
		quest_giver = _spawn("quest_giver", "quest_giver",
			city.plaza.position + Vector2(26, city.plaza.size.y - 26))
		vip = _spawn("vip", "vip", city.plaza.position + Vector2(city.plaza.size.x - 30, 30))
	for q in (data.get("quests", []) as Array):
		quest_progress[str((q as Dictionary)["id"])] = false
	running = true
	hud.notify("রাত %d — %s  •  লক্ষ্য ৳%d / %d ক্রেতা" % [
		Game.day, str(data.get("event", "")), int(data.get("target_profit", 0)),
		int(data.get("target_customers", 0))])


func _build_stalls() -> void:
	stalls = []
	var all_stalls: Array = city.shops + city.plaza_stalls
	for i in all_stalls.size():
		var s: Dictionary = all_stalls[i]
		stalls.append({"idx": i, "pos": s["pos"], "kind": s["kind"],
			"name": Game.stall_name(i), "color": s["color"]})


func _spawn(kind: String, team: String, pos: Vector2):
	var a = load("res://scripts/world/Actor2D.gd").new()
	add_child(a)
	a.setup(kind, pos, team, self)
	actors.append(a)
	return a


func _spawn_customers(n: int) -> void:
	for i in n:
		var a = _spawn("customer", "customer", city.random_road_point(1000 + i * 13))
		a.target_stall = rng.randi_range(0, stalls.size() - 1)


func _process(delta: float) -> void:
	if not running or ended or paused:
		return
	time_left -= delta
	if time_left <= 0.0:
		end_day()
		return
	_handle_input(delta)
	_think += delta
	if _think > 0.35:
		_think = 0.0
		_update_customers()
		_update_staff()
	_inspect -= delta
	if _inspect <= 0.0:
		_inspect = 24.0
	_do_inspection()
	_check_quests()
	hud.tick(delta)
	hud.refresh()


func _check_quests() -> void:
	for q in (data.get("quests", []) as Array):
		var quest: Dictionary = q
		var qid := str(quest["id"])
		if bool(quest_progress.get(qid, false)):
			continue
		var ok := false
		match str(quest["type"]):
			"serve": ok = served >= int(quest["target"])
			"profit": ok = profit >= int(quest["target"])
			"reputation": ok = Game.reputation + rep_change >= int(quest["target"])
		if ok:
			quest_progress[qid] = true
			if Game.grant_quest(qid, int(quest["reward"]), int(quest["xp"])):
				hud.notify("কুয়েস্ট সম্পন্ন: %s  +%d XP" % [str(quest["text"]), int(quest["xp"])])
				Sfx.play("medal")


func _handle_input(delta: float) -> void:
	if hud != null and hud.blocking():
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
	hero.speed = 175.0 if Input.is_key_pressed(KEY_SHIFT) else 120.0
	hero.move(dir, delta, city)
	if Input.is_key_pressed(KEY_E) and _hint <= 0.0:
		_hint = 0.4
		if quest_giver != null and hero.position.distance_to(quest_giver.position) < 42.0:
			hud.open_quests()
		elif vip != null and hero.position.distance_to(vip.position) < 42.0:
			hud.open_duel()
		else:
			var idx := _nearest_stall()
			if idx >= 0:
				selected = idx
				hud.open_stall(idx)
	if Input.is_key_pressed(KEY_F) and _hint <= 0.0:
		_hint = 0.4
		if profit >= int(data.get("target_profit", 0)) and served >= int(data.get("target_customers", 0)):
			end_day()
		else:
			hud.notify("লক্ষ্য পূর্ণ হয়নি — আর কিছু বেচুন")
	_hint = maxf(0.0, _hint - delta)


func _nearest_stall() -> int:
	var best := -1
	var bd := 55.0
	for s in stalls:
		var d: float = (s["pos"] as Vector2).distance_to(hero.position)
		if d < bd:
			bd = d
			best = int(s["idx"])
	return best


func _update_customers() -> void:
	for a in actors:
		if not a.alive or a.kind != "customer":
			continue
		var idx: int = int(a.target_stall)
		if idx < 0 or idx >= stalls.size():
			a.target_stall = rng.randi_range(0, stalls.size() - 1)
			continue
		var dest: Vector2 = stalls[idx]["pos"]
		if a.position.distance_to(dest) < 34.0:
			_try_sale(idx, a)
			a.target_stall = rng.randi_range(0, stalls.size() - 1)
		else:
			a.move((dest - a.position).normalized(), 0.35, city)


func _try_sale(idx: int, customer = null) -> bool:
	var price := Game.price_of(idx)
	var fair := Game.fair_price(idx)
	if Game.stock_of(idx) <= 0:
		return false
	var chance: float = clampf(1.25 - float(price) / float(fair), 0.06, 0.92)
	chance *= float(data.get("rush", 1.0))
	if customer != null and rng.randf() > chance:
		return false
	var qty: int = mini(1 + (rng.randi() % 3), Game.stock_of(idx))
	return force_sale(idx, qty)


func force_sale(idx: int, qty: int) -> bool:
	if idx < 0 or idx >= stalls.size() or qty <= 0 or Game.stock_of(idx) < qty:
		return false
	var price := Game.price_of(idx)
	var fair := Game.fair_price(idx)
	Game.stocks[str(idx)] = Game.stock_of(idx) - qty
	var revenue := qty * price
	profit += revenue
	Game.wallet += revenue
	served += 1
	if price <= fair:
		rep_change += 1
	elif price > fair * 1.4:
		rep_change -= 1
	Sfx.play("coin" if Sfx._streams.has("coin") else "pickup", 1.0 + randf() * 0.2)
	return true


func _update_staff() -> void:
	for s in stalls:
		var idx: int = s["idx"]
		var staff_n := Game.staff_count(idx)
		if staff_n > 0 and Game.stock_of(idx) > 0 and rng.randf() < 0.25 * staff_n:
			force_sale(idx, 1)


func _do_inspection() -> void:
	var idx := rng.randi_range(0, stalls.size() - 1)
	var price := Game.price_of(idx)
	var fair := Game.fair_price(idx)
	if price > int(fair * 1.4) and profit > 0:
		var fine: int = 45 + Game.day * 5
		profit -= fine
		Game.wallet = maxi(0, Game.wallet - fine)
		rep_change -= 2
		hud.notify("পরিদর্শক জরিমানা করলেন ৳%d — %s" % [fine, str(stalls[idx]["name"])])
		Sfx.play("alarm")
	else:
		rep_change += 1
	marker.inspect_at = stalls[idx]["pos"]
	marker.inspect_time = 1.5


func end_day() -> void:
	if ended:
		return
	ended = true
	running = false
	var success: bool = profit >= int(data.get("target_profit", 0)) and \
		served >= int(data.get("target_customers", 0)) and \
		(Game.reputation + rep_change) > 10
	if success:
		Game.complete_day(Game.day, profit, served, rep_change)
	else:
		Game.fail_day(Game.day, "লক্ষ্য পূর্ণ হয়নি")
	Game.save_game()
	hud.show_summary(success, profit, served, rep_change, int(data.get("rent", 0)))


func reset_for_retry() -> void:
	# Re-run the same night with the same stall state.
	get_tree().change_scene_to_file("res://scenes/MarketDay.tscn")


func next_day() -> void:
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/MarketDay.tscn")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ESCAPE and running:
		if hud != null and hud.blocking():
			hud.close_panel()
		else:
			paused = not paused
			hud.notify("বিরতি — ESC দিয়ে ফিরুন")
	elif event.keycode == KEY_Q and running and not paused and hud != null and not hud.blocking():
		hud.open_rpg()


class MarketMarker extends Node2D:
	var market
	var inspect_at: Vector2 = Vector2.ZERO
	var inspect_time: float = 0.0

	func _draw() -> void:
		if market == null or market.hud == null:
			return
		if market.hud.state == "stall" and market.selected >= 0:
			var p: Vector2 = market.stalls[market.selected]["pos"]
			draw_circle(p, 30.0, Color(1.0, 0.80, 0.35, 0.22))
			draw_circle(p, 30.0, Color(1.0, 0.80, 0.35), false, 3.0)
		if inspect_time > 0.0:
			inspect_time = maxf(0.0, inspect_time - 0.016)
			draw_circle(inspect_at, 34.0, Color(0.95, 0.35, 0.30, 0.35))
			draw_circle(inspect_at, 34.0, Color(1.0, 0.4, 0.35), false, 2.0)
