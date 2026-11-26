extends Control
## Night-select menu for Kajla Night Market Tycoon.

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/menu_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.04, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var title := Label.new()
	title.text = "KAJLA NIGHT MARKET TYCOON"
	title.position = Vector2(60, 40)
	title.size = Vector2(900, 66)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.50))
	add_child(title)
	var sub := Label.new()
	sub.text = "সনটেক কাজলা • ১৫ রাত • দোকান, দাম, কর্মচারী আর সুনাম"
	sub.position = Vector2(62, 106)
	sub.size = Vector2(900, 36)
	sub.add_theme_font_size_override("font_size", 21)
	sub.add_theme_color_override("font_color", Color(0.58, 0.90, 0.80))
	add_child(sub)
	var info := Label.new()
	info.text = "৳ %d   |   সুনাম %d/100   |   পদমর্যাদা: %s   |   মোট লাভ ৳%d   |   ঘুমন্ত দোকান 30" % [
		Game.wallet, Game.reputation, Game.rank(), Game.total_profit()]
	info.position = Vector2(62, 150)
	info.size = Vector2(1100, 34)
	info.add_theme_font_size_override("font_size", 19)
	info.add_theme_color_override("font_color", Color(0.93, 0.94, 0.88))
	add_child(info)

	for i in Game.DAY_COUNT:
		var idx := i + 1
		var b := Button.new()
		b.position = Vector2(62 + (i % 5) * 230, 215 + (i / 5) * 118)
		b.size = Vector2(214, 96)
		var locked: bool = idx > Game.unlocked
		var rec: Dictionary = Game.records.get(str(idx), {})
		var grade := str(rec.get("grade", ""))
		var mark := "[LOCKED]" if locked else ("[" + grade + "]" if grade != "" else "[OPEN]")
		b.text = "রাত %02d  %s\n%s  %s" % [idx, str(Game.day_data(idx)["name"]),
			str(Game.day_data(idx)["event"]), mark]
		b.disabled = locked
		b.add_theme_font_size_override("font_size", 16)
		if not locked:
			b.pressed.connect(_start.bind(idx))
		add_child(b)

	var help := Label.new()
	help.text = "WASD চলুন • E দোকান • 1-5 স্টক/দাম/কর্মচারী/উন্নতি • F দিন শেষ • ESC বিরতি • সস্তা দামে বেশি ক্রেতা"
	help.position = Vector2(62, 588)
	help.size = Vector2(1160, 36)
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color(0.82, 0.88, 0.84))
	add_child(help)
	var credit := Label.new()
	credit.text = "Made by S M Nazmuz Sakib   •   Map data © OpenStreetMap contributors (ODbL 1.0)"
	credit.position = Vector2(62, 682)
	credit.size = Vector2(1160, 24)
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.62, 0.70, 0.68))
	add_child(credit)


func _start(idx: int) -> void:
	Game.day = idx
	Sfx.play("ui")
	get_tree().change_scene_to_file("res://scenes/MarketDay.tscn")
