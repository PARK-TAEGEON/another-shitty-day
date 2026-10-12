extends Node
## Original synthesized feedback; no external sound files or runtime service calls.
var _sounds: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 48628
	_sounds["slam"] = _make(0.32, 74.0, 0.72, 0.42)
	_sounds["impact"] = _make(0.17, 130.0, 0.50, 0.55)
	_sounds["throw"] = _make(0.18, 310.0, 0.06, 0.12)
	_sounds["pickup"] = _make(0.07, 430.0, 0.30, 0.03)
	_sounds["swing"] = _make(0.14, 190.0, 0.02, 0.09)
	_sounds["score"] = _make(0.11, 690.0, 0.17, 0.0)
	_sounds["alert"] = _make(0.26, 290.0, 0.18, 0.0)

func _make(duration: float, frequency: float, tone: float, noise: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(duration * rate)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in range(count):
		var t: float = float(i) / float(rate)
		var u: float = float(i) / float(count)
		var envelope: float = pow(1.0 - u, 3.0) * minf(u * 35.0, 1.0)
		var value: float = (sin(TAU * frequency * t * (1.0 - u * 0.18)) * tone + _rng.randf_range(-noise, noise)) * envelope
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 24000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func play(kind: String, gain: float = 1.0) -> void:
	if not _sounds.has(kind):
		return
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = _sounds[kind]
	voice.volume_db = linear_to_db(maxf(0.001, gain)) - 8.0
	voice.pitch_scale = _rng.randf_range(0.95, 1.05)
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func stop_all() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()

func _exit_tree() -> void:
	stop_all()
	_sounds.clear()
