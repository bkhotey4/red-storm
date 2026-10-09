extends Node
# 音效 / 語音管理 (直接讀取 WAV，不需要 Godot 匯入)

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var voice: AudioStreamPlayer
var ack_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var music_name := ""
var ack_t := -100.0
var voice_queue: Array = []
var last_play := {}
var last_voice := {}
const MAP := {
	"mg": "sfx/mg_burst", "cannon": "sfx/cannon_fire", "rocket": "sfx/rocket_launch", "explode": "sfx/explosion",
	"build": "sfx/build_place", "click": "sfx/ui_click", "radio": "sfx/radio_squelch",
	"zap": "sfx/zap", "laser": "sfx/laser", "flak": "sfx/flak", "pistol": "sfx/pistol", "bomb": "sfx/bomb",
	"big_explode": "sfx/big_explode", "sell": "sfx/sell", "cash": "sfx/cash", "deploy": "sfx/deploy",
	"power_down": "sfx/power_down", "alarm": "sfx/alarm", "missile": "sfx/missile", "thunder": "sfx/thunder",
	"select": "sfx/select", "tick": "sfx/tick", "inf_die": "sfx/inf_die", "place": "sfx/place", "jet": "sfx/jet",
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	voice.finished.connect(_next_voice)
	ack_player = AudioStreamPlayer.new()
	add_child(ack_player)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

func load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			var r = load(path)
			if r is AudioStreamWAV:
				return r
		return null
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos := 12
	var channels := 1
	var rate := 22050
	var bits := 16
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var cid := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := b.decode_u32(pos + 4)
		var body := pos + 8
		if cid == "fmt ":
			channels = b.decode_u16(body + 2)
			rate = b.decode_u32(body + 4)
			bits = b.decode_u16(body + 14)
		elif cid == "data":
			data = b.slice(body, mini(body + sz, b.size()))
		pos = body + sz + (sz & 1)
	if data.is_empty():
		return null
	var s := AudioStreamWAV.new()
	s.mix_rate = rate
	s.stereo = channels == 2
	if bits == 8:
		s.format = AudioStreamWAV.FORMAT_8_BITS
		# WAV 8-bit is unsigned; Godot expects signed
		for i in data.size():
			data[i] = (data[i] + 128) & 0xFF
	else:
		s.format = AudioStreamWAV.FORMAT_16_BITS
	s.data = data
	return s

func stream(name: String) -> AudioStreamWAV:
	if streams.has(name):
		return streams[name]
	var path: String = MAP.get(name, name)
	var s := load_wav("res://audio/%s.wav" % path)
	streams[name] = s
	return s

func play(name: String, vol_db := 0.0, world_pos = null, pitch_var := 0.07):
	var s := stream(name)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_play.get(name, -1.0)) < 0.06:
		return
	last_play[name] = now
	if world_pos != null and G.game != null and is_instance_valid(G.game):
		var att: float = G.game.sound_attenuation(world_pos)
		if att <= -40.0:
			return
		vol_db += att
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		return
	p.stream = s
	p.volume_db = vol_db + linear_to_db(maxf(0.001, float(G.settings.sfx_vol)))
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func say(name: String, cooldown := 4.0):
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_voice.get(name, -100.0)) < cooldown:
		return
	last_voice[name] = now
	var s := load_voice(name)
	if s == null:
		return
	if voice.playing:
		if voice_queue.size() < 2 and not voice_queue.has(s):
			voice_queue.append(s)
		return
	voice.stream = s
	voice.volume_db = linear_to_db(maxf(0.001, float(G.settings.voice_vol)))
	voice.play()

func _next_voice():
	if voice_queue.is_empty():
		return
	voice.stream = voice_queue.pop_front()
	voice.play()

func load_voice(name: String) -> AudioStreamWAV:
	var key := "voice:" + name
	if streams.has(key):
		return streams[key]
	var s := load_wav("res://audio/voice/%s.wav" % name)
	streams[key] = s
	return s

func stop_all():
	for p in pool:
		p.stop()
	ack_player.stop()
	voice.stop()
	voice_queue.clear()

func ack(name: String):
	var now := Time.get_ticks_msec() / 1000.0
	if ack_player.playing or now - ack_t < 4.0:
		return
	var s := load_voice(name)
	if s == null:
		return
	ack_t = now
	ack_player.stream = s
	ack_player.volume_db = linear_to_db(maxf(0.001, float(G.settings.voice_vol))) - 3.0
	ack_player.play()

func music(name: String):
	if music_name == name and music_player.playing:
		return
	music_name = name
	var s := load_wav("res://audio/music/%s.wav" % name)
	if s == null:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate) - 1
	music_player.stream = s
	update_music_volume()
	music_player.play()

func update_music_volume():
	music_player.volume_db = linear_to_db(maxf(0.001, float(G.settings.get("music_vol", 0.5)))) - 6.0
