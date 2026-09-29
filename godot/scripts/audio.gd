extends Node
## Music (with crossfades) and pooled sound effects.

const MUSIC_DB := -7.0
const SFX_DB := -2.0

var music_volume := 0.8
var sfx_volume := 0.9
var current := ""

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_players.append(p)
	for i in 10:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx_pool.append(s)


func _stream(name: String, loop: bool) -> AudioStream:
	var key := name + ("@loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := "res://audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		push_warning("Missing audio: " + path)
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		s = s.duplicate()
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_cache[key] = s
	return s


func _music_db() -> float:
	return MUSIC_DB + linear_to_db(maxf(music_volume, 0.001))


func play_music(name: String, fade := 1.0) -> void:
	if name == current:
		return
	current = name
	var old := _players[_active]
	_active = 1 - _active
	var nu := _players[_active]
	var s := _stream(name, name != "victory")
	nu.stream = s
	nu.volume_db = -40.0
	if s:
		nu.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nu, "volume_db", _music_db(), fade)
	tw.tween_property(old, "volume_db", -60.0, fade)
	tw.chain().tween_callback(old.stop)


func stop_music(fade := 1.0) -> void:
	current = ""
	var p := _players[_active]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.stop)


func set_music_volume(v: float) -> void:
	music_volume = v
	if _players[_active].playing:
		_players[_active].volume_db = _music_db()


func sfx(name: String, pitch_jitter := 0.0, db := 0.0) -> void:
	var s := _stream(name, false)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for candidate in _sfx_pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _sfx_pool[0]
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = SFX_DB + db + linear_to_db(maxf(sfx_volume, 0.001))
	p.play()
