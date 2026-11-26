extends Node
## Economy / persistence verification for Night Market Tycoon.
func _ready() -> void:
	var fails := 0
	var snap := {
		"wallet": Game.wallet, "rep": Game.reputation, "unlocked": Game.unlocked,
		"day": Game.day, "records": Game.records.duplicate(true),
		"stocks": Game.stocks.duplicate(true), "prices": Game.prices.duplicate(true),
		"staff": Game.staff.duplicate(true), "levels": Game.levels.duplicate(true),
		"level": Game.level, "xp": Game.xp, "skill_points": Game.skill_points,
		"skills": Game.skills.duplicate(true), "quests": Game.quests_done.duplicate(true),
		"factions": Game.factions.duplicate(true),
	}
	for i in range(1, 16):
		var d: Dictionary = Game.day_data(i)
		if int(d.get("target_profit", 0)) <= 0: fails += 1
		if str(d.get("event", "")) == "": fails += 1
		if str(d.get("name", "")) == "": fails += 1
		if (d.get("quests", []) as Array).size() != 3: fails += 1

	Game.wallet = 2000
	var stock_before := Game.stock_of(0)
	if not Game.buy_stock(0, 10): fails += 1
	if Game.stock_of(0) != mini(stock_before + 10, Game.capacity(0)): fails += 1
	Game.set_price(0, 99)
	if Game.price_of(0) != 99: fails += 1
	if not Game.hire_staff(0) or Game.staff_count(0) < 1: fails += 1
	if not Game.upgrade_stall(0) or Game.stall_level(0) < 1: fails += 1
	var wallet_before := Game.wallet
	Game.complete_day(1, 1000, 20, 5)
	if Game.unlocked < 2: fails += 1
	var grade := str(((Game.records.get("1", {}) as Dictionary).get("grade", "")))
	if grade == "": fails += 1
	Game.save_game()
	Game.wallet = 0
	Game.load_game()
	if Game.wallet <= 0: fails += 1
	if Game.wallet != wallet_before + 1000 - int(Game.day_data(1)["rent"]): fails += 1
	if Game.rank() == "": fails += 1

	# RPG systems
	Game.skill_points = 2
	if not Game.allocate_skill("haggling"): fails += 1
	if Game.skill("haggling") < 1: fails += 1
	var lvl_before := Game.level
	if not Game.grant_quest("economy_test_q", 100, Game.xp_to_next() + 10): fails += 1
	if Game.level <= lvl_before: fails += 1
	if Game.haggling_bonus() <= 1.0: fails += 1
	if not Game.quests_done.has("economy_test_q"): fails += 1
	Game.save_game()
	Game.level = 1
	Game.load_game()
	if Game.level <= lvl_before: fails += 1

	Game.wallet = snap["wallet"]; Game.reputation = snap["rep"]
	Game.unlocked = snap["unlocked"]; Game.day = snap["day"]
	Game.records = snap["records"]; Game.stocks = snap["stocks"]
	Game.prices = snap["prices"]; Game.staff = snap["staff"]
	Game.levels = snap["levels"]
	Game.level = snap["level"]; Game.xp = snap["xp"]; Game.skill_points = snap["skill_points"]
	Game.skills = snap["skills"]; Game.quests_done = snap["quests"]; Game.factions = snap["factions"]
	Game.save_game()
	if fails > 0:
		print("[ECON] FAIL %d checks" % fails)
		get_tree().quit(1)
	print("[ECON] PASS - 15 nights, stock, pricing, staff, upgrades, save/reload")
	get_tree().quit(0)
