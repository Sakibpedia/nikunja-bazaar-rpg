extends Node
## Playthrough-style test for a single market night (DAY=1..15).
var market
var t := 0.0
var idx := 1
var reported := false
var fails := 0

func _ready() -> void:
	var env := OS.get_environment("DAY")
	idx = int(env) if env != "" else 1
	Game.day = idx
	market = (load("res://scenes/MarketDay.tscn") as PackedScene).instantiate()
	add_child(market)

func _ck(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("[DAY] FAIL D%d %s" % [idx, what])

func _process(delta: float) -> void:
	t += delta
	if t > 120.0:
		print("[DAY] FAIL D%d timeout" % idx)
		get_tree().quit(1)
	if reported or t < 2.0 or not market.running:
		return
	reported = true
	_ck(market.stalls.size() >= 30, "stalls present (%d)" % market.stalls.size())
	_ck(market.actors.size() >= 30, "actors spawned (%d)" % market.actors.size())
	_ck(market.city.buildings.size() >= 1400, "city built")
	_ck(market.hero != null, "owner present")
	# Serve enough customers to hit both targets, using the real sale hook.
	Game.stocks["0"] = 400
	var target_profit := int(market.data.get("target_profit", 0))
	var target_customers := int(market.data.get("target_customers", 0))
	var guard := 0
	while (market.profit < target_profit or market.served < target_customers) and guard < 400:
		market.force_sale(0, 5)
		guard += 1
	_ck(market.profit >= target_profit, "profit target")
	_ck(market.served >= target_customers, "customer target")
	market._check_quests()
	_ck(Game.quests_done.has(str((market.data["quests"][0] as Dictionary)["id"])), "serve quest rewarded")
	market.end_day()
	_ck(market.ended == true, "day ended")
	_ck(Game.last_result.get("success", false) == true, "day successful")
	if fails == 0:
		print("[DAY] PASS D%d - %d stalls, %d customers, profit %d" % [
			idx, market.stalls.size(), market.served, market.profit])
		get_tree().quit(0)
	else:
		get_tree().quit(1)
