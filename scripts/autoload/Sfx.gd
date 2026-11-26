extends Node
## Tiny procedural sound bank — no external audio files needed.

const RATE := 22050
var _streams: Dictionary = {}


func _ready() -> void:
	_streams["ui"] = _tone(660.0, 0.07, "sine", 0.28)
	_streams["shot"] = _tone(140.0, 0.12, "noise", 0.34)
	_streams["hit"] = _tone(220.0, 0.10, "square", 0.24)
	_streams["pickup"] = _tone(880.0, 0.12, "sine", 0.30)
	_streams["alarm"] = _tone(440.0, 0.35, "square", 0.20)
	_streams["bomb"] = _tone(70.0, 0.45, "noise", 0.42)
	_streams["medal"] = _tone(990.0, 0.28, "sine", 0.26)


func play(name: String, pitch: float = 1.0) -> void:
	if not bool(Game.settings.get("sfx", true)):
		return
	var st: AudioStream = _streams.get(name)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.pitch_scale = pitch
	p.volume_db = -8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _tone(freq: float, dur: float, shape: String, amp: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seedv := 12345
	for i in n:
		var t := float(i) / RATE
		var env: float = maxf(0.0, 1.0 - float(i) / float(n))
		var v := 0.0
		if shape == "sine":
			v = sin(TAU * freq * t)
		elif shape == "square":
			v = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		else:
			seedv = (seedv * 1103515245 + 12345) & 0x7fffffff
			v = float(seedv) / 1073741823.5 - 1.0
			v *= exp(-6.0 * t)
		var s := int(clampf(v * env * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
