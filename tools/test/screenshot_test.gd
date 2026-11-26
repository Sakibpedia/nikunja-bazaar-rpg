extends Node
## Renders real gameplay frames for the README.
## SHOT_MODE = menu|market|manage|summary
var mode := "menu"
var scene_node = null

func _ready() -> void:
	mode = OS.get_environment("SHOT_MODE")
	if mode == "":
		mode = "menu"
	call_deferred("_setup")
	await get_tree().create_timer(3.0).timeout
	_act()
	await get_tree().create_timer(0.8).timeout
	_capture()

func _setup() -> void:
	if mode == "menu":
		scene_node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	else:
		Game.day = 3
		scene_node = (load("res://scenes/MarketDay.tscn") as PackedScene).instantiate()
	add_child(scene_node)

func _act() -> void:
	if scene_node == null or mode == "menu":
		return
	var market = scene_node
	match mode:
		"manage":
			market.selected = 0
			market.hud.open_stall(0)
		"rpg":
			market.hud.open_rpg()
		"quests":
			market.hud.open_quests()
		"duel":
			market.selected = 0
			market.hud.open_duel()
		"summary":
			market.hud.show_summary(true, 820, 24, 9, 120)
		_:
			pass

func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path := "res://docs/images/gameplay-%s.png" % mode
	img.save_png(path)
	print("[SHOT] saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	get_tree().quit()
