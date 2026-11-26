extends Node2D
## One lightweight actor for hero, guards, neutral forces, gangs and civilians.

var kind: String = "civilian"
var team: String = "civilian"
var hp: int = 100
var max_hp: int = 100
var alive: bool = true
var speed: float = 80.0
var velocity: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var alerted: bool = false
var fire_cd: float = 0.0
var think_cd: float = 0.0
var tag: String = ""
var sprite: Sprite2D
var mission: Node = null
var sheltered: bool = false
var protect_target: Node = null
var target_stall: int = 0


func setup(p_kind: String, pos: Vector2, p_team: String, p_mission: Node) -> void:
	kind = p_kind
	team = p_team
	position = pos
	mission = p_mission
	var tex: Texture2D = load("res://assets/sprites/actor_%s.png" % p_kind)
	if tex == null:
		tex = load("res://assets/sprites/actor_civilian.png")
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/shadow.png")
	shadow.position = Vector2(0.0, 7.0)
	shadow.scale = Vector2(0.72, 0.72)
	add_child(shadow)
	var ring := Sprite2D.new()
	ring.texture = load("res://assets/sprites/ring_%s.png" % p_kind)
	if ring.texture == null:
		ring.texture = load("res://assets/sprites/ring_civilian.png")
	ring.position = Vector2(0.0, 3.0)
	ring.scale = Vector2(0.62, 0.62)
	add_child(ring)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(0.82, 0.82)
	sprite.position = Vector2(0.0, -14.0)
	add_child(sprite)
	z_index = int(position.y)
	var data: Dictionary = _stats(p_kind)
	hp = int(data.get("hp", 100))
	max_hp = hp
	speed = float(data.get("speed", 80.0))
	tag = str(data.get("tag", ""))


func _stats(k: String) -> Dictionary:
	match k:
		"hero": return {"hp": 100, "speed": 145.0}
		"enemy": return {"hp": 80, "speed": 100.0, "tag": "guard"}
		"commander": return {"hp": 160, "speed": 95.0, "tag": "commander"}
		"military": return {"hp": 120, "speed": 100.0}
		"police": return {"hp": 100, "speed": 105.0}
		"airforce": return {"hp": 100, "speed": 110.0}
		"naval": return {"hp": 120, "speed": 110.0}
		"commando": return {"hp": 150, "speed": 120.0}
		"protector": return {"hp": 200, "speed": 130.0}
		"gang": return {"hp": 60, "speed": 135.0}
		"civilian": return {"hp": 45, "speed": 70.0}
		"owner": return {"hp": 100, "speed": 120.0}
		"customer": return {"hp": 40, "speed": 65.0}
		"inspector": return {"hp": 80, "speed": 90.0}
		"vendor": return {"hp": 60, "speed": 100.0}
		"quest_giver": return {"hp": 80, "speed": 0.0}
		"vip": return {"hp": 70, "speed": 40.0}
	return {"hp": 100, "speed": 80.0}


func take_damage(amount: int, from: Node = null) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		die(from)


func die(from: Node = null) -> void:
	if not alive:
		return
	alive = false
	visible = false
	if mission != null:
		mission.call("on_actor_died", self, from)


func face_towards(target: Vector2) -> void:
	var d := target - position
	if d.length_squared() > 1.0 and sprite != null:
		sprite.flip_h = d.x < 0.0


func move(direction: Vector2, delta: float, city: Node) -> void:
	if direction.length_squared() < 0.001:
		velocity = Vector2.ZERO
		return
	velocity = direction.normalized() * speed
	var to := position + velocity * delta
	if city != null:
		position = city.call("clamp_move", position, to, 7.0)
	else:
		position = to
	z_index = int(position.y)
	face_towards(position + velocity)
